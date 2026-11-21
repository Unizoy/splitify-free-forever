import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/ui/theme/theme.dart';

/// One destination of the [CapsuleNavBar].
class CapsuleNavItem {
  const CapsuleNavItem({required this.label, this.icon, this.activeIcon, this.leading});

  final String label;
  final IconData? icon;
  final IconData? activeIcon;

  /// Custom leading widget instead of [icon] (the Account avatar).
  final Widget? leading;
}

/// Floating capsule nav (438, 542): white pill bar (dark: surface + border)
/// with a soft shadow. The active destination is a black pill with icon and
/// label whose width springs open; others show the icon only. An amber round
/// "+" button can sit to the right.
class CapsuleNavBar extends StatelessWidget {
  const CapsuleNavBar({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.onAdd,
    this.addLabel,
    super.key,
  });

  final List<CapsuleNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Shows the amber + button when set.
  final VoidCallback? onAdd;
  final String? addLabel;

  static const _inactiveWidth = 56.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = context.isDark;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.navSide,
        0,
        AppSpacing.navSide,
        AppSpacing.navBottom + bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: AppSpacing.navHeight),
              padding: const EdgeInsets.all(AppSpacing.s2),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: AppRadii.allPill,
                border: Border.all(color: dark ? c.border : c.surface),
                boxShadow: AppShadows.float(c, dark: dark),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final activeWidth = constraints.maxWidth - _inactiveWidth * (items.length - 1);
                  return Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        AnimatedContainer(
                          duration: context.motion.showcase,
                          curve: context.motion.spring,
                          width: i == currentIndex ? activeWidth : _inactiveWidth,
                          child: _NavButton(
                            item: items[i],
                            active: i == currentIndex,
                            onTap: () {
                              if (i != currentIndex) HapticFeedback.selectionClick();
                              onSelected(i);
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: AppSpacing.s3),
            _AddButton(onTap: onAdd!, label: addLabel ?? ''),
          ],
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.onTap});

  final CapsuleNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = active ? c.onInk : c.textPrimary;
    final icon =
        item.leading ??
        Icon(active ? (item.activeIcon ?? item.icon) : item.icon, size: 24, color: fg);
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: Tooltip(
        message: active ? '' : item.label,
        excludeFromSemantics: true,
        child: AnimatedContainer(
          duration: context.motion.base,
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
          decoration: BoxDecoration(
            color: active ? c.ink : AppPalette.clear,
            borderRadius: AppRadii.allPill,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadii.allPill,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.s2),
                child: ClipRect(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      if (active) ...[
                        const SizedBox(width: AppSpacing.s2),
                        Flexible(
                          child: MediaQuery.withClampedTextScaling(
                            maxScaleFactor: 1.15,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                              style: context.text.button.copyWith(color: fg),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: c.money,
          shape: const CircleBorder(),
          elevation: 0,
          shadowColor: AppPalette.clear,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            customBorder: const CircleBorder(),
            child: Container(
              width: AppSpacing.navAdd,
              height: AppSpacing.navAdd,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppShadows.float(c, dark: context.isDark),
              ),
              child: Icon(AppIcons.add, size: 26, color: c.onMoney),
            ),
          ),
        ),
      ),
    );
  }
}
