import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/currency/presentation/currency_picker_sheet.dart';
import 'package:splitify/features/expenses/presentation/editor/pickers.dart' show MonthCalendar;
import 'package:splitify/features/friends/application/contact_picker.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/domain/group_extras.dart';
import 'package:splitify/features/groups/presentation/group_trip_rows.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/features/photos/presentation/photo_source_sheet.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';

/// A person typed on the group form, added as a name-only member when the group is saved.
typedef NewPerson = ({String name, int tint});

/// Create (`/groups/new`) or edit (`/groups/:id/edit`) a group on one screen like Splitwise (D-033, 08 #1):
/// the cover beside the name, type chips, the main currency, then the people right there — name-only
/// people typed one after another, and "Invite with a link or QR" — and Save above the keyboard. A name
/// still in the people field when saving is added too, so nothing typed is lost. Works offline (outbox +
/// upload queue); the invite code comes once the group reaches the server.
class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({this.groupId, super.key});

  /// Null = new group.
  final String? groupId;

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final _name = TextEditingController();
  final _person = TextEditingController();
  final _nameFocus = FocusNode(debugLabel: 'group name');
  final _personFocus = FocusNode(debugLabel: 'add person');
  final _scroll = ScrollController();
  late final String _seed = widget.groupId ?? newId();
  String _type = 'trip';
  String? _currency;
  final _people = <NewPerson>[];

  /// 'generated' or 'photo'; [_photo] is a newly picked cover.
  String _coverKind = 'generated';
  String? _savedCoverPath;
  PreparedImage? _photo;
  bool _filled = false;
  bool _showErrors = false;
  bool _personError = false;
  String? _limitError;

  /// Trip dates (trips only) and settle-up reminders (D-034 C4).
  DateTime? _tripStart;
  DateTime? _tripEnd;
  SettleReminder _reminder = SettleReminder.off;
  final _tripKey = GlobalKey(debugLabel: 'trip dates');
  bool _saving = false;
  bool _saved = false;

  /// The user changed something: leaving asks first.
  bool _dirty = false;

  bool get _isEdit => widget.groupId != null;

  @override
  void dispose() {
    _name.dispose();
    _person.dispose();
    _nameFocus.dispose();
    _personFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _change(VoidCallback f) => setState(() {
    _dirty = true;
    f();
  });

  String? _nameError(AppLocalizations l) {
    if (!_showErrors) return null;
    return switch (GroupRules.name(_name.text)) {
      GroupFieldError.required => l.groupNameRequired,
      GroupFieldError.tooLong => l.groupNameTooLong,
      null => null,
    };
  }

  int _existingCount() =>
      _isEdit ? (ref.read(groupMembersProvider(widget.groupId!)).value?.length ?? 0) : 1;

  /// Adds the typed name to the list; false (with the inline error) when it is not a valid name.
  bool _addPerson({bool keepFocus = true}) {
    final l = AppLocalizations.of(context);
    final name = _person.text.trim();
    if (name.isEmpty) return true;
    if (GroupRules.memberName(name) != null) {
      setState(() => _personError = true);
      _personFocus.requestFocus();
      return false;
    }
    if (_existingCount() + _people.length + 1 > GroupRules.maxMembers) {
      setState(() => _limitError = l.groupErrorGroupFull);
      return false;
    }
    _change(() {
      _people.add((name: name, tint: (_existingCount() + _people.length) % Avatar.tintCount));
      _person.clear();
      _personError = false;
      _limitError = null;
    });
    if (keepFocus) _personFocus.requestFocus();
    return true;
  }

  /// "From contacts" (W2-X F15): the picked contact's name joins the people, like a typed one.
  Future<void> _fromContacts() async {
    final l = AppLocalizations.of(context);
    final String? name;
    try {
      name = await ref.read(contactPickerProvider).pickName();
    } on ContactPickFailed {
      if (mounted) showGroupMessage(context, l.w2xContactsUnavailable);
      return;
    }
    if (name == null || !mounted) return;
    _person.text = name;
    _addPerson(keepFocus: false);
  }

  Future<void> _save(String currency, {bool invite = false}) async {
    final l = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (_saving) return;
    if (GroupRules.name(_name.text) != null) {
      setState(() => _showErrors = true);
      // The name sits at the top of a long, lazy list: bring it back first, then focus it.
      if (_scroll.hasClients && _scroll.offset > 0) _scroll.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocus.requestFocus();
      });
      return;
    }
    // The end before the start: the dates stay as picked, the inline error points at them.
    if (_type == 'trip' && tripDatesInvalid(_tripStart, _tripEnd)) {
      final trip = _tripKey.currentContext;
      if (trip != null) unawaited(Scrollable.ensureVisible(trip, alignment: 0.3));
      return;
    }
    // A name still in the people field is added, never dropped.
    if (!_addPerson(keepFocus: false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final actions = ref.read(groupActionsProvider);
    try {
      final String id;
      if (_isEdit) {
        id = widget.groupId!;
        await actions.update(
          id,
          name: _name.text,
          type: _type,
          currency: currency,
          tripStartsOn: _tripStart,
          tripEndsOn: _tripEnd,
          reminder: _reminder,
        );
      } else {
        id = _seed;
        final profile = ref.read(profileProvider).value;
        await actions.create(
          id: id,
          name: _name.text,
          type: _type,
          currency: currency,
          ownerName: profile?.displayName ?? '',
          tripStartsOn: _tripStart,
          tripEndsOn: _tripEnd,
          reminder: _reminder,
        );
      }
      for (final p in _people) {
        await actions.addMember(id, p.name, tint: p.tint);
      }
      await _saveCover(id);
      _saved = true;
      if (_isEdit) {
        messenger.showSnackBar(SnackBar(content: Text(l.groupSaved)));
        if (mounted) router.pop();
      } else {
        // First group: the shell may ask about push notifications (08 #19).
        ref.read(pushPrePromptRequestsProvider.notifier).request();
        unawaited(router.pushReplacement('/groups/$id'));
        if (invite) {
          // Over the new group's page; the code shows as soon as the group reaches the server.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (rootNavigator.mounted) unawaited(showInviteSheet(rootNavigator.context, id));
          });
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Writes the cover change after the group itself (photo → upload queue).
  Future<void> _saveCover(String id) async {
    final actions = ref.read(groupActionsProvider);
    final photo = _photo;
    if (_coverKind == 'photo' && photo != null) {
      await actions.setCoverPhoto(id, photo, oldPath: _savedCoverPath);
    } else if (_coverKind == 'generated' && _savedCoverPath != null) {
      await actions.useGeneratedCover(id, oldPath: _savedCoverPath);
    }
  }

  Future<void> _pickPhoto() async {
    final image = await pickPhoto(context, ref);
    if (image != null && mounted) {
      _change(() {
        _photo = image;
        _coverKind = 'photo';
      });
    }
  }

  /// The cover sheet: generated art or a photo (S-073).
  Future<void> _openCover() async {
    final l = AppLocalizations.of(context);
    final hasPhoto = _photo != null || _savedCoverPath != null;
    final pick = await showAppSheet<String>(
      context,
      title: l.groupFormCover,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OptionTile(
            key: const Key('cover-generated'),
            label: l.coverGenerated,
            selected: _coverKind == 'generated',
            leading: Icon(AppIcons.sparkle, size: 18, color: sheet.colors.primary),
            onTap: () => Navigator.of(sheet).pop('generated'),
          ),
          if (hasPhoto) ...[
            const SizedBox(height: AppSpacing.s3),
            OptionTile(
              key: const Key('cover-saved-photo'),
              label: l.coverPhotoOption,
              selected: _coverKind == 'photo',
              leading: Icon(AppIcons.image, size: 18, color: sheet.colors.primary),
              onTap: () => Navigator.of(sheet).pop('photo'),
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          OptionTile(
            key: const Key('cover-photo'),
            label: hasPhoto ? l.coverChangePhoto : l.groupFormCoverChoose,
            leading: Icon(AppIcons.camera, size: 18, color: sheet.colors.primary),
            onTap: () => Navigator.of(sheet).pop('pick'),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            _coverKind == 'photo' ? l.coverPhotoHint : l.coverHint,
            textAlign: TextAlign.center,
            style: sheet.text.bodySmall.copyWith(color: sheet.colors.textSecondary),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (pick) {
      case 'generated':
        if (_coverKind != 'generated') _change(() => _coverKind = 'generated');
      case 'photo':
        if (_coverKind != 'photo') _change(() => _coverKind = 'photo');
      case 'pick':
        await _pickPhoto();
    }
  }

  Future<void> _pickCurrency(String current) async {
    final code = await showCurrencyPicker(
      context,
      selected: current,
      title: AppLocalizations.of(context).chooseCurrency,
    );
    if (code != null && mounted) _change(() => _currency = code);
  }

  /// Picks the trip's first ([start]) or last day in a calendar sheet; "No start / end date" clears it.
  Future<void> _pickTripDay({required bool start}) async {
    final l = AppLocalizations.of(context);
    final today = ref.read(clockProvider).today();
    final current = start ? _tripStart : _tripEnd;
    final picked = await showAppSheet<({DateTime? day})>(
      context,
      title: start ? l.tripPickStart : l.tripPickEnd,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            children: [
              IconChip(
                key: Key(start ? 'trip-no-start' : 'trip-no-end'),
                label: start ? l.tripNoStartDate : l.tripNoEndDate,
                selected: current == null,
                onTap: () => Navigator.of(sheet).pop((day: null)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          MonthCalendar(
            initial: current ?? (start ? null : _tripStart) ?? today,
            today: today,
            onPicked: (d) => Navigator.of(sheet).pop((day: d)),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    _change(() => start ? _tripStart = picked.day : _tripEnd = picked.day);
  }

  Future<void> _back() async {
    final l = AppLocalizations.of(context);
    if (_dirty && !_saved) {
      FocusManager.instance.primaryFocus?.unfocus();
      final ok = await confirmAction(
        context,
        title: _isEdit ? l.expDiscardEditTitle : l.groupFormDiscardTitle,
        body: _isEdit ? l.groupFormDiscardEditBody : l.groupFormDiscardBody,
        confirm: l.discardLabel,
        icon: AppIcons.trash,
      );
      if (!ok || !mounted) return;
    }
    if (!mounted) return;
    // `pop` ignores the PopScope that asks first; `maybePop` would ask the (not yet rebuilt) PopScope
    // again and loop forever without a frame.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/groups');
    }
  }

  void _invite(String currency) {
    if (_isEdit) {
      unawaited(showInviteSheet(context, widget.groupId!));
    } else {
      unawaited(_save(currency, invite: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final group = _isEdit ? ref.watch(groupProvider(widget.groupId!)).value : null;
    final members = _isEdit
        ? ref.watch(groupMembersProvider(widget.groupId!)).value ?? const <LocalMember>[]
        : const <LocalMember>[];
    final me = ref.watch(currentUserIdProvider);
    final profile = ref.watch(profileProvider).value;
    if (!_filled && group != null) {
      _filled = true;
      _name.text = group.name;
      _type = GroupRules.type(group.type);
      _currency = group.mainCurrency;
      _coverKind = group.coverKind == 'photo' && group.coverPath != null ? 'photo' : 'generated';
      _savedCoverPath = _coverKind == 'photo' ? group.coverPath : null;
      _tripStart = parseDay(group.tripStartsOn);
      _tripEnd = parseDay(group.tripEndsOn);
      _reminder = SettleReminder.parse(group.settleReminder);
    }
    final today = ref.watch(clockProvider).today();
    // Weekly reminders go out on the weekday the group was created (today for a new group).
    final createdDay = group?.createdAt == null
        ? today
        : (DateTime.tryParse(group!.createdAt!)?.toLocal() ?? today);
    final picked = _photo;
    final ImageProvider? coverPhoto = _coverKind != 'photo'
        ? null
        : (picked != null
              ? ResizeImage(MemoryImage(picked.thumb), width: 240)
              : (group == null ? null : groupCoverImage(ref, group, width: 240)));
    final currency = _currency ?? profile?.defaultCurrency ?? Currencies.inr.code;
    final cur = Currencies.of(currency);
    final myName = (profile?.displayName ?? '').trim();
    final count = (_isEdit ? members.length : 1) + _people.length;
    return PopScope(
      canPop: _saved || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            tooltip: l.back,
            icon: const Icon(AppIcons.back),
            onPressed: () => unawaited(_back()),
          ),
          title: Text(_isEdit ? l.editGroup : l.newGroup),
        ),
        body: PageBody(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: const Key('group-form'),
                  controller: _scroll,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.s3,
                    AppSpacing.screen,
                    AppSpacing.s8,
                  ),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _CoverButton(
                          seed: _seed,
                          type: _type,
                          photo: coverPhoto,
                          onTap: () => unawaited(_openCover()),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Expanded(
                          child: UnderlineField(
                            key: const Key('group-name'),
                            label: l.groupNameLabel,
                            hint: l.groupNameHint,
                            required: true,
                            controller: _name,
                            focusNode: _nameFocus,
                            autofocus: !_isEdit,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(GroupRules.nameMax + 20),
                            ],
                            errorText: _nameError(l),
                            onChanged: (_) => _change(() {}),
                            onSubmitted: (_) => _personFocus.requestFocus(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    SectionLabel(l.groupTypeLabel),
                    const SizedBox(height: AppSpacing.s3),
                    Wrap(
                      spacing: AppSpacing.s2,
                      runSpacing: AppSpacing.s2,
                      children: [
                        for (final t in GroupRules.types)
                          IconChip(
                            key: Key('group-type-$t'),
                            label: groupTypeLabel(l, t),
                            icon: GroupCoverCard.iconFor(coverFamilyFor(t)),
                            selected: _type == t,
                            onTap: () => _change(() => _type = t),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    DashedListRow(
                      key: const Key('group-currency'),
                      icon: AppIcons.coins,
                      label: l.mainCurrency,
                      value: '${cur.code} · ${cur.symbol}',
                      valueColor: c.textSecondary,
                      showDivider: false,
                      onTap: () => unawaited(_pickCurrency(currency)),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    SectionLabel('${l.membersSection} · $count'),
                    const SizedBox(height: AppSpacing.s1),
                    if (_isEdit)
                      for (final m in members)
                        _PersonRow(
                          key: Key('group-member-${m.id}'),
                          name: memberName(l, m, me),
                          label: m.userId != null && m.userId == me && memberName(l, m, me) != l.you
                              ? l.memberYouSuffix(memberName(l, m, me))
                              : null,
                          seed: m.id,
                          tint: m.tint,
                          caption: m.role == 'owner'
                              ? l.memberOwner
                              : m.userId == null
                              ? l.memberNameOnly
                              : m.claimedAt != null
                              ? l.memberClaimed
                              : null,
                        )
                    else
                      _PersonRow(
                        key: const Key('group-member-me'),
                        name: myName.isEmpty ? l.you : myName,
                        label: myName.isEmpty ? l.you : l.memberYouSuffix(myName),
                        seed: me ?? 'me',
                        caption: l.memberOwner,
                      ),
                    for (final (i, p) in _people.indexed)
                      _PersonRow(
                        key: Key('group-new-person-$i'),
                        name: p.name,
                        seed: 'new-${p.name}',
                        tint: p.tint,
                        caption: l.memberNameOnly,
                        onRemove: () => _change(() => _people.removeAt(i)),
                        removeTooltip: l.groupFormRemovePerson(p.name),
                      ),
                    const SizedBox(height: AppSpacing.s3),
                    UnderlineField(
                      key: const Key('group-add-person'),
                      label: l.groupFormPeopleLabel,
                      hint: l.groupFormPeopleHint,
                      controller: _person,
                      focusNode: _personFocus,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(GroupRules.memberNameMax + 20),
                      ],
                      errorText: _personError ? l.memberNameInvalid : _limitError,
                      onChanged: (_) {
                        _dirty = true;
                        if (_personError || _limitError != null) {
                          setState(() {
                            _personError = false;
                            _limitError = null;
                          });
                        }
                      },
                      onSubmitted: (_) => _addPerson(),
                      suffix: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // W2-X F15: a name from the phone's contacts (system picker, no permission).
                          AppIconButton(
                            key: const Key('group-from-contacts'),
                            tooltip: l.w2xFromContacts,
                            icon: Icon(AppIcons.contacts, color: c.textSecondary),
                            onPressed: () => unawaited(_fromContacts()),
                          ),
                          AppIconButton(
                            key: const Key('group-add-person-button'),
                            tooltip: l.groupFormAddPerson,
                            icon: Icon(AppIcons.plus, color: c.primary),
                            onPressed: _addPerson,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      l.groupFormPeopleNote,
                      style: context.text.bodySmall.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    DashedListRow(
                      key: const Key('group-invite'),
                      icon: AppIcons.qr,
                      label: l.groupFormInvite,
                      showDivider: false,
                      onTap: () => _invite(currency),
                    ),
                    if (!_isEdit)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: AppSpacing.s10 + AppSpacing.s2,
                        ),
                        child: Text(
                          l.groupFormInviteNew,
                          style: context.text.bodySmall.copyWith(color: c.textSecondary),
                        ),
                      ),
                    // Trip dates for trips, settle-up reminders for every group (D-034 C4): rows at the
                    // end of the form (optional, after the people), never a dialog on save.
                    if (_type == 'trip')
                      TripDatesRows(
                        key: _tripKey,
                        start: _tripStart,
                        end: _tripEnd,
                        today: today,
                        onStart: () => unawaited(_pickTripDay(start: true)),
                        onEnd: () => unawaited(_pickTripDay(start: false)),
                      ),
                    SettleReminderRow(
                      value: _reminder,
                      today: today,
                      createdDay: createdDay,
                      tripEndsOn: _type == 'trip' ? _tripEnd : null,
                      onChanged: (r) => _change(() => _reminder = r),
                    ),
                  ],
                ),
              ),
              // In the body (not bottomNavigationBar): the Scaffold lifts it above the keyboard (D-032).
              StickyActionBar(
                primary: PillButton(
                  key: const Key('group-save'),
                  label: _isEdit ? l.saveLabel : l.createGroupButton,
                  loading: _saving,
                  onPressed: () => unawaited(_save(currency)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The group's cover as a small rounded tile with a camera badge beside the name (like Splitwise's
/// group photo); tapping it opens the cover sheet.
class _CoverButton extends StatelessWidget {
  const _CoverButton({required this.seed, required this.type, required this.onTap, this.photo});

  final String seed;
  final String type;
  final ImageProvider? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final family = coverFamilyFor(type);
    return Semantics(
      button: true,
      label: l.groupFormCover,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        key: const Key('group-cover'),
        onTap: onTap,
        borderRadius: AppRadii.all16,
        scale: 0.95,
        child: SizedBox.square(
          dimension: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  key: const Key('group-cover-preview'),
                  borderRadius: AppRadii.all16,
                  child: photo == null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CoverArt(seed: seed, family: family),
                            Center(
                              child: Icon(
                                GroupCoverCard.iconFor(family),
                                size: 22,
                                color: c.onHero,
                              ),
                            ),
                          ],
                        )
                      : Image(image: photo!, fit: BoxFit.cover, gaplessPlayback: true),
                ),
              ),
              PositionedDirectional(
                end: -6,
                bottom: -6,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.bg, width: 2),
                  ),
                  child: Icon(AppIcons.camera, size: 14, color: c.onInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One person on the form: avatar, name and a caption; people typed here can be removed again.
class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.name,
    required this.seed,
    this.label,
    this.tint,
    this.caption,
    this.onRemove,
    this.removeTooltip,
    super.key,
  });

  final String name;
  final String seed;

  /// Shown instead of [name] ("Asha (you)"); the avatar keeps the plain name's initials.
  final String? label;
  final int? tint;
  final String? caption;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        child: Row(
          children: [
            Avatar(name: name, seed: seed, tint: tint, size: AvatarSize.s32),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label ?? name, style: context.text.body.w(600)),
                  if (caption != null)
                    Text(caption!, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            if (onRemove != null)
              AppIconButton(
                tooltip: removeTooltip ?? '',
                icon: Icon(AppIcons.close, size: 18, color: c.textSecondary),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
