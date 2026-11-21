import 'package:flutter/material.dart';
import 'package:splitify/features/debug/presentation/gallery/gallery_samples.dart';
import 'package:splitify/features/debug/presentation/gallery/gallery_sections.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

void _noop() {}
void _noopInt(int _) {}

const _gap = SizedBox(height: AppSpacing.s3, width: AppSpacing.s3);

/// GlassCard, GroupCoverCard grid, OverlapBanner, ArcGauge.
Widget cardsSection(BuildContext context) {
  final c = context.colors;
  final ratio = GroupCoverCard.aspectRatioFor(context);
  const cards = [
    (
      seed: 'g-goa',
      family: CoverFamily.trip,
      name: Samples.goaTrip,
      label: Samples.youAreOwedCaps,
      amount: Samples.rupees1200,
      tone: MoneyTone.owed,
      unsynced: false,
    ),
    (
      seed: 'g-flat',
      family: CoverFamily.home,
      name: Samples.flat4b,
      label: Samples.youOweCaps,
      amount: Samples.rupees450,
      tone: MoneyTone.owe,
      unsynced: false,
    ),
    (
      seed: 'g-anniv',
      family: CoverFamily.couple,
      name: Samples.anniversary,
      label: Samples.settled,
      amount: null,
      tone: MoneyTone.settled,
      unsynced: false,
    ),
    (
      seed: 'g-office',
      family: CoverFamily.other,
      name: Samples.officeLunch,
      label: Samples.youAreOwedCaps,
      amount: Samples.rupees500,
      tone: MoneyTone.owed,
      unsynced: true,
    ),
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Demo(
        'GlassCard',
        HeroSwatch(
          seed: 'glass',
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Samples.overall,
                        style: context.text.title.copyWith(color: c.onHero),
                      ),
                    ),
                    const StatusPill(
                      label: Samples.youAreOwedCaps,
                      icon: AppIcons.checkCircle,
                      tone: StatusPillTone.flat,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(Samples.rupees2400, style: context.text.amountHero.copyWith(color: c.onHero)),
                Text(Samples.glassCaption, style: context.text.body.copyWith(color: c.onHeroMuted)),
                const SizedBox(height: AppSpacing.s4),
                const PillButton(
                  label: Samples.settleUp,
                  onPressed: _noop,
                  variant: PillVariant.inverse,
                ),
              ],
            ),
          ),
        ),
      ),
      Demo(
        'GroupCoverCard',
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.gutter,
          crossAxisSpacing: AppSpacing.gutter,
          childAspectRatio: ratio,
          children: [
            for (final g in cards)
              GroupCoverCard(
                seed: g.seed,
                family: g.family,
                name: g.name,
                statusLabel: g.label,
                amountText: g.amount,
                tone: g.tone,
                unsynced: g.unsynced,
                onTap: _noop,
              ),
          ],
        ),
      ),
      Demo(
        'OverlapBanner',
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s5,
            AppSpacing.s4,
            AppSpacing.s5,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadii.all28,
            border: Border.all(color: c.border),
          ),
          child: const Column(
            children: [
              OverlapBanner(line1: Samples.bannerLine1, line2: Samples.bannerLine2),
              SizedBox(height: AppSpacing.s5),
              PillButton(label: Samples.settleUp, onPressed: _noop, variant: PillVariant.money),
            ],
          ),
        ),
      ),
      const Demo(
        'ArcGauge',
        Center(
          child: ArcGauge(
            progress: 0.35,
            valueText: Samples.rupees1750,
            caption: Samples.settledSoFar,
          ),
        ),
      ),
    ],
  );
}

/// WalletCard, DotMatrixCard, MetalCard.
Widget showpiecesSection(BuildContext context) => const Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Demo(
      'WalletCard',
      WalletCard(
        brandLabel: Samples.brand,
        amounts: [Samples.rupees2400, Samples.dollars35],
        statusLabel: Samples.youAreOwedCaps,
        caption: Samples.acrossGroups,
        onTap: _noop,
      ),
    ),
    Demo(
      'DotMatrixCard',
      DotMatrixCard(
        title: Samples.yourSpending,
        onTap: _noop,
        stats: [
          (value: Samples.rupees18k, label: Samples.spentThisMonth),
          (value: '4', label: Samples.activeGroups),
          (value: '9', label: Samples.people),
        ],
      ),
    ),
    Demo(
      'MetalCard',
      MetalCard(
        title: Samples.yourStats,
        stats: [
          (value: '27', label: Samples.expensesAdded),
          (value: '4', label: Samples.activeGroups),
        ],
      ),
    ),
  ],
);

