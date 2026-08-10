import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../local_ai/capabilities.dart';
import '../design/app_theme.dart';
import '../design/design_tokens.dart';

/// Explains, in one line, what kind of understanding is available right now.
///
/// The tone rules come straight from the BRD: an older or not-yet-ready device
/// is never presented as broken, the message names a recoverable state
/// precisely when there is one, and there is no upgrade pressure.
class CapabilityNotice extends StatelessWidget {
  const CapabilityNotice({
    required this.capabilities,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  final LocalAiCapabilities capabilities;

  /// Offered only for states that can actually resolve.
  final VoidCallback? onRetry;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final tier = capabilities.tier;

    final (IconData icon, String message, Color color) = switch (tier) {
      CapabilityTier.fullLocalAi => (
        LucideIcons.sparkles,
        'Enhanced on-device understanding is ready.',
        context.colors.primary,
      ),
      CapabilityTier.eligibleNotReady => (
        LucideIcons.hourglass,
        _notReadyMessage(),
        semantics.caution,
      ),
      CapabilityTier.baselineParsing => (
        LucideIcons.calendarClock,
        'Quick date parsing is available on this device.',
        semantics.muted,
      ),
      CapabilityTier.manualCore => (
        LucideIcons.pencilLine,
        'Type the details and they will be saved exactly as entered.',
        semantics.muted,
      ),
    };

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: Insets.xs + 2),
          Flexible(
            child: Text(
              message,
              style: context.texts.bodySmall?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: semantics.sunken,
        borderRadius: Corners.card,
        border: Border.all(color: semantics.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              message,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ),
          if (onRetry != null && capabilities.availability.isRecoverable)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              ),
              child: const Text('Check again'),
            ),
        ],
      ),
    );
  }

  /// Names the exact recoverable state rather than a generic "unavailable".
  String _notReadyMessage() => switch (capabilities.availability) {
    AiAvailability.disabled =>
      'On-device AI is turned off in system settings. '
          'Date parsing still works here.',
    AiAvailability.modelNotReady =>
      'The on-device model is still getting ready. '
          'Date parsing is being used in the meantime.',
    AiAvailability.busy =>
      'The on-device model is busy. Date parsing is being used for now.',
    _ => 'Date parsing is being used for now.',
  };
}
