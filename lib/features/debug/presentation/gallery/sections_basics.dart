import 'package:flutter/material.dart';
import 'package:splitify/features/debug/presentation/gallery/gallery_samples.dart';
import 'package:splitify/features/debug/presentation/gallery/gallery_sections.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';

void _noop() {}
void _noopInt(int _) {}

Widget _gap([double h = AppSpacing.s3]) => SizedBox(height: h, width: h);

/// PillButton, OptionTile, SegmentedPill, QuantityStepper, DashedCircleButton.
Widget buttonsSection(BuildContext context) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Demo(
      'PillButton',
      Column(
        children: [
          const PillButton(
            label: Samples.saveExpense,
            onPressed: _noop,
            variant: PillVariant.money,
          ),
          _gap(),
          const PillButton(label: Samples.joinGroup, onPressed: _noop, icon: AppIcons.add),
          _gap(),
          const PillButton(label: Samples.youPaid, onPressed: _noop, variant: PillVariant.outline),
          _gap(),
          Row(
            children: [
              const Expanded(
                child: PillButton(
                  label: Samples.cancel,
                  onPressed: _noop,
                  variant: PillVariant.ghost,
                  size: PillSize.medium,
                ),
              ),
              _gap(),
              const Expanded(
                child: PillButton(label: Samples.settleUp, onPressed: _noop, size: PillSize.medium),
              ),
            ],
          ),
          _gap(),
          const PillButton(
            label: Samples.saveExpense,
            onPressed: _noop,
            variant: PillVariant.money,
            loading: true,
          ),
          _gap(),
          const PillButton(label: Samples.continueLabel, onPressed: null),
          _gap(),
          const HeroSwatch(
            child: PillButton(
              label: Samples.viewGroup,
              onPressed: _noop,
              variant: PillVariant.inverse,
            ),
          ),
        ],
      ),
    ),
    Demo(
      'OptionTile',
      Column(
        children: [
          const OptionTile(label: Samples.youPaid, onTap: _noop, selected: true),
          _gap(),
          const OptionTile(label: Samples.multiple, onTap: _noop),
        ],
      ),
    ),
    Demo(
      'SegmentedPill',
      SegmentedPill<int>(
        value: 0,
        onChanged: _noopInt,
        items: const [
          SegmentedPillItem(value: 0, label: Samples.equally),
          SegmentedPillItem(value: 1, label: Samples.shares),
          SegmentedPillItem(value: 2, label: Samples.exact),
        ],
      ),
    ),
    const Demo(
      'QuantityStepper',
      Align(
        alignment: Alignment.centerLeft,
        child: QuantityStepper(value: 2, onChanged: _noopInt),
      ),
    ),
    const Demo(
      'DashedCircleButton',
      HeroSwatch(
        child: Center(
          child: DashedCircleButton(label: Samples.getStarted, onPressed: _noop),
        ),
      ),
    ),
  ],
);

/// StatusPill, IconChip, SyncMarker, TintedIcon.
Widget chipsSection(BuildContext context) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Demo(
      'StatusPill',
      Wrap(
        spacing: AppSpacing.s2,
        runSpacing: AppSpacing.s2,
        children: [
          const StatusPill(label: Samples.savedOffline, icon: AppIcons.shieldCheckFill),
          const StatusPill(label: Samples.youAreOwed, tone: StatusPillTone.positive),
          const StatusPill(label: Samples.youOwe, tone: StatusPillTone.negative),
          HeroSwatch(
            child: Wrap(
              spacing: AppSpacing.s3,
              runSpacing: AppSpacing.s2,
              children: const [
                StatusPill(
                  label: Samples.allSettled,
                  icon: AppIcons.checkCircle,
                  tone: StatusPillTone.glass,
                ),
                StatusPill(
                  label: Samples.settled,
                  icon: AppIcons.checkCircle,
                  tone: StatusPillTone.flat,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    Demo(
      'IconChip',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              for (final (i, cat) in [Category.food, Category.travel, Category.rent].indexed)
                IconChip(
                  label: cat.name[0].toUpperCase() + cat.name.substring(1),
                  icon: cat.icon,
                  iconColor: cat.color,
                  selected: i == 0,
                  onTap: _noop,
                ),
            ],
          ),
          _gap(),
          const HeroSwatch(
            child: Wrap(
              spacing: AppSpacing.s2,
              children: [
                IconChip(label: Samples.all, onTap: _noop, onDark: true, selected: true),
                IconChip(label: Samples.trips, icon: AppIcons.typeTrip, onTap: _noop, onDark: true),
              ],
            ),
          ),
        ],
      ),
    ),
    const Demo(
      'SyncMarker',
      Row(
        children: [
          SyncMarker(),
          SizedBox(width: AppSpacing.s6),
          SyncMarker(compact: true),
        ],
      ),
    ),
    Demo(
      'TintedIcon · categories',
      Wrap(
        spacing: AppSpacing.s3,
        runSpacing: AppSpacing.s3,
        children: [for (final cat in Category.values) TintedIcon.category(cat)],
      ),
    ),
  ],
);

/// UnderlineField states.
Widget inputsSection(BuildContext context) => const Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Demo(
      'UnderlineField',
      UnderlineField(label: Samples.description, hint: Samples.descriptionHint, required: true),
    ),
    Demo('With value', _FilledField()),
    Demo('Error', UnderlineField(label: Samples.amount, hint: '0', errorText: Samples.amountError)),
    Demo(
      'Two columns',
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: UnderlineField(label: Samples.firstName, hint: Samples.typeHere, required: true),
          ),
          SizedBox(width: AppSpacing.s6),
          Expanded(
            child: UnderlineField(label: Samples.lastName, hint: Samples.typeHere, required: true),
          ),
        ],
      ),
    ),
  ],
);

class _FilledField extends StatefulWidget {
  const _FilledField();

  @override
  State<_FilledField> createState() => _FilledFieldState();
}

class _FilledFieldState extends State<_FilledField> {
  final _controller = TextEditingController(text: Samples.goaTrip);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      UnderlineField(label: Samples.groupName, controller: _controller);
}

/// Avatar sizes, AvatarStack, AvatarCarousel.
Widget avatarsSection(BuildContext context) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Demo(
      'Avatar · 32 / 40 / 56 / 96',
      Row(
        children: [
          for (final (i, size) in AvatarSize.values.indexed) ...[
            Avatar(name: Samples.people6[i].name, seed: Samples.people6[i].seed, size: size),
            _gap(),
          ],
        ],
      ),
    ),
    const Demo(
      'AvatarStack (+N)',
      Align(
        alignment: Alignment.centerLeft,
        child: AvatarStack(people: Samples.people6),
      ),
    ),
    const Demo(
      'AvatarCarousel',
      Center(
        child: AvatarCarousel(people: Samples.people6, onChanged: _noopInt, initialIndex: 1),
      ),
    ),
  ],
);

/// Generated covers: every family × two seeds (D-013).
Widget coversSection(BuildContext context) => Wrap(
  spacing: AppSpacing.s3,
  runSpacing: AppSpacing.s3,
  children: [
    for (final family in CoverFamily.values)
      for (final seed in ['a1', 'b2'])
        SizedBox(
          width: 104,
          height: 150,
          child: ClipRRect(
            borderRadius: AppRadii.all16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverArt(seed: seed, family: family, cache: false),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s2),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      '${family.name} · $seed',
                      style: context.text.caption.copyWith(color: context.colors.onHero),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  ],
);
