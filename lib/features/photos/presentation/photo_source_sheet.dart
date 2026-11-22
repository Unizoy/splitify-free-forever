import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

final _log = Logger('photos');

/// "Add a photo" sheet (camera or the Android photo picker), then compression. Returns null when the
/// person backs out; a photo that cannot be read shows "Couldn't use that photo".
Future<PreparedImage?> pickPhoto(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final picker = ref.read(preparedPhotoPickerProvider);
  final source = await showAppSheet<PhotoSource>(
    context,
    title: l.photoSourceTitle,
    builder: (sheet) => const _SourceChoices(),
  );
  if (source == null) return null;
  try {
    return await picker(source);
  } on Exception catch (e) {
    _log.warning('photo pick failed: $e');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.photoPickFailed)));
    return null;
  }
}

class _SourceChoices extends StatelessWidget {
  const _SourceChoices();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionTile(
          key: const Key('photo-camera'),
          label: l.photoTake,
          leading: Icon(AppIcons.camera, size: 20, color: c.primary),
          onTap: () => Navigator.of(context).pop(PhotoSource.camera),
        ),
        const SizedBox(height: AppSpacing.s3),
        OptionTile(
          key: const Key('photo-gallery'),
          label: l.photoChoose,
          leading: Icon(AppIcons.images, size: 20, color: c.primary),
          onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          l.photoChooseHint,
          textAlign: TextAlign.center,
          style: context.text.bodySmall.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}
