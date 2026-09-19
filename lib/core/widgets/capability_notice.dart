import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../local_ai/capabilities.dart';
import '../design/app_theme.dart';
import '../design/design_tokens.dart';
import '../../l10n/l10n.dart';

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
    this.flat = false,
    super.key,
  });

  final LocalAiCapabilities capabilities;

  /// Offered only for states that can actually resolve.
  final VoidCallback? onRetry;

  final bool compact;

  /// Drops the surrounding card, for when the notice already sits inside one.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final tier = capabilities.tier;
    final l10n = context.l10n;

    final (IconData icon, String message, Color color) = switch (tier) {
      CapabilityTier.fullLocalAi => (
        LucideIcons.sparkles,
        l10n.capReady,
        context.colors.primary,
      ),
      CapabilityTier.eligibleNotReady => (
        LucideIcons.hourglass,
        _notReadyMessage(l10n),
        semantics.caution,
      ),
      CapabilityTier.baselineParsing => (
        LucideIcons.calendarClock,
        l10n.capBaseline,
        semantics.muted,
      ),
      CapabilityTier.manualCore => (
        LucideIcons.pencilLine,
        l10n.capManual,
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

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _wash(context, tier),
            borderRadius: Corners.chip,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Text(
            message,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
        ),
        if (onRetry != null && capabilities.availability.isRecoverable) ...[
          const SizedBox(width: Insets.sm),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            ),
            child: Text(l10n.capCheckAgain),
          ),
        ],
      ],
    );

    if (flat) return row;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: semantics.sunken,
        borderRadius: Corners.card,
        border: Border.all(color: semantics.hairline),
      ),
      child: row,
    );
  }

  Color _wash(BuildContext context, CapabilityTier tier) {
    final semantics = context.semantics;
    return switch (tier) {
      CapabilityTier.fullLocalAi => semantics.accentSoft,
      CapabilityTier.eligibleNotReady => semantics.cautionSoft,
      _ => semantics.sunken,
    };
  }

  /// Names the exact recoverable state rather than a generic "unavailable".
  String _notReadyMessage(AppLocalizations l10n) =>
      switch (capabilities.availability) {
        AiAvailability.disabled => l10n.capDisabled,
        AiAvailability.modelNotReady => l10n.capNotReady,
        AiAvailability.busy => l10n.capBusy,
        _ => l10n.capFallback,
      };
}
