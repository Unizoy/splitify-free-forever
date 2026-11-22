// TC-29 UI: photo viewer, stored/memory photo states, "Add a photo" sheet.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/features/photos/presentation/photo_source_sheet.dart';
import 'package:splitify/features/photos/presentation/photo_viewer_screen.dart';
import 'package:splitify/features/photos/presentation/stored_photo.dart';

import '../../../support/photo_fixtures.dart';
import '../../../support/sample_photo.dart';
import '../../expenses/expense_fixtures.dart';
import '../../expenses/presentation/presentation_harness.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _pump(WidgetTester t, Widget child, {List<Override> overrides = const []}) async {
  usePhone(t);
  await t.pumpWidget(expenseApp(PushHost(child), overrides: overrides));
  await t.tap(_key('open'));
  await settle(t);
}

double _scale(WidgetTester t) => t
    .widget<InteractiveViewer>(_key('photo-zoom'))
    .transformationController!
    .value
    .getMaxScaleOnAxis();

Future<void> _doubleTap(WidgetTester t) async {
  final at = t.getCenter(_key('photo-zoom'));
  await t.tapAt(at);
  await t.pump(const Duration(milliseconds: 50));
  await t.tapAt(at);
  await settle(t);
}

/// A photo that never resolves (loading tile).
Override _loading(String path) =>
    storedPhotoProvider((bucket: MediaBuckets.receipts, path: path, thumb: true))
        .overrideWith((ref) => Completer<File>().future);

Override _failing(String path, Object error) =>
    storedPhotoProvider((bucket: MediaBuckets.receipts, path: path, thumb: true))
        .overrideWith((ref) async => throw error);

