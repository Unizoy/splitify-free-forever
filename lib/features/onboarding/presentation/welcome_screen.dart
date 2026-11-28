import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/auth/application/pending_join.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Onboarding (`/welcome`, redesigned for D-029): the Groups hero's lavender → dusk background over the
/// whole page, a small brand bar, a product preview (two group covers fanned behind a frosted "Overall"
/// card), the serif "split it. / settle it." headline, three feature chips, then "Get started" (sign-in)
/// and "Have an invite? Join a group" (sign-in first, then the join screen; S-283).
///
/// Looks the same in light and dark mode (S-280); the launch splash uses its top colour.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  /// Built once: the welcome always wears the light theme's hero colours.
  static final ThemeData _theme = AppTheme.light();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Theme(
      data: _theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: AppPalette.clear,
          systemNavigationBarColor: AppPalette.clear,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Scaffold(
          backgroundColor: AppColors.light.heroTop,
          body: GlassBackdropHost(
            background: const _Backdrop(),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, box) => _Body(
                  height: box.maxHeight,
                  onStart: () {
                    AppHaptics.light();
                    ref.read(pendingJoinProvider).dropCodeless();
                    unawaited(context.push('/sign-in'));
                  },
                  // Signed out, the router keeps the join and opens sign-in first (S-283).
                  onInvite: () => unawaited(context.push('/join')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Groups hero background stretched over the page, a little darker toward the actions.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const HeroBackground(art: (seed: 'groups-home', family: CoverFamily.other)),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppPalette.black.withValues(alpha: 0),
              AppPalette.black.withValues(alpha: 0.4),
            ],
            stops: const [0.55, 1],
          ),
        ),
      ),
    ],
  );
}

/// Smallest preview area: the glass card alone fits (scaled down a touch on narrow phones).
const _previewFloor = 200.0;

class _Body extends StatelessWidget {
  const _Body({required this.height, required this.onStart, required this.onInvite});

  /// Height of the safe area; shorter content is spread over it, taller content scrolls.
  final double height;
  final VoidCallback onStart;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        // Spacers need a bounded height inside the scroll view; the preview answers the intrinsic pass
        // itself (its covers measure with a LayoutBuilder).
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.s2,
              AppSpacing.screen,
              AppSpacing.s4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TopBar(),
                const SizedBox(height: AppSpacing.s4),
                // The preview takes the free height: fanned covers when there is room, else the glass
                // card alone. Its text keeps its size (an illustration, skipped by screen readers), so
                // large text grows the words around it and the page scrolls (S-285).
                Expanded(
                  child: _IntrinsicFloor(
                    height: _previewFloor,
                    child: MediaQuery.withNoTextScaling(
                      child: LayoutBuilder(builder: (context, box) => _Preview(size: box.biggest)),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                const _Headline(),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  l.welcomeSubline,
                  textAlign: TextAlign.center,
                  style: context.text.body.copyWith(color: c.onHero.withValues(alpha: 0.72)),
                ),
                const SizedBox(height: AppSpacing.s5),
                const _Features(),
                const SizedBox(height: AppSpacing.s8),
                PillButton(
                  key: const Key('welcome-get-started'),
                  label: l.getStarted,
                  trailingIcon: AppIcons.arrowRight,
                  variant: PillVariant.inverse,
                  onPressed: onStart,
                ),
                const SizedBox(height: AppSpacing.s1),
                _InviteLink(onTap: onInvite),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  l.welcomeFooter.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: context.text.labelCaps.copyWith(color: c.onHero.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mark + "SPLITIFY" on the left, the lime "Free forever · no ads" pill on the right (wraps at large text).
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s3,
      runSpacing: AppSpacing.s2,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 28, tile: true),
            const SizedBox(width: AppSpacing.s2),
            Text(
              l.welcomeBrand.toUpperCase(),
              style: context.text.labelCaps.copyWith(color: c.onHero),
            ),
          ],
        ),
        StatusPill(label: l.welcomeBadge, icon: AppIcons.sparkle, tone: StatusPillTone.positive),
      ],
    );
  }
}

