// Auto-category for payment-bubble captures (D-028, S-273): the payee or note picks the category of the
// prefilled expense, and typing can still change it.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/category_memory.dart';
import 'package:splitify/features/capture/application/capture_providers.dart';
import 'package:splitify/features/expenses/application/category_providers.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';

import '../../support/capture_fakes.dart';
import '../../support/category_support.dart';
import '../expenses/application/expense_test_env.dart';

final _at = DateTime.utc(2026, 11, 20, 8, 30);

void main() {
  late ExpenseEnv env;
  late FakeCaptureBridge bridge;
  late CategoryMemory memory;

  setUp(() async {
    bridge = FakeCaptureBridge();
    memory = CategoryMemory.inMemory();
    env = await ExpenseEnv.create(
      overrides: [
        captureBridgeProvider.overrideWithValue(bridge),
        categorySuggesterProvider.overrideWith((ref) async => suggester),
        categoryMemoryProvider.overrideWithValue(memory),
      ],
    );
  });
  tearDown(() => env.dispose());

  Future<ExpenseDraft> open(Map<String, Object?> raw) async {
    bridge.captures = [raw];
    await env.container.read(captureRepositoryProvider).importNow();
    final p = captureEditorProvider((groupId: env.groupId, captureId: captureId1));
    env.container.listen(p, (_, _) {});
    return env.container.read(p.future);
  }

  test('the payee picks the category', () async {
    final d = await open(rawCapture(payee: 'Swiggy', at: _at));
    expect(d.category, 'food.takeaway');
    expect(d.categoryOrigin, CategoryOrigin.auto);
    expect(d.baseCategory, 'other.general');
  });

  test('a UPI ID payee and a note both count; the brand wins', () async {
    final d = await open(rawCapture(payee: 'uber.india@hdfcbank', note: 'dinner drop', at: _at));
    expect(d.category, 'travel.cab_auto');
  });

  test('no match keeps the group default and still follows typing', () async {
    final d = await open(rawCapture(payee: 'Rahul', at: _at));
    expect(d.category, 'other.general');
    expect(d.categoryFollowsDescription, isTrue);
    final c = env.container.read(
      captureEditorProvider((groupId: env.groupId, captureId: captureId1)).notifier,
    );
    c
      ..edit((x) => x.copyWith(description: 'Rahul petrol'))
      ..suggestCategory();
    expect(
      env.container
          .read(captureEditorProvider((groupId: env.groupId, captureId: captureId1)))
          .value!
          .category,
      'travel.fuel',
    );
  });

  test('what the user taught wins for a payee', () async {
    await memory.learn({'rahul': 'rent.rent'});
    expect((await open(rawCapture(payee: 'Rahul', at: _at))).category, 'rent.rent');
  });
}