void main() {
  group('PhotoViewerScreen', () {
    // TC-29 UI
    testWidgets('shows the photo from memory and closes with the close button', (t) async {
      await _pump(t, PhotoViewerScreen(title: 'Receipt photo', bytes: samplePhotoPng));
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(find.byType(MemoryPhoto), findsOneWidget);
      expect(find.text('Receipt photo'), findsOneWidget);
      await tapKey(t, 'photo-close');
      expect(find.byType(PhotoViewerScreen), findsNothing);
    });

    // TC-29 UI
    testWidgets('shows a stored photo through StoredPhoto', (t) async {
      final file = samplePhotoFile(addTearDown);
      await _pump(
        t,
        const PhotoViewerScreen(
          title: 'Receipt photo',
          bucket: MediaBuckets.receipts,
          path: 'g/e/p.jpg',
        ),
        overrides: storedReceipt('g/e/p.jpg', file),
      );
      expect(find.byType(StoredPhoto), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('double-tap zooms in, a second double-tap resets', (t) async {
      await _pump(t, PhotoViewerScreen(title: 'Receipt photo', bytes: samplePhotoPng));
      expect(_scale(t), closeTo(1, 0.001));
      await _doubleTap(t);
      expect(_scale(t), greaterThan(1));
      await _doubleTap(t);
      expect(_scale(t), closeTo(1, 0.001));
    });

    // TC-29 UI
    testWidgets('the photo fills the whole screen', (t) async {
      await _pump(t, PhotoViewerScreen(title: 'Receipt photo', bytes: samplePhotoPng));
      expect(t.getSize(_key('photo-zoom')), const Size(412, 915));
    });

    // TC-29 UI
    testWidgets('no Replace/Remove buttons without callbacks', (t) async {
      await _pump(t, PhotoViewerScreen(title: 'Receipt photo', bytes: samplePhotoPng));
      expect(_key('photo-replace'), findsNothing);
      expect(_key('photo-remove'), findsNothing);
    });

    // TC-29 UI
    testWidgets('only the given callbacks show a button', (t) async {
      await _pump(
        t,
        PhotoViewerScreen(
          title: 'Receipt photo',
          bytes: samplePhotoPng,
          onRemove: () async => false,
        ),
      );
      expect(_key('photo-replace'), findsNothing);
      expect(_key('photo-remove'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('a callback returning true closes the viewer', (t) async {
      var calls = 0;
      await _pump(
        t,
        PhotoViewerScreen(
          title: 'Receipt photo',
          bytes: samplePhotoPng,
          onReplace: () async {
            calls++;
            return true;
          },
          onRemove: () async => false,
        ),
      );
      await tapKey(t, 'photo-replace');
      expect(calls, 1);
      expect(find.byType(PhotoViewerScreen), findsNothing);
    });

    // TC-29 UI
    testWidgets('a callback returning false keeps the viewer open and re-enables the buttons', (
      t,
    ) async {
      var calls = 0;
      await _pump(
        t,
        PhotoViewerScreen(
          title: 'Receipt photo',
          bytes: samplePhotoPng,
          onReplace: () async => false,
          onRemove: () async {
            calls++;
            return false;
          },
        ),
      );
      await tapKey(t, 'photo-remove');
      expect(calls, 1);
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(buttonEnabled(t, 'photo-remove'), isTrue);
    });

    // TC-29 UI
    testWidgets('buttons are disabled while an action runs', (t) async {
      final done = Completer<bool>();
      await _pump(
        t,
        PhotoViewerScreen(
          title: 'Receipt photo',
          bytes: samplePhotoPng,
          onReplace: () => done.future,
          onRemove: () async => false,
        ),
      );
      await tapKey(t, 'photo-replace');
      expect(buttonEnabled(t, 'photo-remove'), isFalse);
      expect(buttonEnabled(t, 'photo-replace'), isFalse);
      done.complete(true);
      await settle(t);
      expect(find.byType(PhotoViewerScreen), findsNothing);
    });

    // TC-29 UI
    testWidgets('open() pushes the viewer above the current route', (t) async {
      usePhone(t);
      await t.pumpWidget(
        expenseApp(
          Builder(
            builder: (context) => ElevatedButton(
              key: const Key('go'),
              onPressed: () => unawaited(
                PhotoViewerScreen.open(context, title: 'Cover photo', bytes: samplePhotoPng),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await t.tap(_key('go'));
      await settle(t);
      expect(find.text('Cover photo'), findsOneWidget);
    });
  });

  group('StoredPhoto / MemoryPhoto / PhotoProblem', () {
    Future<void> pumpPhoto(WidgetTester t, Widget child, List<Override> overrides) async {
      usePhone(t);
      await t.pumpWidget(
        expenseApp(
          Center(child: SizedBox.square(dimension: 160, child: child)),
          overrides: overrides,
        ),
      );
      await settle(t);
    }

    const stored = StoredPhoto(bucket: MediaBuckets.receipts, path: 'p1');

    // TC-29 UI
    testWidgets('data shows an Image', (t) async {
      final file = samplePhotoFile(addTearDown);
      await pumpPhoto(t, stored, storedReceipt('p1', file));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Photo not available'), findsNothing);
    });

    // TC-29 UI
    testWidgets('offline error says it shows when online', (t) async {
      await pumpPhoto(t, stored, [_failing('p1', const MediaOffline())]);
      expect(find.text("Shows when you're online"), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('other error says the photo is not available', (t) async {
      await pumpPhoto(t, stored, [_failing('p1', StateError('gone'))]);
      expect(find.text('Photo not available'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('showProblem false hides the line but keeps the semantics label', (t) async {
      await pumpPhoto(
        t,
        const StoredPhoto(bucket: MediaBuckets.receipts, path: 'p1', showProblem: false),
        [_failing('p1', const MediaOffline())],
      );
      expect(find.text("Shows when you're online"), findsNothing);
      expect(find.bySemanticsLabel("Shows when you're online"), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('loading shows a quiet tile labelled Loading', (t) async {
      await pumpPhoto(t, stored, [_loading('p1')]);
      expect(find.byType(Image), findsNothing);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('MemoryPhoto shows an Image', (t) async {
      await pumpPhoto(t, MemoryPhoto(bytes: samplePhotoPng), const []);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(PhotoProblem), findsNothing);
    });

    // TC-29 UI
    testWidgets('PhotoProblem offline and unavailable use their own text', (t) async {
      await pumpPhoto(t, const PhotoProblem(offline: true), const []);
      expect(find.text("Shows when you're online"), findsOneWidget);
      await pumpPhoto(t, const PhotoProblem(offline: false), const []);
      expect(find.text('Photo not available'), findsOneWidget);
    });
  });

  group('pickPhoto sheet', () {
    PreparedImage? result;
    var finished = false;

    Future<void> open(WidgetTester t, List<Override> overrides) async {
      result = null;
      finished = false;
      usePhone(t);
      await t.pumpWidget(
        expenseApp(
          Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                key: const Key('pick'),
                onPressed: () => unawaited(
                  pickPhoto(context, ref).then((v) {
                    result = v;
                    finished = true;
                  }),
                ),
                child: const Text('pick'),
              ),
            ),
          ),
          overrides: overrides,
        ),
      );
      await t.tap(_key('pick'));
      await settle(t);
    }

    // TC-29 UI
    testWidgets('lists camera and gallery; cancelling returns null', (t) async {
      await open(t, [pickerReturns(samplePrepared)]);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from your photos'), findsOneWidget);
      await t.tapAt(const Offset(200, 20));
      await settle(t);
      expect(finished, isTrue);
      expect(result, isNull);
    });

    // TC-29 UI
    testWidgets('choosing gallery returns the prepared photo', (t) async {
      await open(t, [pickerReturns(samplePrepared)]);
      await tapKey(t, 'photo-gallery');
      expect(result, same(samplePrepared));
    });

    // TC-29 UI
    testWidgets('a failing picker returns null and shows the snackbar', (t) async {
      await open(t, [pickerThrows()]);
      await tapKey(t, 'photo-camera');
      expect(result, isNull);
      expect(finished, isTrue);
      expect(find.text("Couldn't use that photo. Try another one."), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('the picker gets the chosen source', (t) async {
      final sources = <PhotoSource>[];
      await open(t, [
        preparedPhotoPickerProvider.overrideWithValue((s) async {
          sources.add(s);
          return null;
        }),
      ]);
      await tapKey(t, 'photo-camera');
      expect(sources, [PhotoSource.camera]);
    });
  });
}