/// "split it." / "settle it." in the hero serif, the second line lime (the Groups hero's words).
class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    // One step up from the Groups hero: this is the page's message (S-282).
    final style = context.text.displayLarge.copyWith(color: c.onHero);
    return Semantics(
      header: true,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: AppText.maxSerifScale,
        child: Text.rich(
          TextSpan(
            text: '${l.welcomeLead}\n',
            children: [
              TextSpan(
                text: l.welcomeHighlight,
                style: style.copyWith(color: c.owedOnDark),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }
}

/// UPI settle-up · Works offline · No ads ever, as glass chips.
class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: [
        for (final (icon, label) in [
          (AppIcons.qr, l.welcomeFeatureUpi),
          (AppIcons.unsynced, l.welcomeFeatureOffline),
          (AppIcons.shieldCheck, l.welcomeFeatureNoAds),
        ])
          _FeatureChip(icon: icon, label: label),
      ],
    );
  }
}

/// A small glass chip (the glass pill's colours with the glass card's edge), compact enough that all three
/// fit one row on a 412 dp phone (S-282).
class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: c.onHero.withValues(alpha: 0.14),
        borderRadius: AppRadii.allPill,
        border: Border.all(color: c.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grows with the text a little, so large labels do not carry a tiny icon.
          Icon(
            icon,
            size: MediaQuery.textScalerOf(context).scale(14).clamp(14.0, 20.0),
            color: c.onHero,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, style: context.text.caption.w(600).copyWith(color: c.onHero)),
          ),
        ],
      ),
    );
  }
}

