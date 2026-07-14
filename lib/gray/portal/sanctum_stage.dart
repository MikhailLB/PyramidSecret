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
import '../insight/oracle_trace.dart';
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

Future<void> primeSanctumEngine() async {
  // Warmup hook — kept explicit so the splash can `await` on it
  // right after the deferred `loadLibrary()` call.
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
  // The black loading overlay is only useful once — while the very
  // first page is being fetched, so users don't see an empty black
  // scaffold. Every subsequent navigation (e.g. tapping a link
  // inside the site) MUST NOT re-cover the WebView, because slow /
  // hanging third-party pages would then look like an infinite
  // spinner blocking the whole app. `_firstLoadDone` flips to true
  // the first time `onPageFinished` fires.
  bool _loading = true;
  bool _firstLoadDone = false;
  bool _errored = false;
  bool _routedAway = false;

  // Clarity funnel state — see OracleTrace notes at the top of this
  // widget: session replay ignores the WebView DOM, so custom events
  // are the only way to answer "did the user reach the offer?".
  bool _offerReached = false;
  bool _pageHadError = false;

  StreamSubscription<List<ConnectivityResult>>? _pulseSub;
  Timer? _offlineDebounce;

  String? _lastMainUrl;
  int _redirectRetries = 0;

  // In-page funnel detection — kept static so hot-reload doesn't
  // recompile the character classes. Non-capturing groups only.
  static final RegExp _depositRx = RegExp(
    r'(deposit|cashier|top.?up|replenish|payment|checkout|wallet|'
    r'пополн|депозит|касс|оплат|внести|платеж)',
    caseSensitive: false,
  );
  static final RegExp _registerRx = RegExp(
    r'(sign.?up|regist|create.?account|onboarding|'
    r'регистрац|зарегистр)',
    caseSensitive: false,
  );
  static final RegExp _loginRx = RegExp(
    r'(sign.?in|log.?in|log.?on|/auth\b|authoriz|войти|вход|авториз)',
    caseSensitive: false,
  );

  void Function(String url)? _previousWarmHandler;

  @override
  void initState() {
    super.initState();
    OracleTrace.screen('web');
    OracleTrace.event('web_open');
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
            _pageHadError = false;
            // Never re-arm the overlay after the first page has
            // painted — subsequent link taps stay on the current
            // page until the new one is ready.
            setState(() {
              _errored = false;
              if (!_firstLoadDone) _loading = true;
            });
          },
          onPageFinished: (url) {
            if (!mounted) return;
            if (_errored) return;
            setState(() {
              _loading = false;
              _firstLoadDone = true;
            });
            _redirectRetries = 0;
            _injectSafeAreaKill();
            _injectKeyboardScroll();
            _injectLinkFix();
            _installInsightProbe();
            _trackWebPage(url);
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
            // External hand-off (tel:, mailto:, deposit intent,
            // etc.). Log the scheme so the funnel can attribute
            // deposit / auth intents that leave the WebView.
            OracleTrace.event('web_external');
            OracleTrace.tag('web_external_scheme', uri.scheme);
            _launchExternal(uri);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..addJavaScriptChannel(
        'PyramidLens',
        onMessageReceived: (msg) => _onWebSignal(msg.message),
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
    if (state == AppLifecycleState.resumed) {
      _applyImmersive();
      OracleTrace.event('web_foreground');
    } else if (state == AppLifecycleState.paused) {
      // Pause while inside the WebView is the strongest drop-off
      // signal we get natively — combine with the `last_screen` tag
      // to see what page they abandoned on.
      OracleTrace.event('web_background');
    }
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
    // But only DO the overlay while we are still on the very first
    // page — otherwise a transient sub-resource failure (favicon,
    // analytics beacon, etc.) mid-session would blank out the whole
    // page and look like an infinite spinner.
    if (mounted) {
      setState(() {
        _errored = true;
        if (!_firstLoadDone) _loading = true;
      });
    }
    if (error.isForMainFrame == false) return;

    _pageHadError = true;
    final String reason = _classifyWebError(error);
    final String failed = _lastMainUrl ?? widget.shrineUrl;
    final String host = Uri.tryParse(failed)?.host ?? '';
    OracleTrace.event('web_error');
    OracleTrace.tag('web_error_reason', reason);
    OracleTrace.tag(
      'web_last_error',
      '${error.errorCode}:${error.description}',
    );
    if (host.isNotEmpty) OracleTrace.tag('web_error_host', host);
    if (!_offerReached) {
      OracleTrace.event('web_offer_unreachable');
      OracleTrace.tag('offer_reached', 'false');
      OracleTrace.tag('offer_unreachable_reason', reason);
    } else {
      OracleTrace.event('web_error_after_load');
    }

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

  // ── OracleTrace / Microsoft Clarity helpers ────────────────────
  //
  // The DOM inside the WebView is invisible to session replay.
  // Native events + tags below reproduce the funnel that answers:
  //   * did the user actually reach the offer site?
  //   * did they land on a register / login / cashier page?
  //   * did they submit an auth form or tap deposit?
  // High-cardinality values (urls, hosts, labels, error text) go
  // into TAGS, never into event names.

  void _trackWebPage(String url) {
    final Uri? uri = Uri.tryParse(url);
    OracleTrace.screenName(
      'web:${uri == null ? url : '${uri.host}${uri.path}'}',
    );
    OracleTrace.event('web_page');
    OracleTrace.tag('web_last_url', url);
    if (!_offerReached && !_pageHadError) {
      _offerReached = true;
      OracleTrace.event('web_offer_reached');
      OracleTrace.tag('offer_reached', 'true');
      if (uri?.host != null && uri!.host.isNotEmpty) {
        OracleTrace.tag('offer_host', uri.host);
      }
    }
    if (_depositRx.hasMatch(url)) {
      OracleTrace.event('web_cashier_page');
      OracleTrace.tag('reached_cashier', 'true');
    }
    _trackAuthPage(url);
  }

  void _trackAuthPage(String url) {
    if (_registerRx.hasMatch(url)) {
      OracleTrace.event('web_register_page');
      OracleTrace.tag('reached_register', 'true');
    } else if (_loginRx.hasMatch(url)) {
      OracleTrace.event('web_login_page');
      OracleTrace.tag('reached_login', 'true');
    }
  }

  static String _classifyWebError(WebResourceError err) {
    final String d = err.description.toLowerCase();
    final int c = err.errorCode;
    if (d.contains('connection_refused') ||
        d.contains('connection refused')) {
      return 'connection_refused';
    }
    if (d.contains('too_many_redirects') ||
        d.contains('too many redirects')) {
      return 'redirect_loop';
    }
    if (d.contains('name_not_resolved') ||
        d.contains('address_unreachable') ||
        d.contains('unknownhost') ||
        c == -2) {
      return 'dns_unresolved';
    }
    if (d.contains('timed out') || d.contains('timeout') || c == -8) {
      return 'timeout';
    }
    if (d.contains('internet_disconnected') ||
        d.contains('network_changed') ||
        c == -6) {
      return 'no_network';
    }
    if (d.contains('connection_reset')) return 'connection_reset';
    if (d.contains('connection_closed') ||
        d.contains('empty_response')) {
      return 'connection_closed';
    }
    if (d.contains('ssl') || d.contains('cert') || c == -11) {
      return 'ssl_error';
    }
    if (d.contains('blocked')) return 'blocked';
    return 'other';
  }

  /// Idempotent in-page probe — the `window.__psOracleLens` guard
  /// means calling this on every `onPageFinished` is a no-op after
  /// the first navigation. Reports SPA route changes, deposit /
  /// register / login clicks and auth form submits over the
  /// `PyramidLens` JS channel.
  void _installInsightProbe() {
    _web.runJavaScript(r'''
(function(){
  if (window.__psOracleLens) return; window.__psOracleLens = true;
  function send(t){ try { PyramidLens.postMessage(t); } catch(e){} }
  var DEP=/(deposit|cashier|top.?up|add funds|replenish|payment|pay now|checkout|withdraw|пополн|депозит|касс|оплат|внести|вывод|платеж)/i;
  var REG=/(sign.?up|regist|create.?account|регистрац|зарегистр)/i;
  var LOG=/(sign.?in|log.?in|log.?on|войти|вход|авториз)/i;
  var lastPath='';
  function reportPath(){ var p=location.pathname+location.search; if(p!==lastPath){ lastPath=p; send('path:'+p);} }
  reportPath();
  ['pushState','replaceState'].forEach(function(fn){ var o=history[fn]; history[fn]=function(){ var r=o.apply(this,arguments); setTimeout(reportPath,60); return r; }; });
  window.addEventListener('popstate',function(){ setTimeout(reportPath,60); });
  document.addEventListener('click',function(e){
    try{ var el=e.target;
      for(var i=0;i<4&&el;i++){
        var t=((el.innerText||el.value||(el.getAttribute&&el.getAttribute('aria-label'))||'')+'').trim();
        if(t){ if(DEP.test(t)){send('deposit_click:'+t.slice(0,60));return;}
               if(REG.test(t)){send('register_click:'+t.slice(0,60));return;}
               if(LOG.test(t)){send('login_click:'+t.slice(0,60));return;} }
        el=el.parentElement;
      }
    }catch(x){}
  },true);
  document.addEventListener('submit',function(e){
    try{ var f=e.target;
      var pw=f.querySelectorAll?f.querySelectorAll('input[type="password"]'):[];
      var blob=((f.innerText||'')+' '+(f.getAttribute('action')||'')+' '+(f.className||''));
      var confirm=f.querySelector&&(f.querySelector('input[name*="confirm" i]')||f.querySelector('input[name*="repeat" i]'));
      if(pw&&pw.length>=2){send('auth_submit:register');return;}
      if(pw&&pw.length===1){ send('auth_submit:'+((confirm||REG.test(blob))?'register':'login')); return; }
      if(REG.test(blob)){send('auth_submit:register');return;}
      if(LOG.test(blob)){send('auth_submit:login');return;}
      send('form_submit');
    }catch(x){ send('form_submit'); }
  },true);
})();
''');
  }

  void _onWebSignal(String raw) {
    final int i = raw.indexOf(':');
    final String type = i < 0 ? raw : raw.substring(0, i);
    final String data = i < 0 ? '' : raw.substring(i + 1);
    switch (type) {
      case 'path':
        OracleTrace.event('web_spa_route');
        OracleTrace.tag('web_last_path', data);
        if (_depositRx.hasMatch(data)) {
          OracleTrace.event('web_cashier_page');
          OracleTrace.tag('reached_cashier', 'true');
        }
        _trackAuthPage(data);
        break;
      case 'deposit_click':
        OracleTrace.event('web_deposit_click');
        OracleTrace.tag('deposit_intent', 'true');
        if (data.isNotEmpty) OracleTrace.tag('deposit_label', data);
        break;
      case 'register_click':
        OracleTrace.event('web_register_click');
        OracleTrace.tag('register_intent', 'true');
        break;
      case 'login_click':
        OracleTrace.event('web_login_click');
        OracleTrace.tag('login_intent', 'true');
        break;
      case 'auth_submit':
        if (data == 'register') {
          OracleTrace.event('web_register_submit');
          OracleTrace.tag('attempted_register', 'true');
        } else {
          OracleTrace.event('web_login_submit');
          OracleTrace.tag('attempted_login', 'true');
        }
        break;
      case 'form_submit':
        OracleTrace.event('web_form_submit');
        break;
    }
  }

  /// Android WebView does NOT open `target="_blank"` links or
  /// `window.open(...)` calls by default — `WebChromeClient
  /// .onCreateWindow` is not wired into the public plugin API, so
  /// those clicks just no-op. We fix it in JS: every click on an
  /// anchor with `target="_blank"` (or a middle click, or a
  /// programmatic window.open) is rewritten to a top-level
  /// navigation, which our NavigationDelegate then handles like any
  /// other page transition.
  void _injectLinkFix() {
    _web.runJavaScript(r'''
(function(){
  if (window.__psLinkFix) return;
  window.__psLinkFix = true;

  function follow(href){
    if (!href) return;
    try {
      var abs = new URL(href, document.baseURI).href;
      window.top.location.href = abs;
    } catch (e) {
      window.top.location.href = href;
    }
  }

  // 1. Rewire window.open — always route to top-level nav.
  var origOpen = window.open;
  window.open = function(url, target, features){
    if (url) { follow(url); return null; }
    try { return origOpen.apply(window, arguments); } catch(_) { return null; }
  };

  // 2. Neutralise target="_blank" on every anchor click.
  function normalise(root){
    var anchors = root.querySelectorAll ? root.querySelectorAll('a[target]') : [];
    for (var i = 0; i < anchors.length; i++){
      var a = anchors[i];
      var t = (a.getAttribute('target') || '').toLowerCase();
      if (t === '_blank' || t === '_new') a.setAttribute('target', '_self');
    }
  }
  normalise(document);

  // 3. Capture clicks early — beat any host handler that only
  //    prevents defaults on target=_self.
  document.addEventListener('click', function(e){
    if (e.defaultPrevented) return;
    if (e.button && e.button !== 0) return;
    var el = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (!el) return;
    var href = el.getAttribute('href');
    if (!href) return;
    if (/^\s*javascript:/i.test(href)) return; // let JS handlers run
    var t = (el.getAttribute('target') || '').toLowerCase();
    if (t === '_blank' || t === '_new' || e.metaKey || e.ctrlKey){
      e.preventDefault();
      e.stopPropagation();
      follow(href);
    }
  }, true);

  // 4. Newly added anchors (SPA renders) also get normalised.
  try {
    var mo = new MutationObserver(function(mutations){
      for (var i = 0; i < mutations.length; i++){
        var m = mutations[i];
        for (var j = 0; j < m.addedNodes.length; j++){
          var n = m.addedNodes[j];
          if (n && n.nodeType === 1) normalise(n);
        }
      }
    });
    mo.observe(document.documentElement, { childList: true, subtree: true });
  } catch(_) {}
})();
''');
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
