import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/account/presentation/profile_form.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
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

/// Profile edit (`/account/profile`, B2), one simple screen (D-033): the photo (tap it to change; the
/// saved one shows), name, UPI ID with a scan button in the field, default currency, and Save above the
/// keyboard. Saving needs internet (allowed online-only exception); typed values stay on any error.
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
    FocusManager.instance.primaryFocus?.unfocus();
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
    final profile = ref.watch(profileProvider).value;
    final draft = (_draft ??= ProfileDraft(null))..fillOnce(profile);
    final name = draft.name.text.trim();
    final photo = _photo;
    // The saved photo (D-033 bug: only a photo picked in this visit used to show).
    final path = profile?.avatarPath;
    final saved = path == null
        ? null
        : ref
              .watch(storedPhotoProvider((bucket: MediaBuckets.avatars, path: path, thumb: false)))
              .value;
    final ImageProvider? image = photo != null
        ? MemoryImage(photo)
        : saved == null
        ? null
        : ResizeImage(FileImage(saved), width: 512);
    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l.profileTitle),
      ),
      body: PageBody(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.s3,
                  AppSpacing.screen,
                  AppSpacing.s8,
                ),
                children: [
                  Center(
                    child: PhotoAvatarButton(
                      key: const Key('profile-photo'),
                      name: name.isEmpty ? l.you : name,
                      seed: profile?.id ?? 'me',
                      image: image,
                      tooltip: l.profilePhotoTooltip,
                      onTap: () => unawaited(_pickPhoto()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  ProfileFields(draft: draft, onSubmitted: () => unawaited(_save())),
                ],
              ),
            ),
            // In the body (not bottomNavigationBar): the Scaffold lifts it above the keyboard (D-032).
            StickyActionBar(
              primary: PillButton(
                key: const Key('profile-save'),
                label: l.saveLabel,
                loading: _saving,
                onPressed: () => unawaited(_save()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A large avatar with a small camera badge; tapping it picks a new photo.
class PhotoAvatarButton extends StatelessWidget {
  const PhotoAvatarButton({
    required this.name,
    required this.seed,
    required this.tooltip,
    required this.onTap,
    this.image,
    super.key,
  });

  final String name;
  final String seed;
  final String tooltip;
  final VoidCallback onTap;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        circle: true,
        scale: 0.95,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Avatar(name: name, seed: seed, size: AvatarSize.s96, ring: true, image: image),
            PositionedDirectional(
              end: -2,
              bottom: -2,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.bg, width: 3),
                ),
                child: Icon(AppIcons.camera, size: 16, color: c.onInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
