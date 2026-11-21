// Static guards (gate G1). Run: dart run tool/guards.dart
// ignore_for_file: avoid_print
import 'dart:io';

class Violation {
  Violation(this.rule, this.file, this.line, this.text);
  final String rule;
  final String file;
  final int line;
  final String text;
  @override
  String toString() => '[$rule] $file:$line  ${text.trim()}';
}

final _moneyType = RegExp(r'\b(double|num)\b');
final _supabaseImport = RegExp(r'''import\s+['"]package:(supabase_flutter|supabase)/''');
final _printCall = RegExp(r'(^|[^\w.])print\(');
final _secret = RegExp(
  r'sb_(publishable|secret)_[A-Za-z0-9_-]{10,}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}|AIza[0-9A-Za-z_-]{30,}',
);
final _literalString = RegExp(
  r'''\bText\(\s*['"]|\b(labelText|hintText|tooltip|semanticsLabel|helperText|errorText):\s*['"]''',
);

// Design tokens only (planning/06-design-system.md §9): no literal colours or
// text styles outside lib/ui/theme/.
final _literalStyle = RegExp(r'\bColor\(0x|\bColor\.from(ARGB|RGBO)\(|\bColors\.|\bTextStyle\(');

String _norm(String p) => p.replaceAll('\\', '/');

Iterable<File> _files(String dir, {String ext = '.dart'}) sync* {
  final d = Directory(dir);
  if (!d.existsSync()) return;
  for (final e in d.listSync(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final p = _norm(e.path);
    if (p.contains('/build/') || p.contains('/.dart_tool/')) continue;
    if (ext.isEmpty || p.endsWith(ext)) yield e;
  }
}

void main() {
  final out = <Violation>[];

  for (final f in _files('lib')) {
    final path = _norm(f.path);
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;
    if (path.startsWith('lib/l10n/')) continue;
    final lines = f.readAsLinesSync();
    final inMoney = path.startsWith('lib/core/money/') || path.startsWith('lib/domain/');
    final inRemote = path.startsWith('lib/data/remote/');
    final inWidgets =
        path.startsWith('lib/features/') ||
        path.startsWith('lib/ui/') ||
        path.startsWith('lib/app/');
    final inTheme = path.startsWith('lib/ui/theme/');
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.trimLeft().startsWith('//')) continue;
      if (inMoney && _moneyType.hasMatch(l)) {
        out.add(Violation('money-no-float', path, i + 1, l));
      }
      if (!inRemote && _supabaseImport.hasMatch(l)) {
        out.add(Violation('supabase-only-in-remote', path, i + 1, l));
      }
      if (_printCall.hasMatch(l)) {
        out.add(Violation('no-print', path, i + 1, l));
      }
      if (!inTheme && _literalStyle.hasMatch(l)) {
        out.add(Violation('ui-tokens-only', path, i + 1, l));
      }
      if (inWidgets && _literalString.hasMatch(l)) {
        out.add(Violation('l10n-no-literal', path, i + 1, l));
      }
    }
  }

  for (final dir in ['lib', 'test', 'integration_test', 'tool', 'supabase', '.github']) {
    for (final f in _files(dir, ext: '')) {
      final path = _norm(f.path);
      if (path.endsWith('tool/guards.dart')) continue;
      if (path.contains('/fixtures/')) continue;
      List<String> lines;
      try {
        lines = f.readAsLinesSync();
      } on FileSystemException {
        continue;
      } on FormatException {
        continue;
      }
      for (var i = 0; i < lines.length; i++) {
        if (_secret.hasMatch(lines[i])) {
          out.add(Violation('secret-looking', path, i + 1, '(hidden)'));
        }
      }
    }
  }

  if (out.isEmpty) {
    print('guards: OK');
    return;
  }
  out.forEach(print);
  print('guards: ${out.length} violation(s)');
  exit(1);
}
