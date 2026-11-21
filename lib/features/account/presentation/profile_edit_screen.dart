import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:splitify/features/account/presentation/profile_form.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Picks a photo and returns a square-ish compressed JPEG (≤ 512 px), or null.
typedef PhotoPicker = Future<Uint8List?> Function();

Future<Uint8List?> pickAvatarPhoto() async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
  if (file == null) return null;
  return FlutterImageCompress.compressWithList(
    await file.readAsBytes(),
    minWidth: 512,
    minHeight: 512,
    quality: 82,
  );
}

/// Photo picker used by the profile screen (tests override it).
final photoPickerProvider = Provider<PhotoPicker>((ref) => pickAvatarPhoto);

/// Profile edit (`/account/profile`, B2): photo, name, UPI ID (+ scan) and
/// default currency. Saving needs internet (allowed online-only exception).
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  ProfileDraft? _draft;
  Uint8List? _photo;
  bool _saving = false;

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final bytes = await ref.read(photoPickerProvider)();
    if (bytes != null && mounted) setState(() => _photo = bytes);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = _draft!;
    final profile = ref.read(profileProvider).value;
    if (!draft.validate()) {
      setState(() {});
      return;
    }
    if (profile == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.needsInternet)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(profileProvider.notifier).save(draft.apply(profile), photo: _photo);
      messenger.showSnackBar(SnackBar(content: Text(l.profileSaved)));
      if (mounted) Navigator.of(context).maybePop();
    } on ProfileFailure catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (e.code) {
            ProfileFailureCode.invalidName => l.nameInvalid,
            ProfileFailureCode.invalidUpi => l.upiInvalid,
            ProfileFailureCode.offline => l.needsInternet,
            _ => l.authErrorUnknown,
          }),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final profile = ref.watch(profileProvider).value;
    final draft = (_draft ??= ProfileDraft(null))..fillOnce(profile);
    final name = draft.name.text.trim();
    final photo = _photo;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.s2,
          AppSpacing.screen,
          AppSpacing.s8,
        ),
        children: [
          Semantics(
            header: true,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: AppText.maxSerifScale,
              child: Text(l.profileTitle, style: context.text.sheetTitle),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(l.profileConfirmSubtitle, style: context.text.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpacing.s8),
          Center(
            child: Avatar(
              name: name.isEmpty ? l.you : name,
              seed: profile?.id ?? 'me',
              size: AvatarSize.s96,
              ring: true,
              image: photo == null ? null : MemoryImage(photo),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Center(
            child: PillButton(
              key: const Key('profile-photo'),
              label: l.changePhoto,
              icon: AppIcons.user,
              variant: PillVariant.ghost,
              size: PillSize.medium,
              expand: false,
              onPressed: () => unawaited(_pickPhoto()),
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          ProfileFields(draft: draft),
          const SizedBox(height: AppSpacing.s10),
          PillButton(
            key: const Key('profile-save'),
            label: l.saveLabel,
            loading: _saving,
            onPressed: () => unawaited(_save()),
          ),
        ],
      ),
    );
  }
}
