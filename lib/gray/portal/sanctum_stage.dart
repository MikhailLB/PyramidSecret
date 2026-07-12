import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/desert_transport.dart';
import '../core/signal_scanner.dart';
import '../core/telegram_courier.dart';
import '../core/vault_locker.dart';
import '../env/sanctum_config.dart';
import 'tempest_screen.dart';

// ────────────────────────────────────────────────────────────
// SanctumStage — full-screen WebView container (gray mode UI).
// ────────────────────────────────────────────────────────────
// Consolidates every WebView pitfall from `gray_part_pitfalls.md`:
//   §3   — debounced connectivity loss (700 ms).
//   §4   — instant black overlay on WebResourceError so the native
//          Android error page never shows.
//   §5,8 — keyboard scroll fix + safe-area CSS killer.
// Also handles third-party cookies, file uploads, video autoplay,
// warm push URL delivery, cold-tap recovery.

Future<void> primeSanctumEngine({String? warmupHost}) async {
  // Best-effort DNS lookup so the WebView's first request skips the
  // cold-lookup penalty on cellular. Non-blocking — 400 ms cap, every
  // failure is swallowed.
  if (warmupHost == null) return;
  try {
    await InternetAddress.lookup(warmupHost)
        .timeout(const Duration(milliseconds: 400));
  } catch (_) {}
}

class SanctumStage extends StatefulWidget {
  final String shrineUrl;
  final VaultLocker vault;
  final TelegramCourier courier;
  final SignalScanner scanner;

  const SanctumStage({
    super.key,
    required this.shrineUrl,
    required this.vault,
    required this.courier,
    required this.scanner,
  });

  @override
  State<SanctumStage> createState() => _SanctumStageState();
}

