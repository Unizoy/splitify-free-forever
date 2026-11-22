import 'package:flutter/material.dart';
import 'package:splitify/features/app_lock/application/app_lock_controller.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Full-screen lock (X2): soft blobs, the brand, a lock badge, one Unlock button. Covers the whole
/// app (it sits above the navigator), so nothing behind it can be read or tapped.
class LockScreen extends StatelessWidget {
  const LockScreen({required this.state, required this.onUnlock, super.key});

  final AppLockState state;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final failed = state.notice == LockNotice.failed;
    return Material(
      key: const Key('lock-screen'),
      color: c.bg,
      child: BlobBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpacing.s8),
                    const BrandMark(size: 48, tile: true),
                    const SizedBox(height: AppSpacing.s10),
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: c.primaryContainer,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.float(c, dark: context.isDark),
                      ),
                      child: Icon(AppIcons.lockFill, size: 44, color: c.onPrimaryContainer),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Semantics(
                      header: true,
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: AppText.maxSerifScale,
                        child: Text(
                          l.lockTitle,
                          textAlign: TextAlign.center,
                          style: context.text.headline,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Text(
                      l.lockBody,
                      textAlign: TextAlign.center,
                      style: context.text.body.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    PillButton(
                      key: const Key('lock-unlock'),
                      label: l.lockUnlock,
                      icon: AppIcons.fingerprint,
                      loading: state.authenticating,
                      onPressed: state.authenticating ? null : onUnlock,
                    ),
                    if (failed) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          l.lockConfirmFailed,
                          key: const Key('lock-failed'),
                          textAlign: TextAlign.center,
                          style: context.text.bodySmall.copyWith(color: c.oweText),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain cover while the app is in the background with the lock on: the last frame Android keeps
/// (and shows for a moment on return) holds no balances.
class LockCover extends StatelessWidget {
  const LockCover({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('lock-cover'),
    color: context.colors.bg,
    child: const Center(child: BrandMark(size: 64, tile: true)),
  );
}
