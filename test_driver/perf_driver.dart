// Host side of integration_test/perf_test.dart (T7): turns the scroll timeline into a frame summary and
// prints the numbers the phase report records.
//   flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart \
//     -d emulator-5554 --dart-define-from-file=secrets/env.dev.json
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    for (final key in ['scroll_timeline', 'open_timeline']) {
      final raw = data[key];
      if (raw is! Map<String, dynamic>) continue;
      final summary = TimelineSummary.summarize(Timeline.fromJson(raw));
      await summary.writeTimelineToFile(key, pretty: true);
      final s = summary.summaryJson;
      stdout.writeln(
        'PERF $key frames=${s['frame_count']} '
        'build_avg=${s['average_frame_build_time_millis']} '
        'build_p90=${s['90th_percentile_frame_build_time_millis']} '
        'build_worst=${s['worst_frame_build_time_millis']} '
        'raster_avg=${s['average_frame_rasterizer_time_millis']} '
        'raster_p90=${s['90th_percentile_frame_rasterizer_time_millis']} '
        'missed_build=${s['missed_frame_build_budget_count']} '
        'missed_raster=${s['missed_frame_rasterizer_budget_count']}',
      );
    }
    final rest = Map.of(data)
      ..remove('scroll_timeline')
      ..remove('open_timeline');
    stdout.writeln('PERF numbers ${jsonEncode(rest)}');
  },
);
