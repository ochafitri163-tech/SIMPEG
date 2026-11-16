import 'dart:async';
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
  JSFunction? onLoaded,
);

@JS('resetTurnstileWidget')
external void _jsResetTurnstileWidget(JSString elementId);

@JS('removeTurnstileWidget')
external void _jsRemoveTurnstileWidget(JSString elementId);

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
    this.baseUrl = 'http://127.0.0.1:8000',
  });

  @override
  State<TurnstilePlatformView> createState() => TurnstilePlatformViewState();
}

class TurnstilePlatformViewState extends State<TurnstilePlatformView> {
  static int _instanceSequence = 0;
  static const Duration _attachCheckInterval = Duration(milliseconds: 100);
  static const int _maxAttachAttempts = 100;
  static const Duration _interopRetryInterval = Duration(milliseconds: 150);
  static const int _maxInteropRetries = 5;

  late final String _elementId;
  late final String _viewType;

  web.HTMLDivElement? _container;
  web.MutationObserver? _domObserver;
  Timer? _attachTimer;
  Timer? _retryTimer;

  int _attachAttempts = 0;
  int _interopRetries = 0;
  bool _isRendered = false;
  bool _isRendering = false;
  bool _hasError = false;
  bool _disposed = false;
  String? _widgetId;

  @override
  void initState() {
    super.initState();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final sequence = ++_instanceSequence;
    _elementId = 'cf-turnstile-$timestamp-$sequence';
    _viewType = 'turnstile-view-$timestamp-$sequence';

    _ensureTurnstileScript();
    _registerViewFactory();
  }

  void _ensureTurnstileScript() {
    final existingScript =
        web.document.querySelector('script[src*="challenges.cloudflare.com"]');
    if (existingScript == null) {
      final script = web.HTMLScriptElement()
        ..src =
            'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'
        ..async = true
        ..defer = true;
      web.document.head?.appendChild(script);
    }
  }

  void _registerViewFactory() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final div = web.HTMLDivElement()
        ..id = _elementId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'flex'
        ..style.justifyContent = 'center'
        ..style.alignItems = 'center';

