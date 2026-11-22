import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/config/app_info.dart';

void main() {
  test('appVersion matches the pubspec version name (phase 19 T6)', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final name = line.substring('version:'.length).trim().split('+').first;
    expect(appVersion, name);
  });

  test('project links point at the public repository', () {
    expect(privacyUrl, startsWith(repoUrl));
    expect(issuesUrl, startsWith(repoUrl));
    expect(Uri.parse(privacyUrl).isAbsolute, isTrue);
  });
}
