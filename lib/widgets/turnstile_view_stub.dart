import 'package:flutter/material.dart';

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
  void reset() {}

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