/// AmountRow, DashedListRow, AccordionCard, FolderTabs, StickyActionBar.
Widget listsSection(BuildContext context) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Demo(
      'AmountRow',
      Column(
        children: [
          AmountRow(
            leading: TintedIcon.category(Category.food),
            title: Samples.dinner,
            caption: Samples.rahulPaid,
            amountText: Samples.rupees450,
            amountCaption: Samples.youBorrowed,
            tone: MoneyTone.owe,
          ),
          AmountRow(
            leading: TintedIcon.category(Category.travel),
            title: Samples.cab,
            caption: Samples.ashaPaid,
            amountText: Samples.rupees1200,
            amountCaption: Samples.youLent,
            tone: MoneyTone.owed,
          ),
          AmountRow(
            leading: TintedIcon.category(Category.groceries),
            title: Samples.groceries,
            caption: Samples.groceriesCaption,
            amountText: Samples.rupees15,
            tone: MoneyTone.owed,
            unsynced: true,
          ),
          const AmountRow(
            title: Samples.payment,
            caption: Samples.paymentCaption,
            amountText: Samples.rupees500,
          ),
        ],
      ),
    ),
    const Demo(
      'DashedListRow',
      Column(
        children: [
          DashedListRow(
            icon: AppIcons.coins,
            label: Samples.credits,
            value: Samples.rupees500,
            onTap: _noop,
          ),
          DashedListRow(icon: AppIcons.info, label: Samples.getHelp, onTap: _noop),
          DashedListRow(
            icon: AppIcons.trash,
            label: Samples.deleteAccount,
            onTap: _noop,
            destructive: true,
            showDivider: false,
          ),
        ],
      ),
    ),
    const Demo(
      'AccordionCard',
      Column(
        children: [
          AccordionCard(
            icon: AppIcons.userFill,
            title: Samples.profile,
            subtitle: Samples.profileSub,
            initiallyExpanded: true,
            rows: [
              AccordionRow(label: Samples.upiId, value: Samples.upiValue, onTap: _noop),
              AccordionRow(label: Samples.currency, value: Samples.inr, onTap: _noop),
            ],
          ),
          _gap,
          AccordionCard(
            icon: AppIcons.palette,
            title: Samples.preferences,
            subtitle: Samples.preferencesSub,
            rows: [],
          ),
        ],
      ),
    ),
    const Demo(
      'FolderTabs',
      FolderTabs(
        index: 0,
        onChanged: _noopInt,
        tabs: [
          FolderTab(label: Samples.expenses, icon: AppIcons.receipt),
          FolderTab(label: Samples.balances, icon: AppIcons.coins),
          FolderTab(label: Samples.totals, icon: AppIcons.chart),
        ],
      ),
    ),
    const Demo(
      'StickyActionBar',
      StickyActionBar(
        summary: Text(Samples.youOweAsha),
        secondary: PillButton(label: Samples.remind, onPressed: _noop, variant: PillVariant.ghost),
        primary: PillButton(label: Samples.settleUp, onPressed: _noop, variant: PillVariant.money),
      ),
    ),
  ],
);

