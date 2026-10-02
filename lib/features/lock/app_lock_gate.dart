import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../services/security/device_authenticator.dart';
import '../../l10n/l10n.dart';

/// Optional App Lock (BRD §17 "lost/unlocked device" control).
///
/// Sits above the navigator, so everything underneath — including a screen
/// opened from a notification tap — stays mounted and simply waits behind the
/// lock. The app locks on a cold start and after it has been in the
/// background for [lockAfter]; shorter trips (answering a message, the share
/// sheet) do not ask again.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  static const Duration lockAfter = Duration(seconds: 30);

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late final AppLifecycleListener _lifecycle;

  /// Null until settings have loaded; the gate covers the app until then so
  /// task content never flashes before the lock appears.
  bool? _locked;
  DateTime? _backgroundedAt;
  bool _obscured = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onInactive: () => setState(() => _obscured = true),
      onHide: () => _backgroundedAt ??= ref.read(clockProvider)(),
      onResume: _onResume,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  bool get _enabled =>
      ref.read(settingsProvider).valueOrNull?.appLockEnabled ?? false;

  void _onResume() {
    final away = _backgroundedAt;
    _backgroundedAt = null;
    final now = ref.read(clockProvider)();
    setState(() {
      _obscured = false;
      if (_enabled &&
          away != null &&
          now.difference(away) >= AppLockGate.lockAfter) {
        _locked = true;
      }
    });
    if (_locked == true) _unlock();
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    _authenticating = true;
    final l10n = context.l10n;
    final result = await ref
        .read(deviceAuthenticatorProvider)
        .authenticate(l10n.lockUnlockReason);
    _authenticating = false;
    if (!mounted) return;

    switch (result) {
      case UnlockResult.unlocked:
        setState(() => _locked = false);
      case UnlockResult.unavailable:
        // The phone no longer has a passcode, so there is nothing to check
        // against. Staying locked would only lock the owner out.
        final store = ref.read(settingsStoreProvider);
        final settings = await store.read();
        await store.write(settings.copyWith(appLockEnabled: false));
        if (!mounted) return;
        setState(() => _locked = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(l10n.lockTurnedOffNoPasscode)),
        );
      case UnlockResult.cancelled || UnlockResult.failed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final enabled = settings.valueOrNull?.appLockEnabled;

    // First settings load decides the cold-start state.
    if (_locked == null && enabled != null) {
      _locked = enabled;
      if (enabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
      }
    }
    // Turned off in Settings while unlocked: nothing more to do. Turned on:
    // the user just proved who they are, so it takes effect next time.
    if (enabled == false) _locked = false;

    final loading = settings.isLoading && !settings.hasValue;
    final showLock = _locked == true;
    final cover = loading || showLock || (_obscured && enabled == true);

    return Stack(
      children: <Widget>[
        ExcludeSemantics(excluding: cover, child: widget.child),
        if (cover)
          Positioned.fill(
            child: _LockScreen(
              showUnlock: showLock && !loading,
              onUnlock: _unlock,
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.showUnlock, required this.onUnlock});

  final bool showUnlock;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    return Material(
      color: context.colors.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: AnimatedOpacity(
              opacity: showUnlock ? 1 : 0,
              duration: Motion.fast,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: semantics.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.lock,
                      size: 28,
                      color: context.colors.primary,
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  Text(
                    context.l10n.lockTitle,
                    style: context.texts.titleLarge,
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    context.l10n.lockBody,
                    textAlign: TextAlign.center,
                    style: context.texts.bodyMedium?.copyWith(
                      color: semantics.muted,
                    ),
                  ),
                  const SizedBox(height: Insets.xl),
                  FilledButton.icon(
                    onPressed: showUnlock ? onUnlock : null,
                    icon: const Icon(LucideIcons.scanFace, size: 18),
                    label: Text(context.l10n.unlock),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
