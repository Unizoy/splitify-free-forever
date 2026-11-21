// S-073 (phase 10): a group's photo cover on the hero (group detail, expense detail) and on the group card,
// light and dark at text scale 1.0 and 2.0.
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../support/sample_photo.dart';
import 'golden_support.dart';

Widget _covers(Brightness brightness, double scale) {
  final photo = MemoryImage(samplePhotoPng);
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: themedFrame(
      brightness,
      Column(
        children: [
          HeroHeader(
            title: 'Goa trip',
            photo: photo,
            leading: HeroIconButton(icon: AppIcons.back, tooltip: 'Back', onPressed: () {}),
            actions: [
              HeroIconButton(icon: AppIcons.loan, tooltip: 'Record a loan', onPressed: () {}),
              HeroIconButton(icon: AppIcons.settings, tooltip: 'Settings', onPressed: () {}),
            ],
            child: const StatusPill(
              label: 'All settled',
              icon: AppIcons.checkCircle,
              tone: StatusPillTone.glass,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Row(
              children: [
                for (final (name, tone, amount) in [
                  ('Goa Trip', MoneyTone.owed, '₹1,240'),
                  ('Flat 4B', MoneyTone.owe, '₹860'),
                ]) ...[
                  Expanded(
                    child: SizedBox(
                      height: 300,
                      child: GroupCoverCard(
                        seed: name,
                        family: CoverFamily.trip,
                        name: name,
                        statusLabel: tone == MoneyTone.owed ? 'You are owed' : 'You owe',
                        amountText: amount,
                        tone: tone,
                        photo: photo,
                      ),
                    ),
                  ),
                  if (name == 'Goa Trip') const SizedBox(width: AppSpacing.s3),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  for (final (suffix, scale) in goldenScales) {
    goldenTest(
      'S-073 photo covers $suffix',
      fileName: 'photo_covers_$suffix',
      pumpBeforeTest: pumpFixedFrames,
      builder: () => GoldenTestGroup(
        columns: 2,
        columnWidthBuilder: (_) => const FixedColumnWidth(goldenWidth + 16),
        children: [
          for (final b in [Brightness.light, Brightness.dark])
            GoldenTestScenario.builder(
              name: b.name,
              constraints: const BoxConstraints.tightFor(width: goldenWidth),
              builder: (context) => _covers(b, scale),
            ),
        ],
      ),
    );
  }
}
