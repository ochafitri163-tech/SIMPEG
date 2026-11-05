import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TurnstilePlatformView extends StatefulWidget {
  final String siteKey;
  final ValueChanged<String> onVerified;
  final VoidCallback? onExpired;
  final ValueChanged<String>? onError;
  final VoidCallback? onLoaded;
  final String baseUrl;

  const TurnstilePlatformView({
    super.key,
    required this.siteKey,
    required this.onVerified,
    this.onExpired,
    this.onError,
    this.onLoaded,
    this.baseUrl = 'https://jyywrknlkqwmiqokmcju.supabase.co',
  });

  @override
  State<TurnstilePlatformView> createState() => TurnstilePlatformViewState();
}

class TurnstilePlatformViewState extends State<TurnstilePlatformView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void reset() {
    _controller.reload();
  }

  void _initController() {
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
  <style>
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      display: flex;
      justify-content: center;
      align-items: center;
      background: transparent;
      overflow: hidden;
    }
  </style>
</head>
<body>
  <div class="cf-turnstile"
       data-sitekey="${widget.siteKey}"
       data-callback="onTurnstileSuccess"
       data-error-callback="onTurnstileError"
       data-expired-callback="onTurnstileExpired"
       data-theme="light"></div>
  <script>
    try {
      if (window.TurnstileBridge) {
        TurnstileBridge.postMessage(JSON.stringify({
          type: 'debug',
          origin: window.location.origin,
          host: window.location.host,
          hostname: window.location.hostname,
          href: window.location.href
        }));
      }
    } catch (e) {}

    function onTurnstileSuccess(token) {
      if (window.TurnstileBridge) {
        TurnstileBridge.postMessage(JSON.stringify({ type: 'success', token: token }));
      }
    }
    function onTurnstileError(error) {
      if (window.TurnstileBridge) {
        TurnstileBridge.postMessage(JSON.stringify({ type: 'error', error: error }));
      }
    }
    function onTurnstileExpired() {
      if (window.TurnstileBridge) {
        TurnstileBridge.postMessage(JSON.stringify({ type: 'expired' }));
      }
    }
  </script>
</body>
</html>
''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36')
      ..addJavaScriptChannel(
        'TurnstileBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          debugPrint('>>> [Turnstile Mobile] Received: ${msg.message}');
          try {
            final data = jsonDecode(msg.message) as Map<String, dynamic>;
            final type = data['type'] as String?;
            if (type == 'success') {
              final token = data['token'] as String;
              widget.onVerified(token);
            } else if (type == 'expired') {
              widget.onExpired?.call();
            } else if (type == 'error') {
              debugPrint('>>> [Turnstile Mobile Error] ${data['error']}');
              widget.onError?.call(data['error']?.toString() ?? 'Verifikasi gagal');
            }
          } catch (e) {
            debugPrint('>>> [Turnstile Mobile Parse Error] $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            debugPrint('>>> [Turnstile Mobile] Page finished: $url');
            widget.onLoaded?.call();
          },
          onWebResourceError: (error) {
            debugPrint(
                '>>> [Turnstile Mobile WebResourceError] ${error.errorCode}: ${error.description} on ${error.url}');
          },
        ),
      )
      ..loadHtmlString(html, baseUrl: widget.baseUrl);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

