import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Live "still working" feedback for the AI waits (2026-09-27).
///
/// The AI edge functions retry Gemini 429/503 bursts server-side, so the
/// client sits on one long HTTP call with no progress events — the scripted
/// stage stories finish early and the wait goes silent, which reads as
/// "hung". This line keeps the wait honest: an elapsed-seconds counter that
/// never stops moving, plus a reassurance line that fades in once the wait
/// crosses [slowAfter]. These AI flows are the app's paid features — a wait
/// that visibly moves is one the user stays inside.
class AiWaitLine extends StatefulWidget {
  final DateTime startedAt;

  /// When the reassurance copy appears (~6s in the scan screen, 8s here).
  final Duration slowAfter;

  /// Center the line inside its column (full-screen waits) vs start-aligned
  /// (inside a card).
  final bool center;

  const AiWaitLine({
    super.key,
    required this.startedAt,
    this.slowAfter = const Duration(seconds: 8),
    this.center = false,
  });

  @override
  State<AiWaitLine> createState() => _AiWaitLineState();
}

class _AiWaitLineState extends State<AiWaitLine> {
  Timer? _ticker;
  int _elapsed = 0;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final elapsed = DateTime.now().difference(widget.startedAt);
    final secs = elapsed.inSeconds;
    final slow = elapsed >= widget.slowAfter;
    if (secs != _elapsed || slow != _slow) {
      setState(() {
        _elapsed = secs;
        _slow = slow;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: widget.center
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${l10n.aiWaitWorking} ${l10n.aiWaitElapsed('$_elapsed')}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          child: _slow
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.aiWaitSlow,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
