import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({super.key, required this.url, required this.title});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) {
            _fitToViewport();
            setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// The support/privacy HTML on pyramidseccret.com ships without a
  /// `<meta name="viewport">` tag, so Android WebView renders it as a
  /// 980 px desktop page — the 400 px card ends up looking tiny in the
  /// middle of the screen ("сильно отдалился"). Inject a mobile
  /// viewport once the page settles, force the layout root to match
  /// device width and kill any horizontal overflow that would produce
  /// a scroll gutter. Safe to run against pages that already have a
  /// viewport tag — the setAttribute call is a no-op in that case.
  void _fitToViewport() {
    _controller.runJavaScript(r'''
(function(){
  try {
    var v = document.querySelector('meta[name="viewport"]');
    if (!v) {
      v = document.createElement('meta');
      v.setAttribute('name','viewport');
      (document.head || document.documentElement).appendChild(v);
    }
    v.setAttribute('content','width=device-width, initial-scale=1, maximum-scale=5');
    var s = document.getElementById('__ps_fit');
    if (!s) {
      s = document.createElement('style');
      s.id = '__ps_fit';
      (document.head || document.documentElement).appendChild(s);
    }
    s.textContent =
      'html,body{margin:0!important;padding:0!important;' +
        'width:100%!important;max-width:100%!important;' +
        'overflow-x:hidden!important;-webkit-text-size-adjust:100%!important;}';
  } catch(e){}
})();
''');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        // No AppBar — the page renders full-width and the entire chrome
        // is the floating Back pill. The WebView itself lives inside a
        // SafeArea so notches / status bar / gesture insets never eat
        // into the page content.
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              WebViewWidget(controller: _controller),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              Positioned(
                top: 8,
                left: 8,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
