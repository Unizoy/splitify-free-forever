import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import 'golden_support.dart';

const _cardWidth = 176.0;
const _gridWidth = _cardWidth * 2 + AppSpacing.s3 + AppSpacing.s3 * 2;

({String name, String status, String? amount, MoneyTone tone, bool unsynced}) _variant(int i) =>
    switch (i) {
      0 => (
        name: 'Goa Trip',
        status: 'You are owed',
        amount: '₹1,240.50',
        tone: MoneyTone.owed,
        unsynced: false,
      ),
      1 => (
        name: 'Flat 4B',
        status: 'You owe',
        amount: '₹860.00',
        tone: MoneyTone.owe,
        unsynced: false,
      ),
      2 => (
        name: 'Date Night',
        status: 'Settled',
        amount: null,
        tone: MoneyTone.settled,
        unsynced: false,
      ),
      _ => (
        name: 'Office Lunch',
        status: 'You are owed',
        amount: '₹320.00',
        tone: MoneyTone.owed,
        unsynced: true,
      ),
    };

/// Four balance variants on the trip cover, then one card per other family.
const _cards = <(CoverFamily, int)>[
  (CoverFamily.trip, 0),
  (CoverFamily.trip, 1),
  (CoverFamily.trip, 2),
  (CoverFamily.trip, 3),
  (CoverFamily.home, 1),
  (CoverFamily.couple, 0),
  (CoverFamily.other, 2),
  (CoverFamily.direct, 3),
];

void main() {
  // TC-1-05: group cover card variants (owed / owe / settled / not synced) in every cover family.
  for (final (suffix, scale) in goldenScales) {
    goldenTest(
      'TC-1-05 group cover cards $suffix',
      fileName: 'group_cover_card_$suffix',
      textScaleFactor: scale,
      pumpBeforeTest: pumpFixedFrames,
      builder: () => GoldenTestGroup(
        columns: 2,
        columnWidthBuilder: (_) => const FixedColumnWidth(_gridWidth + 16),
        children: [
          for (final brightness in [Brightness.light, Brightness.dark])
            GoldenTestScenario.builder(
              name: brightness.name,
              builder: (context) => themedFrame(
                brightness,
                Builder(
                  builder: (context) {
                    final ratio = GroupCoverCard.aspectRatioFor(context);
                    return SizedBox(
                      width: _gridWidth - AppSpacing.s3 * 2,
                      child: Wrap(
                        spacing: AppSpacing.s3,
                        runSpacing: AppSpacing.s3,
                        children: [
                          for (final (family, variant) in _cards)
                            SizedBox(
                              width: _cardWidth,
                              height: _cardWidth / ratio,
                              child: _card(family, _variant(variant), '${family.name}-$variant'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                padding: const EdgeInsets.all(AppSpacing.s3),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _card(
  CoverFamily family,
  ({String name, String status, String? amount, MoneyTone tone, bool unsynced}) v,
  String seed,
) => GroupCoverCard(
  seed: seed,
  family: family,
  name: v.name,
  statusLabel: v.status,
  amountText: v.amount,
  tone: v.tone,
  unsynced: v.unsynced,
);
