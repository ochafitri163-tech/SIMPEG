import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

@JS('renderTurnstileWidget')
external void _jsRenderTurnstileWidget(
  JSString elementId,
  JSString siteKey,
  JSFunction onSuccess,
  JSFunction? onError,
  JSFunction? onExpired,
);

@JS('resetTurnstileWidget')
external void _jsResetTurnstileWidget(JSString elementId);

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
  late final String _elementId;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    _elementId = 'cf-turnstile-$timestamp';
    _viewType = 'turnstile-view-$timestamp';

    _ensureTurnstileScript();
    _registerViewFactory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _renderWidget();
    });
  }

  void _ensureTurnstileScript() {
    final existingScript =
        web.document.querySelector('script[src*="challenges.cloudflare.com"]');
    if (existingScript == null) {
      final script = web.HTMLScriptElement();
      script.src =
          'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
      script.async = true;
      script.defer = true;
      web.document.head?.appendChild(script);
    }

    final existingHelper =
        web.document.querySelector('script#turnstile-helper-script');
    if (existingHelper == null) {
      final helper = web.HTMLScriptElement();
      helper.id = 'turnstile-helper-script';
      helper.text = '''
        window.renderTurnstileWidget = function(elementId, siteKey, onSuccess, onError, onExpired) {
          function checkAndRender() {
            if (window.turnstile && typeof window.turnstile.render === 'function') {
              try {
                window.turnstile.render('#' + elementId, {
                  sitekey: siteKey,
                  callback: function(token) { if (onSuccess) onSuccess(token); },
                  'error-callback': function(err) { if (onError) onError(err); },
                  'expired-callback': function() { if (onExpired) onExpired(); },
                  theme: 'light'
                });
              } catch (e) {
                console.error('Turnstile render error:', e);
              }
            } else {
              setTimeout(checkAndRender, 150);
            }
          }
          checkAndRender();
        };

        window.resetTurnstileWidget = function(elementId) {
          if (window.turnstile && typeof window.turnstile.reset === 'function') {
            try {
              window.turnstile.reset('#' + elementId);
            } catch (e) {
              console.error('Turnstile reset error:', e);
            }
          }
        };
      ''';
      web.document.head?.appendChild(helper);
    }
  }

  void _registerViewFactory() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final div = web.HTMLDivElement();
      div.id = _elementId;
      div.style.width = '100%';
      div.style.height = '100%';
      div.style.display = 'flex';
      div.style.justifyContent = 'center';
      div.style.alignItems = 'center';
      return div;
    });
  }

  void _renderWidget() {
    try {
      _jsRenderTurnstileWidget(
        _elementId.toJS,
        widget.siteKey.toJS,
        ((JSString token) {
          widget.onVerified(token.toDart);
        }).toJS,
        ((JSAny? error) {
          widget.onError?.call(error?.toString() ?? 'Verifikasi gagal');
        }).toJS,
        (() {
          widget.onExpired?.call();
        }).toJS,
      );
      widget.onLoaded?.call();
    } catch (_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _renderWidget();
      });
    }
  }

  void reset() {
    try {
      _jsResetTurnstileWidget(_elementId.toJS);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