class _SanctumStageState extends State<SanctumStage>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _loading = true;
  bool _errored = false;
  bool _routedAway = false;

  StreamSubscription<List<ConnectivityResult>>? _pulseSub;
  Timer? _offlineDebounce;

  String? _lastMainUrl;
  int _redirectRetries = 0;

  void Function(String url)? _previousWarmHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _applyImmersive();

    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(desertTransport.userAgent)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _errored = false;
              _loading = true;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            if (_errored) return;
            setState(() => _loading = false);
            _redirectRetries = 0;
            _injectSafeAreaKill();
            _injectKeyboardScroll();
          },
          onWebResourceError: _handleWebError,
          onHttpError: (_) {},
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            final scheme = uri.scheme;
            const webSchemes = <String>{
              'http',
              'https',
              'about',
              'data',
              'blob',
            };
            if (webSchemes.contains(scheme)) {
              if (request.isMainFrame) _lastMainUrl = request.url;
              return NavigationDecision.navigate;
            }
            _launchExternal(uri);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..enableZoom(false);

    _tuneAndroidWebView();
    _web.loadRequest(Uri.parse(widget.shrineUrl));

    _previousWarmHandler = widget.courier.onWarmShrine;
    widget.courier.onWarmShrine = (url) {
      if (!mounted) return;
      _web.loadRequest(Uri.parse(url));
    };

    _pulseSub = widget.scanner.pulseStream.listen(_onPulse);
  }

  void _applyImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _applyImmersive();
  }

  void _tuneAndroidWebView() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final controller = _web.platform as AndroidWebViewController;

    controller.setMediaPlaybackRequiresUserGesture(false);
    controller.setOnShowFileSelector(_pickFilesForWeb);

    final cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(controller, true);
  }

  Future<List<String>> _pickFilesForWeb(FileSelectorParams params) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (picked == null) return const <String>[];
      return picked.files
          .where((file) => file.path != null)
          .map((file) => Uri.file(file.path!).toString())
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  void _handleWebError(WebResourceError error) {
    // §4 belt-and-braces: cover the WebView instantly so the native
    // "no internet dinosaur" never shows up while we route away.
    if (mounted) {
      setState(() {
        _errored = true;
        _loading = true;
      });
    }
    if (error.isForMainFrame == false) return;

    final blurb = error.description.toLowerCase();
    final isRedirectLoop = blurb.contains('too_many_redirects') ||
        blurb.contains('too many redirects') ||
        error.errorCode == -1007 ||
        error.errorCode == -9;
    if (isRedirectLoop &&
        _lastMainUrl != null &&
        _redirectRetries < 3) {
      _redirectRetries++;
      _web.loadRequest(Uri.parse(_lastMainUrl!));
      return;
    }

    final isKnownOffline = blurb.contains('name_not_resolved') ||
        blurb.contains('internet_disconnected') ||
        blurb.contains('network_changed') ||
        blurb.contains('address_unreachable') ||
        blurb.contains('connection_refused') ||
        blurb.contains('connection_reset') ||
        blurb.contains('connection_timed_out') ||
        error.errorCode == -2 ||
        error.errorCode == -6 ||
        error.errorCode == -7 ||
        error.errorCode == -21 ||
        error.errorCode == -105 ||
        error.errorCode == -106 ||
        error.errorCode == -109 ||
        error.errorCode == -118;

    if (isKnownOffline) {
      _teleportToTempest();
    } else {
      _confirmTempest();
    }
  }

  Future<void> _confirmTempest() async {
    final live = await widget.scanner.hasReachableNet();
    if (!mounted || live) return;
    _teleportToTempest();
  }

  void _teleportToTempest() {
    if (_routedAway) return;
    _routedAway = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TempestScreen(
          retryBuilder: (_) => SanctumStage(
            shrineUrl: widget.shrineUrl,
            vault: widget.vault,
            courier: widget.courier,
            scanner: widget.scanner,
          ),
        ),
      ),
    );
  }

  void _onPulse(List<ConnectivityResult> results) {
    final allNone =
        results.every((r) => r == ConnectivityResult.none);
    if (!allNone) {
      _offlineDebounce?.cancel();
      _offlineDebounce = null;
      return;
    }
    _offlineDebounce?.cancel();
    _offlineDebounce = Timer(
      Duration(milliseconds: SanctumConfig.offlineDebounceMillis),
      _teleportToTempest,
    );
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _injectKeyboardScroll() {
    _web.runJavaScript(r'''
(function(){
  if (window.__psKbFix) return;
  window.__psKbFix = true;
  function isField(el){
    if (!el) return false;
    if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') return true;
    return el.isContentEditable === true;
  }
  function into(){
    var el = document.activeElement;
    if (!isField(el)) return;
    el.scrollIntoView({behavior:'auto', block:'nearest'});
  }
  document.addEventListener('focusin', function(e){
    if (isField(e.target)) setTimeout(into, 340);
  });
  if (window.visualViewport){
    var last = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function(){
      var h = window.visualViewport.height;
      if (h < last) setTimeout(into, 120);
      last = h;
    });
  }
})();
''');
  }

  void _injectSafeAreaKill() {
    _web.runJavaScript(r'''
(function(){
  if (window.__psSafeArea) return;
  window.__psSafeArea = true;
  var TAG = '__ps_safe_area';
  var CSS =
    ':root{' +
      '--safe-area-inset-top:0px!important;' +
      '--safe-area-inset-right:0px!important;' +
      '--safe-area-inset-bottom:0px!important;' +
      '--safe-area-inset-left:0px!important;' +
      '--sat:0px!important;--sar:0px!important;' +
      '--sab:0px!important;--sal:0px!important;' +
      '--safe-top:0px!important;--safe-right:0px!important;' +
      '--safe-bottom:0px!important;--safe-left:0px!important;' +
    '}';
  function kbOpen(){
    if (!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight * 0.75;
  }
  function apply(){
    if (kbOpen()) return;
    var head = document.head || document.documentElement;
    if (!head) return;
    var meta = document.querySelector('meta[name="viewport"]');
    if (meta && !/viewport-fit\s*=\s*contain/i.test(meta.getAttribute('content')||'')){
      var c = (meta.getAttribute('content')||'')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      meta.setAttribute('content', c + (c ? ', ' : '') + 'viewport-fit=contain');
    }
    var style = document.getElementById(TAG);
    if (!style){
      style = document.createElement('style');
      style.id = TAG;
      head.appendChild(style);
    }
    if (style.textContent !== CSS) style.textContent = CSS;
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var orig = history[fn];
    history[fn] = function(){
      var r = orig.apply(this, arguments);
      setTimeout(apply, 80);
      setTimeout(apply, 400);
      return r;
    };
  });
  window.addEventListener('popstate', function(){ setTimeout(apply, 80); });
  setInterval(apply, 2500);
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseSub?.cancel();
    _offlineDebounce?.cancel();
    // Restore whatever handler existed before — never null it, or the
    // next warm push tap after we leave will vanish (pitfall §12).
    widget.courier.onWarmShrine = _previousWarmHandler;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<bool> _onBackTap() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final orient = MediaQuery.of(context).orientation;
    final padding = MediaQuery.of(context).viewPadding;
    final isLandscape = orient == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onBackTap();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: isLandscape
                  ? EdgeInsets.only(
                      left: padding.left,
                      right: padding.right,
                    )
                  : EdgeInsets.only(top: padding.top),
              child: WebViewWidget(controller: _web),
            ),
            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFF4C752),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
