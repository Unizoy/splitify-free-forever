import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// A stored photo (receipt or cover): the local copy when there is one, else downloaded once through a
/// signed URL. While loading a quiet tile shows; offline or missing shows an icon with a short line.
class StoredPhoto extends ConsumerWidget {
  const StoredPhoto({
    required this.bucket,
    required this.path,
    this.thumb = true,
    this.fit = BoxFit.cover,
    this.decodeWidth,
    this.showProblem = true,
    super.key,
  });

  final String bucket;
  final String path;

  /// Prefer the small local copy (lists, thumbnails).
  final bool thumb;
  final BoxFit fit;

  /// Decode at about this many physical pixels wide (memory); null = full size.
  final int? decodeWidth;

  /// Show the "shows when you're online" line under the icon (off for tiny tiles).
  final bool showProblem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(storedPhotoProvider((bucket: bucket, path: path, thumb: thumb)));
    return switch (file) {
      AsyncData(:final value) => Image.file(
        value,
        fit: fit,
        cacheWidth: decodeWidth,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => PhotoProblem(offline: false, showText: showProblem),
      ),
      AsyncError(:final error) => PhotoProblem(
        offline: error is MediaOffline,
        showText: showProblem,
      ),
      _ => const _Loading(),
    };
  }
}

/// A just-picked photo held in memory (editor, cover form).
class MemoryPhoto extends StatelessWidget {
  const MemoryPhoto({required this.bytes, this.fit = BoxFit.cover, this.decodeWidth, super.key});

  final Uint8List bytes;
  final BoxFit fit;
  final int? decodeWidth;

  @override
  Widget build(BuildContext context) => Image.memory(
    bytes,
    fit: fit,
    cacheWidth: decodeWidth,
    gaplessPlayback: true,
    errorBuilder: (context, _, _) => const PhotoProblem(offline: false),
  );
}

/// Placeholder for a photo that cannot be shown: offline (cloud icon, "Shows when you're online") or
/// unavailable (broken image).
class PhotoProblem extends StatelessWidget {
  const PhotoProblem({required this.offline, this.showText = true, super.key});

  final bool offline;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final text = offline ? l.photoOffline : l.photoUnavailable;
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: ColoredBox(
        color: c.surfaceMuted,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  offline ? AppIcons.cloudUpload : AppIcons.imageBroken,
                  size: 24,
                  color: c.textTertiary,
                ),
                if (showText) ...[
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).loading,
    child: ColoredBox(color: context.colors.surfaceMuted),
  );
}
