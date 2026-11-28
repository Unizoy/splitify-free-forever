import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/features/photos/presentation/stored_photo.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Full-screen photo (#29): black page, pinch or double-tap to zoom, close on top; optional Replace /
/// Remove at the bottom (each returns true when it changed the photo, which closes the viewer).
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    required this.title,
    this.bytes,
    this.bucket,
    this.path,
    this.placeholderPath,
    this.onReplace,
    this.onRemove,
    super.key,
  }) : assert(bytes != null || (bucket != null && path != null), 'a photo to show');

  /// Opens the viewer above everything (tab shell included).
  static Future<void> open(
    BuildContext context, {
    required String title,
    Uint8List? bytes,
    String? bucket,
    String? path,
    String? placeholderPath,
    Future<bool> Function()? onReplace,
    Future<bool> Function()? onRemove,
  }) => Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PhotoViewerScreen(
        title: title,
        bytes: bytes,
        bucket: bucket,
        path: path,
        placeholderPath: placeholderPath,
        onReplace: onReplace,
        onRemove: onRemove,
      ),
    ),
  );

  final String title;

  /// A photo held in memory (just picked), or the stored [bucket]/[path].
  final Uint8List? bytes;
  final String? bucket;
  final String? path;

  /// A small copy in the same bucket (an attachment's thumbnail, W2-Y) shown while the full-resolution
  /// photo loads, and kept with a note when it can't load offline.
  final String? placeholderPath;
  final Future<bool> Function()? onReplace;
  final Future<bool> Function()? onRemove;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  final _zoom = TransformationController();
  TapDownDetails? _tap;
  bool _busy = false;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_zoom.value.getMaxScaleOnAxis() > 1.01) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final p = _tap?.localPosition ?? Offset.zero;
    const s = 2.5;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(-p.dx * (s - 1), -p.dy * (s - 1), 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  Future<void> _run(Future<bool> Function() action) async {
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final changed = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (changed) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final bytes = widget.bytes;
    final placeholder = widget.placeholderPath;
    final photo = bytes != null
        ? MemoryPhoto(bytes: bytes, fit: BoxFit.contain)
        : placeholder != null
        ? _FullOverThumb(bucket: widget.bucket!, path: widget.path!, thumbPath: placeholder)
        : StoredPhoto(
            bucket: widget.bucket!,
            path: widget.path!,
            thumb: false,
            fit: BoxFit.contain,
          );
    final actions = [
      if (widget.onReplace != null)
        PillButton(
          key: const Key('photo-replace'),
          label: l.photoReplace,
          icon: AppIcons.replace,
          variant: PillVariant.inverse,
          size: PillSize.medium,
          expand: false,
          onPressed: _busy ? null : () => unawaited(_run(widget.onReplace!)),
        ),
      if (widget.onRemove != null)
        PillButton(
          key: const Key('photo-remove'),
          label: l.photoRemove,
          icon: AppIcons.trash,
          variant: PillVariant.inverse,
          size: PillSize.medium,
          expand: false,
          onPressed: _busy ? null : () => unawaited(_run(widget.onRemove!)),
        ),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Semantics(
                image: true,
                label: widget.title,
                hint: l.photoZoomHint,
                child: GestureDetector(
                  onDoubleTapDown: (d) => _tap = d,
                  onDoubleTap: _toggleZoom,
                  child: InteractiveViewer(
                    key: const Key('photo-zoom'),
                    transformationController: _zoom,
                    maxScale: 5,
                    child: SizedBox.expand(child: photo),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                  child: Row(
                    children: [
                      HeroIconButton(
                        key: const Key('photo-close'),
                        icon: AppIcons.close,
                        tooltip: l.photoClose,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.title.w(600).copyWith(color: c.onHero),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (actions.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: AppSpacing.s4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.s3,
                      runSpacing: AppSpacing.s2,
                      children: actions,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The full-resolution photo over its thumbnail (W2-Y "full resolution on tap"): the thumbnail shows at
/// once, the big photo replaces it when it is here (downloaded once, then cached); a small note says it is
/// loading, or that the full size needs the internet.
class _FullOverThumb extends ConsumerWidget {
  const _FullOverThumb({required this.bucket, required this.path, required this.thumbPath});

  final String bucket;
  final String path;
  final String thumbPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final full = ref.watch(storedPhotoProvider((bucket: bucket, path: path, thumb: false)));
    final note = switch (full) {
      AsyncData() => null,
      AsyncError(:final error) when error is MediaOffline => l.w2yPhotoFullOffline,
      AsyncError() => null,
      _ => l.w2yPhotoFullLoading,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        if (full case AsyncData(:final value))
          Image.file(
            value,
            key: const Key('photo-full'),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, _, _) => const PhotoProblem(offline: false),
          )
        else
          StoredPhoto(bucket: bucket, path: thumbPath, fit: BoxFit.contain, showProblem: false),
        if (note != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.s12 * 2,
            child: Center(
              child: Container(
                key: const Key('photo-full-note'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s1,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.black.withValues(alpha: 0.6),
                  borderRadius: AppRadii.allPill,
                ),
                child: Text(note, style: context.text.caption.w(600).copyWith(color: c.onHero)),
              ),
            ),
          ),
      ],
    );
  }
}
