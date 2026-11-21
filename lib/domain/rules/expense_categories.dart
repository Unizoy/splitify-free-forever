/// Expense category keys `parent.sub` (planning/08-feature-specs.md #13). The UI maps parents to icons
/// and every key to ARB text.
abstract final class ExpenseCategories {
  /// Category of a new expense when nothing else is known.
  static const defaultKey = 'other.general';

  /// Parent → sub keys, in picker order.
  static const tree = <String, List<String>>{
    'food': ['food.dining_out', 'food.takeaway', 'food.snacks'],
    'groceries': ['groceries.groceries', 'groceries.household'],
    'travel': [
      'travel.flights',
      'travel.train_bus',
      'travel.cab_auto',
      'travel.fuel',
      'travel.hotel',
      'travel.parking_tolls',
    ],
    'rent': ['rent.rent', 'rent.maintenance'],
    'utilities': [
      'utilities.electricity',
      'utilities.water',
      'utilities.gas',
      'utilities.internet_phone',
      'utilities.subscriptions',
    ],
    'shopping': ['shopping.clothing', 'shopping.electronics', 'shopping.gifts', 'shopping.other'],
    'entertainment': [
      'entertainment.movies',
      'entertainment.events',
      'entertainment.games',
      'entertainment.sports',
    ],
    'other': ['other.general', 'other.medical', 'other.education', 'other.services'],
  };

  /// True for one of the keys in [tree].
  static bool isKnown(String key) => tree[parentOf(key)]?.contains(key) ?? false;

  /// The parent part of [key] (`food` for `food.snacks`); unknown parents count as `other`.
  static String parentOf(String key) {
    final parent = key.split('.').first;
    return tree.containsKey(parent) ? parent : 'other';
  }

  /// [key] when known, else [defaultKey] (imported or future keys still show).
  static String normalize(String key) => isKnown(key) ? key : defaultKey;
}
