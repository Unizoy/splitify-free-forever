// Host side of the profile-mode perf tests (integration_test/perf_test.dart, T7, and
// integration_test/perf_screens_test.dart): turns every reported `*_timeline` into a frame summary and
// prints the numbers the reports record.
//   flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf_test.dart -d emulator-5554 --dart-define-from-file=secrets/env.dev.json
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final timelines = [
      for (final key in data.keys)
        if (key.endsWith('_timeline')) key,
    ];
    for (final key in timelines) {
      final raw = data[key];
      if (raw is! Map<String, dynamic>) continue;
      try {
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
      } on Object catch (e) {
        stdout.writeln('PERF $key summary failed: $e');
      }
    }
    final rest = Map.of(data)..removeWhere((key, _) => timelines.contains(key));
    stdout.writeln('PERF numbers ${jsonEncode(rest)}');
  },
);