/// "Have an invite? **Join a group**": a quiet text link under the main button (48 dp tall).
class _InviteLink extends StatelessWidget {
  const _InviteLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final style = context.text.body;
    return Center(
      child: Semantics(
        button: true,
        label: '${l.welcomeInvitePrompt} ${l.joinGroup}',
        excludeSemantics: true,
        onTap: onTap,
        child: Pressable(
          key: const Key('welcome-invite'),
          onTap: onTap,
          borderRadius: AppRadii.allPill,
          highlightColor: c.onHero,
          haptic: PressHaptic.selection,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: Center(
                widthFactor: 1,
                child: Text.rich(
                  TextSpan(
                    text: '${l.welcomeInvitePrompt} ',
                    style: style.copyWith(color: c.onHero.withValues(alpha: 0.72)),
                    children: [
                      TextSpan(
                        text: l.joinGroup,
                        style: style.w(700).copyWith(color: c.onHero),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reports a fixed intrinsic height instead of asking its child (the preview's LayoutBuilder cannot answer
/// intrinsic queries); its real height comes from the [Expanded] around it.
class _IntrinsicFloor extends SingleChildRenderObjectWidget {
  const _IntrinsicFloor({required this.height, super.child});

  final double height;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderIntrinsicFloor(height);

  @override
  void updateRenderObject(BuildContext context, _RenderIntrinsicFloor renderObject) {
    renderObject.height = height;
  }
}

class _RenderIntrinsicFloor extends RenderProxyBox {
  _RenderIntrinsicFloor(this._height);

  double _height;
  double get height => _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;
}

/// Preview area below which the back covers are left out.
const _cardsFloor = 320.0;

/// Tallest the fanned preview grows; extra height is shared above and below it.
const _maxStack = 430.0;

/// Covers fan out to ±8°.
const double _fanAngle = 8 * math.pi / 180;

/// Covers start this far below and rise into place.
const _rise = 28.0;

/// The idle float waits this long after the entrance, so the glass card's blurred backdrop is taken
/// while nothing moves (S-267/S-279).
const _floatDelay = Duration(milliseconds: 800);

/// The product preview: a trip and a home cover fanned behind a frosted "Overall · you are owed ₹2,450"
/// card (S-281). Sample data from the ARB; decorative, so screen readers skip it. The parts rise and fan in
/// (≤ 350 ms with the stagger), then float ±3–4 dp on a 4 s loop; still when animations are removed.
class _Preview extends StatefulWidget {
  const _Preview({required this.size});

  /// Room for the preview.
  final Size size;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> with TickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _scheduleFloat();
    });
  late final _float = AnimationController(vsync: this);
  Timer? _floatStart;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.motion;
    _float.duration = motion.float;
    if (motion.reduced) {
      _floatStart?.cancel();
      _float
        ..stop()
        ..value = 0;
      _intro.value = 1;
      return;
    }
    if (!_started) {
      _started = true;
      _intro
        ..duration = motion.intro
        ..forward();
    }
  }

  void _scheduleFloat() {
    _floatStart?.cancel();
    _floatStart = Timer(_floatDelay, () {
      if (mounted && !context.motion.reduced) _float.repeat();
    });
  }

  @override
  void dispose() {
    _floatStart?.cancel();
    _intro.dispose();
    _float.dispose();
    super.dispose();
  }

  _Layer _layer({
    required Interval interval,
    required double phase,
    required double drift,
    required Widget child,
    double angle = 0,
  }) => _Layer(
    intro: _intro,
    float: _float,
    interval: interval,
    angle: angle,
    phase: phase,
    drift: drift,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final glass = _layer(
      interval: const Interval(0.3, 1, curve: AppMotion.emphasized),
      phase: 0.66,
      drift: 2.5,
      child: const _OverallCard(),
    );
    final Widget preview;
    if (size.height < _cardsFloor) {
      // Short screen: the glass card alone, scaled down a touch if it would not fit.
      final width = math.min(size.width, _FanLayout.glassMaxWidth);
      preview = Center(
        child: SizedBox(
          width: width,
          height: size.height,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: width, child: glass),
          ),
        ),
      );
    } else {
      final l = AppLocalizations.of(context);
      String money(int minor) => MoneyFormatter.list.format(minor, 'INR');
      preview = Center(
        child: SizedBox(
          width: size.width,
          height: math.min(size.height, _maxStack),
          child: CustomMultiChildLayout(
            delegate: _FanLayout(),
            children: [
              LayoutId(
                id: _Slot.left,
                child: _layer(
                  interval: const Interval(0, 0.7, curve: AppMotion.emphasized),
                  angle: -_fanAngle,
                  phase: 0,
                  drift: 3.5,
                  child: _Cover(
                    seed: 'welcome-goa',
                    family: CoverFamily.trip,
                    name: l.welcomeSampleTrip,
                    status: l.youAreOwed,
                    amount: money(310000),
                    tone: MoneyTone.owed,
                  ),
                ),
              ),
              LayoutId(
                id: _Slot.right,
                child: _layer(
                  interval: const Interval(0.15, 0.85, curve: AppMotion.emphasized),
                  angle: _fanAngle,
                  phase: 0.33,
                  drift: 3.5,
                  child: _Cover(
                    seed: 'welcome-flat',
                    family: CoverFamily.home,
                    name: l.welcomeSampleHome,
                    status: l.youOwe,
                    amount: money(65000),
                    tone: MoneyTone.owe,
                  ),
                ),
              ),
              LayoutId(id: _Slot.glass, child: glass),
            ],
          ),
        ),
      );
    }
    return ExcludeSemantics(child: RepaintBoundary(child: preview));
  }
}

/// One part of the preview: rises, fades and turns in over its slice of [intro], then drifts with [float].
class _Layer extends StatelessWidget {
  const _Layer({
    required this.intro,
    required this.float,
    required this.interval,
    required this.angle,
    required this.phase,
    required this.drift,
    required this.child,
  });

  final Animation<double> intro;
  final Animation<double> float;
  final Interval interval;

  /// Final tilt (radians), about the bottom centre.
  final double angle;

  /// Offset of this part in the float loop (0–1), so the parts never move together.
  final double phase;

  /// Float amplitude (dp).
  final double drift;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([intro, float]),
    builder: (context, child) {
      final t = interval.transform(intro.value);
      final dy = (1 - t) * _rise + drift * math.sin(2 * math.pi * (float.value + phase));
      return Opacity(
        opacity: (t * 1.5).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: angle * t,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        ),
      );
    },
    // Moving the cached layer never repaints the card.
    child: RepaintBoundary(child: child),
  );
}

/// A real group cover with a lifted shadow, as on the Groups grid.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.seed,
    required this.family,
    required this.name,
    required this.status,
    required this.amount,
    required this.tone,
  });

