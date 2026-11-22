// Dart port of android/app/src/full/kotlin/com/unizoy/splitify/capture/PaymentParser.kt (phase 18b, S-221/S-229).
// It proves the recipes JSON means the same in Dart's regex engine as in Java's, and that the Kotlin text rules
// (normalising, paise, payee clean-up) are reproducible. Keep both in step.
import 'dart:convert';
import 'dart:io';

/// Parsed debit or the reason it was ignored, or a screen stage.
typedef Outcome = ({String kind, Map<String, Object?> fields});

class RecipeEvaluator {
  RecipeEvaluator(Map<String, Object?> json)
    : maxAmount = json['maxAmountPaise']! as int,
      _apps = {for (final a in json['apps']! as List) (a as Map)['package'] as String: a},
      _ignore = [for (final r in json['ignore']! as List) _Rule.of(r as Map)],
      _debit = [for (final r in json['debit']! as List) _Rule.of(r as Map)],
      _refs = [for (final p in json['refs']! as List) _rx(p as String)],
      _reject = _rx(json['payeeReject']! as String),
      _pin = _rx(((json['screen']! as Map)['pin'])! as String),
      _paying = _rx(((json['screen']! as Map)['paying'])! as String),
      _success = [for (final r in (json['screen']! as Map)['success'] as List) _Rule.of(r as Map)];

  factory RecipeEvaluator.load() => RecipeEvaluator(
    jsonDecode(File('android/app/src/full/assets/payment_recipes.json').readAsStringSync())
        as Map<String, Object?>,
  );

  final int maxAmount;
  final Map<String, Map<Object?, Object?>> _apps;
  final List<_Rule> _ignore;
  final List<_Rule> _debit;
  final List<RegExp> _refs;
  final RegExp _reject;
  final RegExp _pin;
  final RegExp _paying;
  final List<_Rule> _success;

  static final _phone = RegExp(r'^\+?[0-9][0-9 ()-]{3,}$');

  Map<Object?, Object?>? _app(String pkg, {required bool debug}) {
    final a = _apps[pkg];
    if (a == null || (!debug && a['debugOnly'] == true)) return null;
    return a;
  }

  Outcome notification(String pkg, String title, String text, {required bool debug}) {
    final app = _app(pkg, debug: debug);
    if (app == null) return _ignored('app');
    if (app['kind'] == 'sms') {
      if (!debug && _phone.hasMatch(normalize(title))) return _ignored('sender');
      return _body(normalize(text), 'sms', _debit);
    }
    return _body(joinTitle(title, text), 'notification', _debit);
  }

  Outcome screen(String pkg, String text, {required bool debug}) {
    if (_app(pkg, debug: debug) == null) return _stage('none');
    final body = normalize(text);
    if (_pin.hasMatch(body)) return _stage('pin');
    final r = _body(body, 'screen', _success);
    if (r.kind == 'debit') return r;
    if (r.fields['reason'] != 'failed' && _paying.hasMatch(body)) return _stage('paying');
    return _stage('none');
  }

  Outcome _body(String body, String source, List<_Rule> rules) {
    for (final r in _ignore) {
      if (r.regex.hasMatch(body) && !(r.unless?.hasMatch(body) ?? false)) return _ignored(r.id);
    }
    for (final r in rules) {
      final m = r.regex.firstMatch(body);
      if (m == null) continue;
      final amount = toPaise(m.namedGroup('amount'));
      if (amount == null || amount <= 0 || amount > maxAmount) return _ignored('amount');
      final payee = m.groupNames.contains('payee') ? cleanPayee(m.namedGroup('payee')) : null;
      if (payee != null && _reject.hasMatch(payee)) return _ignored('payee');
      final ref = (m.groupNames.contains('ref') ? m.namedGroup('ref') : null) ?? _firstRef(body);
      return (
        kind: 'debit',
        fields: {'amount': amount, 'payee': payee, 'ref': ref, 'source': source, 'rule': r.id},
      );
    }
    return _ignored('nomatch');
  }

  String? _firstRef(String body) {
    for (final r in _refs) {
      final m = r.firstMatch(body);
      if (m != null) return m.namedGroup('ref');
    }
    return null;
  }

  static Outcome _ignored(String reason) => (kind: 'ignore', fields: {'reason': reason});
  static Outcome _stage(String stage) => (kind: 'stage', fields: {'stage': stage});
}

class _Rule {
  _Rule(this.id, this.regex, this.unless);

  factory _Rule.of(Map<Object?, Object?> j) => _Rule(
    j['id']! as String,
    _rx(j['pattern']! as String),
    j['unless'] == null ? null : _rx(j['unless']! as String),
  );

  final String id;
  final RegExp regex;
  final RegExp? unless;
}

/// Same flags as Kotlin `RegexOption.IGNORE_CASE` (ASCII case folding, no Unicode mode).
RegExp _rx(String p) => RegExp(p, caseSensitive: false);

final _spaces = RegExp('[ \t\r\n\f\u000B    ]+');
final _tail = RegExp(r'[ .,;:-]+$');

String normalize(String s) => s.replaceAll(_spaces, ' ').trim();

String joinTitle(String title, String text) {
  final t = normalize(title);
  final b = normalize(text);
  if (t.isEmpty) return b;
  if (b.isEmpty) return t;
  return '.!?:'.contains(t[t.length - 1]) ? '$t $b' : '$t. $b';
}

int? toPaise(String? raw) {
  if (raw == null) return null;
  final parts = raw.replaceAll(',', '').split('.');
  final digits = RegExp(r'^[0-9]*$');
  if (parts.length > 2 || parts[0].isEmpty || parts[0].length > 10 || !digits.hasMatch(parts[0])) {
    return null;
  }
  final frac = parts.length == 2 ? parts[1] : '';
  if (frac.length > 2 || !digits.hasMatch(frac)) return null;
  return int.parse(parts[0]) * 100 + int.parse(frac.padRight(2, '0'));
}

String? cleanPayee(String? raw) {
  var s = normalize(raw ?? '').replaceFirst(RegExp(r'^[. ]+'), '');
  s = s.replaceFirst(_tail, '');
  if (s.isEmpty) return null;
  if (s.length > 60) s = s.substring(0, 60).trimRight();
  final letters = RegExp('[A-Za-z]').hasMatch(s);
  final lower = RegExp('[a-z]').hasMatch(s);
  if (letters && !lower && !s.contains('@')) {
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
  return s;
}
