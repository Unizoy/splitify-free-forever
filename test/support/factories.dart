// Test data factories (aGroup(), anExpense(), ...). Filled in from phase 03/07.
// Ids come from fixed seeds so tests stay deterministic.

/// Deterministic id for tests: `id(1)` -> a stable UUID-shaped string.
String id(int n) => '00000000-0000-7000-8000-${n.toRadixString(16).padLeft(12, '0')}';