  final String seed;
  final CoverFamily family;
  final String name;
  final String status;
  final String amount;
  final MoneyTone tone;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: AppRadii.all28,
      boxShadow: AppShadows.lifted(context.colors),
    ),
    child: GroupCoverCard(
      seed: seed,
      family: family,
      name: name,
      statusLabel: status,
      amountText: amount,
      tone: tone,
      footer: false,
    ),
  );
}

/// The Groups glass card with sample numbers: Overall · YOU ARE OWED, ₹2,450, Asha, Rahul and you.
class _OverallCard extends StatelessWidget {
  const _OverallCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.s3,
            runSpacing: AppSpacing.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: c.onHero, shape: BoxShape.circle),
                    child: Icon(AppIcons.wallet, size: 18, color: c.primaryFill),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Text(l.overall, style: context.text.title.copyWith(color: c.onHero)),
                ],
              ),
              StatusPill(
                label: l.youAreOwed,
                icon: AppIcons.coins,
                tone: StatusPillTone.flat,
                iconColor: c.owedOnDark,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              MoneyFormatter.list.format(245000, 'INR'),
              style: context.text.amountHero.copyWith(color: c.owedOnDark),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              AvatarStack(
                people: [
                  (name: l.welcomeSampleAsha, seed: 'welcome-asha', tint: 1),
                  (name: l.welcomeSampleRahul, seed: 'welcome-rahul', tint: 3),
                  (name: l.you, seed: 'welcome-you', tint: 0),
                ],
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  [l.homeGroupsCount(2), l.homePeopleOweYou(2)].join('\u00A0· '),
                  style: context.text.bodySmall.copyWith(color: c.onHero.withValues(alpha: 0.78)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _Slot { left, right, glass }

/// Glass card at the bottom centre; the two covers above it, side by side and overlapping a little,
/// tall enough to tuck their footers under the glass so their icon and name stay in view.
class _FanLayout extends MultiChildLayoutDelegate {
  static const glassMaxWidth = 340.0;

  /// Room above the covers for their tilted corners.
  static const _top = 14.0;

  /// How far the covers reach under the glass card (their footer-less bottom: art only).
  static const _tuck = 40.0;

  /// Cover width / height (the grid uses 0.62; a little wider reads better tilted).
  static const _aspect = 0.68;

  @override
  void performLayout(Size size) {
    final glassWidth = math.min(size.width, glassMaxWidth);
    final glass = layoutChild(
      _Slot.glass,
      BoxConstraints(minWidth: glassWidth, maxWidth: glassWidth, maxHeight: size.height),
    );
    final glassTop = size.height - glass.height;
    positionChild(_Slot.glass, Offset((size.width - glassWidth) / 2, glassTop));
    final height = math.max<double>(0, glassTop - _top + _tuck);
    final width = math.min(height * _aspect, size.width * 0.46);
    final card = BoxConstraints.tight(Size(width, height));
    final overlap = width * 0.1;
    layoutChild(_Slot.left, card);
    positionChild(_Slot.left, Offset(size.width / 2 - width + overlap, _top));
    layoutChild(_Slot.right, card);
    positionChild(_Slot.right, Offset(size.width / 2 - overlap, _top));
  }

  @override
  bool shouldRelayout(_FanLayout oldDelegate) => false;
}
