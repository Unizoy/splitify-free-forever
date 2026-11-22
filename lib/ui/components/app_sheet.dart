import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Opens an [AppSheet] as a modal bottom sheet over a scrim.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    barrierColor: context.colors.scrim,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
    clipBehavior: Clip.antiAlias,
    // Quick, decelerating rise that reads as a spring without overshooting the edge (S-263).
    sheetAnimationStyle: AnimationStyle(
      duration: context.motion.slow,
      curve: AppMotion.emphasized,
      reverseDuration: context.motion.fast,
      reverseCurve: Curves.easeIn,
    ),
    builder: (context) => AppSheet(title: title, child: builder(context)),
  );
}

/// Bottom-sheet body (614): 36×4 handle, centred serif title, content.
class AppSheet extends StatelessWidget {
  const AppSheet({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, borderRadius: AppRadii.sheetTop),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s3,
            AppSpacing.screen,
            AppSpacing.s6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: c.sheetHandle, borderRadius: AppRadii.allPill),
                ),
              ),
              const SizedBox(height: AppSpacing.s5),
              Semantics(
                header: true,
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: AppText.maxSerifScale,
                  child: Text(title, textAlign: TextAlign.center, style: context.text.sheetTitle),
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
