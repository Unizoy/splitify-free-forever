import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/features/attachments/application/attachment_providers.dart';
import 'package:splitify/features/attachments/presentation/attachment_widgets.dart';
import 'package:splitify/features/photos/presentation/photo_viewer_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// A PDF attachment full screen (W2-Y, S-433): its pages drawn by Android's PdfRenderer, one under the
/// other; a tap opens a page sharper in the zoom viewer. "Open with" hands it to another app. A PDF that is
/// not on this phone downloads once (signed URL); offline it says so.
class PdfViewerScreen extends ConsumerStatefulWidget {
  const PdfViewerScreen({required this.name, this.bytes, this.path, this.onRemove, super.key})
    : assert(bytes != null || path != null, 'a PDF to show');

  static Future<void> open(
    BuildContext context, {
    required String name,
    Uint8List? bytes,
    String? path,
    Future<bool> Function()? onRemove,
  }) => Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PdfViewerScreen(name: name, bytes: bytes, path: path, onRemove: onRemove),
    ),
  );

  final String name;

  /// A PDF picked in this session (not saved yet), or the stored attachment [path].
  final Uint8List? bytes;
  final String? path;
  final Future<bool> Function()? onRemove;

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  Future<File>? _picked;
  File? _pickedFile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final bytes = widget.bytes;
    if (bytes != null) {
      _picked = _writeTemp(bytes);
      unawaited(
        _picked!.then((f) {
          if (mounted) setState(() => _pickedFile = f);
        }, onError: (Object _) {}),
      );
    }
  }

  /// PdfRenderer reads files: a picked PDF is written to the cache first.
  static Future<File> _writeTemp(Uint8List bytes) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/pdf-preview');
    await dir.create(recursive: true);
    return File('${dir.path}/${newId()}.pdf').writeAsBytes(bytes, flush: true);
  }

  Future<void> _openWith(File file) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(pdfPlatformProvider).openExternally(file.path, widget.name);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.w2yPdfNoApp)));
    }
  }

  Future<void> _remove() async {
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final removed = await widget.onRemove!();
    if (!mounted) return;
    setState(() => _busy = false);
    if (removed) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final AsyncValue<File> file = _picked != null
        ? const AsyncLoading<File>()
        : ref.watch(attachmentFileProvider(widget.path!));
    Widget withFile(File f) => _Pages(file: f, name: widget.name);
    final body = _picked != null
        ? FutureBuilder<File>(
            future: _picked,
            builder: (context, snap) => snap.hasData
                ? withFile(snap.data!)
                : snap.hasError
                ? _Problem(text: l.w2yPdfUnreadable)
                : const _Loading(),
          )
        : switch (file) {
            AsyncData(:final value) => withFile(value),
            AsyncError(:final error) => _Problem(
              text: error is MediaOffline ? l.w2yPdfOffline : l.w2yPdfUnreadable,
              icon: error is MediaOffline ? AppIcons.cloudUpload : AttachmentIcons.pdf,
            ),
            _ => const _Loading(),
          };
    final current = _pickedFile ?? file.value;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s3,
                  AppSpacing.s2,
                  AppSpacing.s3,
                  AppSpacing.s2,
                ),
                child: Row(
                  children: [
                    HeroIconButton(
                      key: const Key('pdf-close'),
                      icon: AppIcons.close,
                      tooltip: l.close,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.title.w(600).copyWith(color: c.onHero),
                      ),
                    ),
                    HeroIconButton(
                      key: const Key('pdf-open-with'),
                      icon: AttachmentIcons.openExternal,
                      tooltip: l.w2yPdfOpenWith,
                      onPressed: current == null ? null : () => unawaited(_openWith(current)),
                    ),
                  ],
                ),
              ),
              Expanded(child: body),
              if (widget.onRemove != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.s3,
                    AppSpacing.screen,
                    AppSpacing.s4,
                  ),
                  child: PillButton(
                    key: const Key('pdf-remove'),
                    label: l.photoRemove,
                    icon: AppIcons.trash,
                    variant: PillVariant.inverse,
                    size: PillSize.medium,
                    expand: false,
                    onPressed: _busy ? null : () => unawaited(_remove()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every page of [file], rendered at the screen's width.
class _Pages extends ConsumerStatefulWidget {
  const _Pages({required this.file, required this.name});

  final File file;
  final String name;

  @override
  ConsumerState<_Pages> createState() => _PagesState();
}

class _PagesState extends ConsumerState<_Pages> {
  late final Future<int> _count = ref.read(pdfPlatformProvider).pageCount(widget.file.path);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<int>(
      future: _count,
      builder: (context, snap) {
        if (snap.hasError) return _Problem(text: l.w2yPdfUnreadable, icon: AttachmentIcons.pdf);
        final count = snap.data;
        if (count == null) return const _Loading();
        if (count == 0) return _Problem(text: l.w2yPdfUnreadable, icon: AttachmentIcons.pdf);
        return LayoutBuilder(
          builder: (context, box) {
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final width = (box.maxWidth * dpr).round().clamp(320, 1600);
            return ListView.separated(
              key: const Key('pdf-pages'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s2,
                AppSpacing.s4,
                AppSpacing.s6,
              ),
              itemCount: count,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
              itemBuilder: (context, i) =>
                  _Page(file: widget.file, index: i, count: count, width: width, name: widget.name),
            );
          },
        );
      },
    );
  }
}

class _Page extends ConsumerStatefulWidget {
  const _Page({
    required this.file,
    required this.index,
    required this.count,
    required this.width,
    required this.name,
  });

  final File file;
  final int index;
  final int count;
  final int width;
  final String name;

  @override
  ConsumerState<_Page> createState() => _PageState();
}

class _PageState extends ConsumerState<_Page> {
  late final Future<Uint8List> _png = ref
      .read(pdfPlatformProvider)
      .renderPage(widget.file.path, widget.index, widget.width);

  Future<void> _zoom() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final sharp = await ref
        .read(pdfPlatformProvider)
        .renderPage(widget.file.path, widget.index, (widget.width * 2).clamp(640, 2400));
    if (!mounted) return;
    await PhotoViewerScreen.open(
      navigator.context,
      title: l.w2yPdfPage(widget.index + 1, widget.count),
      bytes: sharp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return FutureBuilder<Uint8List>(
      future: _png,
      builder: (context, snap) {
        final png = snap.data;
        return Semantics(
          button: png != null,
          image: true,
          label: l.w2yPdfPage(widget.index + 1, widget.count),
          excludeSemantics: true,
          onTap: png == null ? null : () => unawaited(_zoom()),
          child: GestureDetector(
            key: Key('pdf-page-${widget.index}'),
            onTap: png == null ? null : () => unawaited(_zoom()),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.r8),
              child: png != null
                  ? Image.memory(png, gaplessPlayback: true, fit: BoxFit.fitWidth)
                  : AspectRatio(
                      aspectRatio: 1 / 1.414,
                      child: ColoredBox(
                        color: c.surfaceMuted,
                        child: snap.hasError
                            ? Center(
                                child: Icon(AttachmentIcons.pdf, size: 32, color: c.textTertiary),
                              )
                            : null,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
    child: DotsPulse(
      color: context.colors.onHero,
      semanticLabel: AppLocalizations.of(context).loading,
    ),
  );
}

class _Problem extends StatelessWidget {
  const _Problem({required this.text, this.icon = AttachmentIcons.pdf});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: c.onHeroMuted),
            const SizedBox(height: AppSpacing.s3),
            Text(
              text,
              key: const Key('pdf-problem'),
              textAlign: TextAlign.center,
              style: context.text.body.copyWith(color: c.onHero),
            ),
          ],
        ),
      ),
    );
  }
}
