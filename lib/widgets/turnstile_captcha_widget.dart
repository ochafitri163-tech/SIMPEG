import 'package:flutter/material.dart';

import 'turnstile_view_stub.dart'
    if (dart.library.js_interop) 'turnstile_view_web.dart'
    if (dart.library.io) 'turnstile_view_mobile.dart';

class TurnstileCaptchaWidget extends StatefulWidget {
  final String siteKey;
  final ValueChanged<String> onVerified;
  final VoidCallback? onExpired;
  final ValueChanged<String>? onError;
  final String baseUrl;

  const TurnstileCaptchaWidget({
    super.key,
    required this.siteKey,
    required this.onVerified,
    this.onExpired,
    this.onError,
    this.baseUrl = 'https://jyywrknlkqwmiqokmcju.supabase.co',
  });

  @override
  State<TurnstileCaptchaWidget> createState() => TurnstileCaptchaWidgetState();
}

class TurnstileCaptchaWidgetState extends State<TurnstileCaptchaWidget> {
  final GlobalKey<TurnstilePlatformViewState> _platformViewKey =
      GlobalKey<TurnstilePlatformViewState>();

  bool _isLoading = true;
  bool _isVerified = false;
  String? _errorMessage;

  void reset() {
    if (!mounted) return;
    setState(() {
      _isVerified = false;
      _isLoading = true;
      _errorMessage = null;
    });
    _platformViewKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isVerified ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TurnstilePlatformView(
            key: _platformViewKey,
            siteKey: widget.siteKey,
            baseUrl: widget.baseUrl,
            onLoaded: () {
              if (mounted) setState(() => _isLoading = false);
            },
            onVerified: (token) {
              if (mounted) {
                setState(() {
                  _isVerified = true;
                  _isLoading = false;
                });
              }
              widget.onVerified(token);
            },
            onExpired: () {
              if (mounted) setState(() => _isVerified = false);
              widget.onExpired?.call();
            },
            onError: (err) {
              if (mounted) {
                setState(() {
                  _isVerified = false;
                  _isLoading = false;
                  _errorMessage = err;
                });
              }
              widget.onError?.call(err);
            },
          ),
          if (_errorMessage != null)
            Container(
              color: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verifikasi gagal: $_errorMessage',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: const Color(0xFFEF4444),
                    onPressed: reset,
                    tooltip: 'Coba lagi',
                  ),
                ],
              ),
            ),
          if (_isLoading && _errorMessage == null)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}