      if (!_disposed && mounted) {
        _container = div;
        _startObservingDomAttachment(div);
      }
      return div;
    });
  }

  bool _isContainerConnected(web.HTMLDivElement? div) {
    return !_disposed &&
        mounted &&
        div != null &&
        div.isConnected &&
        web.document.getElementById(_elementId) != null;
  }

  void _startObservingDomAttachment(web.HTMLDivElement div) {
    _stopDomObservation();
    if (_disposed || !mounted || _isRendered || _isRendering) return;

    _attachAttempts = 0;

    final web.Node? observeTarget =
        web.document.body ?? web.document.documentElement;
    if (observeTarget != null) {
      _domObserver = web.MutationObserver(
        ((JSArray<web.MutationRecord> mutations, web.MutationObserver observer) {
          if (_disposed || !mounted) {
            _stopDomObservation();
            return;
          }
          if (_isContainerConnected(div)) {
            _onContainerAttached();
          }
        }).toJS,
      );
      _domObserver!.observe(
        observeTarget,
        web.MutationObserverInit(childList: true, subtree: true),
      );
    }

    _attachTimer = Timer.periodic(_attachCheckInterval, (timer) {
      if (_disposed || !mounted || _isRendered || _isRendering) {
        _stopDomObservation();
        return;
      }
      if (_isContainerConnected(div)) {
        _onContainerAttached();
        return;
      }
      _attachAttempts += 1;
      if (_attachAttempts >= _maxAttachAttempts) {
        _stopDomObservation();
        _reportError('Container verifikasi keamanan gagal terpasang ke DOM');
      }
    });
  }

  void _stopDomObservation() {
    _domObserver?.disconnect();
    _domObserver = null;
    _attachTimer?.cancel();
    _attachTimer = null;
  }

  void _onContainerAttached() {
    _stopDomObservation();
    if (_disposed || !mounted || _isRendered || _isRendering) return;
    if (!_isContainerConnected(_container)) return;

    _interopRetries = 0;
    _hasError = false;
    _isRendering = true;
    _renderWidget();
  }

  void _renderWidget() {
    if (_disposed || !mounted || _isRendered) {
      _isRendering = false;
      return;
    }

    final div = _container;
    if (!_isContainerConnected(div)) {
      _isRendering = false;
      if (div != null) {
        _startObservingDomAttachment(div);
      }
      return;
    }

    try {
      _jsRenderTurnstileWidget(
        _elementId.toJS,
        widget.siteKey.toJS,
        ((JSString token) {
          if (_disposed || !mounted) return;
          widget.onVerified(token.toDart);
        }).toJS,
        ((JSAny? error) {
          if (_disposed || !mounted) return;
          _isRendering = false;
          _reportError(_formatJsError(error));
        }).toJS,
        (() {
          if (_disposed || !mounted) return;
          widget.onExpired?.call();
        }).toJS,
        ((JSString widgetId) {
          if (_disposed || !mounted) return;
          final parsedId = widgetId.toDart.trim();
          if (parsedId.isEmpty) {
            _isRendering = false;
            _isRendered = false;
            _widgetId = null;
            _reportError('Widget ID Turnstile tidak valid');
            return;
          }
          _retryTimer?.cancel();
          _retryTimer = null;
          _isRendering = false;
          _isRendered = true;
          _hasError = false;
          _widgetId = parsedId;
          widget.onLoaded?.call();
        }).toJS,
      );
    } catch (e) {
      _isRendering = false;
      if (_disposed || !mounted) return;
      if (_interopRetries < _maxInteropRetries) {
        _interopRetries += 1;
        _retryTimer?.cancel();
        _retryTimer = Timer(_interopRetryInterval, () {
          if (_disposed || !mounted || _isRendered || _isRendering) return;
          final currentDiv = _container;
          if (_isContainerConnected(currentDiv)) {
            _isRendering = true;
            _renderWidget();
          } else if (currentDiv != null) {
            _startObservingDomAttachment(currentDiv);
          }
        });
      } else {
        _reportError('Gagal memulai verifikasi keamanan: $e');
      }
    }
  }

  String _formatJsError(JSAny? error) {
    if (error == null) return 'Verifikasi gagal';
    try {
      final dartValue = error.dartify();
      final msg = dartValue?.toString().trim() ?? '';
      if (msg.isNotEmpty) return msg;
    } catch (_) {}
    final raw = error.toString().trim();
    return raw.isEmpty ? 'Verifikasi gagal' : raw;
  }

  void _reportError(String message) {
    if (_disposed || !mounted) return;
    _hasError = true;
    widget.onError?.call(message.isEmpty ? 'Verifikasi gagal' : message);
  }

  void reset() {
    if (_disposed || !mounted) return;
    _retryTimer?.cancel();
    _retryTimer = null;

    final div = _container;
    final connected = _isContainerConnected(div);

    if (_isRendered && _widgetId != null && connected) {
      _hasError = false;
      try {
        _jsResetTurnstileWidget(_elementId.toJS);
      } catch (e) {
        _isRendered = false;
        _widgetId = null;
        _reportError('Gagal mereset verifikasi keamanan: $e');
      }
      return;
    }

    if (_hasError || !_isRendered || _widgetId == null) {
      _hasError = false;
      _isRendering = false;
      _interopRetries = 0;

      if (connected) {
        _isRendering = true;
        _renderWidget();
      } else if (div != null) {
        _startObservingDomAttachment(div);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopDomObservation();
    _retryTimer?.cancel();
    _retryTimer = null;

    try {
      _jsRemoveTurnstileWidget(_elementId.toJS);
    } catch (_) {}

    _container = null;
    _widgetId = null;
    _isRendered = false;
    _isRendering = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