/// CapsuleNavBar, StepHeader, HeroTabs, HeroHeader + OverlapSheet.
Widget navigationSection(BuildContext context) {
  final items = [
    const CapsuleNavItem(
      label: Samples.groups,
      icon: AppIcons.groups,
      activeIcon: AppIcons.groupsActive,
    ),
    const CapsuleNavItem(
      label: Samples.friends,
      icon: AppIcons.friends,
      activeIcon: AppIcons.friendsActive,
    ),
    const CapsuleNavItem(
      label: Samples.activity,
      icon: AppIcons.activity,
      activeIcon: AppIcons.activityActive,
    ),
    const CapsuleNavItem(label: Samples.account, icon: AppIcons.account),
  ];
  final steps = [
    const StepItem(label: 'Amount', icon: AppIcons.stepAmount),
    const StepItem(label: 'Paid by', icon: AppIcons.stepPaidBy),
    const StepItem(label: 'Split', icon: AppIcons.stepSplit),
    const StepItem(label: 'Details', icon: AppIcons.stepDetails),
    const StepItem(label: 'Review', icon: AppIcons.stepReview),
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Demo(
        'CapsuleNavBar',
        MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: Column(
            children: [
              CapsuleNavBar(
                items: items,
                currentIndex: 0,
                onSelected: _noopInt,
                onAdd: _noop,
                addLabel: Samples.addExpense,
              ),
              CapsuleNavBar(items: items, currentIndex: 3, onSelected: _noopInt),
            ],
          ),
        ),
      ),
      Demo(
        'StepHeader',
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: StepHeader(steps: steps, current: 2, statusText: Samples.stepGoa, onHome: _noop),
        ),
      ),
      const Demo(
        'HeroTabs',
        HeroSwatch(
          child: HeroTabs(
            index: 0,
            onChanged: _noopInt,
            tabs: [
              (icon: AppIcons.groupsActive, label: Samples.explore),
              (icon: AppIcons.receipt, label: Samples.archived),
            ],
          ),
        ),
      ),
      Demo(
        'HeroHeader + OverlapSheet',
        ClipRRect(
          borderRadius: AppRadii.all24,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            child: OverlapColumn(
              top: const HeroHeader(
                title: Samples.heroTitle,
                art: (seed: 'gallery-hero', family: CoverFamily.other),
              ),
              bottom: const OverlapSheet(
                child: EmptyState(
                  icon: AppIcons.groups,
                  title: Samples.emptyTitle,
                  message: Samples.emptyBody,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// EmptyState, BlobBackground, StackedCardsLoader, Celebration, AppSheet.
Widget feedbackSection(BuildContext context) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const Demo(
      'EmptyState',
      EmptyState(
        icon: AppIcons.groups,
        title: Samples.emptyTitle,
        message: Samples.emptyBody,
        actions: [
          PillButton(label: Samples.joinGroup, onPressed: _noop),
          PillButton(label: Samples.cancel, onPressed: _noop, variant: PillVariant.outline),
        ],
      ),
    ),
    const Demo(
      'BlobBackground',
      ClipRRect(
        borderRadius: AppRadii.all28,
        child: BlobBackground(
          child: SizedBox(
            width: double.infinity,
            child: EmptyState(
              icon: AppIcons.chat,
              title: Samples.noComments,
              message: Samples.startConversation,
            ),
          ),
        ),
      ),
    ),
    Demo(
      'StackedCardsLoader',
      StackedCardsLoader(
        title: Samples.creatingGroup,
        message: Samples.justAMoment,
        cards: [
          for (final (i, caption) in Samples.loaderCaptions.indexed)
            (
              seed: 'load-$i',
              family: CoverFamily.values[i % CoverFamily.values.length],
              caption: caption,
            ),
        ],
      ),
    ),
    const Demo(
      'Celebration',
      Celebration(
        lead: Samples.celebrationLead,
        highlight: Samples.celebrationHighlight,
        message: Samples.celebrationMessage,
      ),
    ),
    Demo(
      'AppSheet',
      DecoratedBox(
        decoration: BoxDecoration(color: context.colors.scrim, borderRadius: AppRadii.all24),
        child: const Padding(
          padding: EdgeInsets.only(top: AppSpacing.s10),
          child: AppSheet(
            title: Samples.accountSettings,
            child: Column(
              children: [
                DashedListRow(
                  icon: AppIcons.coins,
                  label: Samples.credits,
                  value: Samples.rupees500,
                  onTap: _noop,
                ),
                DashedListRow(
                  icon: AppIcons.info,
                  label: Samples.getHelp,
                  onTap: _noop,
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ],
);
