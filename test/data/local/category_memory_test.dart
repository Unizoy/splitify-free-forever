// Auto-category learning store (D-028, S-272): per user, on this phone only.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/data/local/category_memory.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('learns, persists and reads back per user', () async {
    final a = CategoryMemory(prefs, userId: 'u1');
    await a.learn({'starbucks': 'food.dining_out'});
    await a.learn({'maid': 'other.services'});
    expect(a.entries, {'starbucks': 'food.dining_out', 'maid': 'other.services'});
    expect(CategoryMemory(prefs, userId: 'u1').entries, a.entries);
    expect(CategoryMemory(prefs, userId: 'u2').entries, isEmpty);
    expect(prefs.getString('${CategoryMemory.keyPrefix}u1'), contains('starbucks'));
  });

  test('a phrase taught again moves to the newest end with its new category', () async {
    final m = CategoryMemory(prefs, userId: 'u1');
    await m.learn({'a': 'food.snacks', 'b': 'food.snacks'});
    await m.learn({'a': 'food.takeaway'});
    expect(m.entries.keys, ['b', 'a']);
    expect(m.entries['a'], 'food.takeaway');
    await m.learn(const {});
    expect(m.entries.length, 2);
  });

  test('keeps at most maxEntries, dropping the oldest', () async {
    final m = CategoryMemory(prefs, userId: 'u1');
    await m.learn({for (var i = 0; i < CategoryMemory.maxEntries + 5; i++) 'p$i': 'food.snacks'});
    expect(m.entries.length, CategoryMemory.maxEntries);
    expect(m.entries.containsKey('p0'), isFalse);
    expect(m.entries.containsKey('p${CategoryMemory.maxEntries + 4}'), isTrue);
  });

  test('a damaged value starts over; clear forgets', () async {
    await prefs.setString('${CategoryMemory.keyPrefix}u1', '{not json');
    final m = CategoryMemory(prefs, userId: 'u1');
    expect(m.entries, isEmpty);
    await prefs.setString('${CategoryMemory.keyPrefix}u3', '{"ok":"food.snacks","bad":3}');
    expect(CategoryMemory(prefs, userId: 'u3').entries, {'ok': 'food.snacks'});
    await m.learn({'x': 'food.snacks'});
    await m.clear();
    expect(m.entries, isEmpty);
    expect(prefs.getString('${CategoryMemory.keyPrefix}u1'), isNull);
  });

  test('without preferences it remembers for this run only (signed out key)', () async {
    final m = CategoryMemory.inMemory();
    await m.learn({'x': 'food.snacks'});
    expect(m.entries, {'x': 'food.snacks'});
    expect(CategoryMemory(prefs, userId: null).entries, isEmpty);
  });
}
