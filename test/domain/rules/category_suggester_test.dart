// Auto-category (D-028, S-270..S-273): the keyword file and the matcher.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/rules/category_suggester.dart';
import 'package:splitify/domain/rules/expense_categories.dart';

final _file = File('assets/category_keywords.json');
final _json = (jsonDecode(_file.readAsStringSync()) as Map).cast<String, Object?>();
final _s = CategorySuggester.fromJson(_json);

/// Description → expected category (null = no match, the editor keeps its category).
const _vectors = <(String, String?)>[
  // Food delivery and dining (owner's list).
  ('Swiggy', 'food.takeaway'),
  ('swiggy order', 'food.takeaway'),
  ('ZOMATO', 'food.takeaway'),
  ('Zomato dinner', 'food.takeaway'),
  ('EatSure', 'food.takeaway'),
  ("Domino's", 'food.takeaway'),
  ('Dominos pizza', 'food.takeaway'),
  ("McDonald's", 'food.dining_out'),
  ('KFC bucket', 'food.dining_out'),
  ('Burger King', 'food.dining_out'),
  ('Starbucks', 'food.snacks'),
  ('Chaayos', 'food.snacks'),
  ('Dinner at Thalassa', 'food.dining_out'),
  ('Lunch', 'food.dining_out'),
  ('breakfast', 'food.dining_out'),
  ('Restaurant bill', 'food.dining_out'),
  ('Café Mondegar', 'food.dining_out'),
  ('dhaba stop', 'food.dining_out'),
  ('Snacks', 'food.snacks'),
  ('chai', 'food.snacks'),
  ('Coffee', 'food.snacks'),
  ('Pizza night', 'food.dining_out'),
  ('Biryani', 'food.dining_out'),
  ('F&B', 'food.dining_out'),
  ('Drinks at the bar', 'food.dining_out'),
  ('Pub crawl', 'food.dining_out'),
  ('Cafe Coffee Day', 'food.snacks'),
  ('cold drinks', 'food.snacks'),
  ('Uber Eats', 'food.takeaway'),
  ('Swiggy Dineout', 'food.dining_out'),
  ('ice cream', 'food.snacks'),
  // Groceries.
  ('Blinkit', 'groceries.groceries'),
  ('Zepto order', 'groceries.groceries'),
  ('Swiggy Instamart', 'groceries.groceries'),
  ('Instamart', 'groceries.groceries'),
  ('BigBasket', 'groceries.groceries'),
  ('big basket', 'groceries.groceries'),
  ('JioMart', 'groceries.groceries'),
  ('DMart', 'groceries.groceries'),
  ('D-Mart', 'groceries.groceries'),
  ('Reliance Fresh', 'groceries.groceries'),
  ('More Supermarket', 'groceries.groceries'),
  ("Nature's Basket", 'groceries.groceries'),
  ('Vegetables', 'groceries.groceries'),
  ('sabzi', 'groceries.groceries'),
  ('Fruits', 'groceries.groceries'),
  ('Milk', 'groceries.groceries'),
  ('kirana', 'groceries.groceries'),
  ('Groceries for the villa', 'groceries.groceries'),
  ('Amazon Fresh', 'groceries.groceries'),
  ('Detergent and toiletries', 'groceries.household'),
  ('Vim bar', 'groceries.household'),
  // Travel.
  ('Uber', 'travel.cab_auto'),
  ('Uber to airport', 'travel.cab_auto'),
  ('Ola', 'travel.cab_auto'),
  ('Rapido', 'travel.cab_auto'),
  ('Namma Yatri', 'travel.cab_auto'),
  ('Auto', 'travel.cab_auto'),
  ('Cab to airport', 'travel.cab_auto'),
  ('Taxi', 'travel.cab_auto'),
  ('e-rickshaw', 'travel.cab_auto'),
  ('Metro', 'travel.train_bus'),
  ('Metro card recharge', 'travel.train_bus'),
  ('IRCTC', 'travel.train_bus'),
  ('Train tickets', 'travel.train_bus'),
  ('redBus', 'travel.train_bus'),
  ('Bus to Pune', 'travel.train_bus'),
  ('IndiGo', 'travel.flights'),
  ('Air India', 'travel.flights'),
  ('Akasa Air', 'travel.flights'),
  ('SpiceJet', 'travel.flights'),
  ('Flight to Goa', 'travel.flights'),
  ('MakeMyTrip', 'travel.flights'),
  ('MakeMyTrip hotel', 'travel.hotel'),
  ('Goibibo', 'travel.flights'),
  ('Cleartrip', 'travel.flights'),
  ('ixigo trains', 'travel.train_bus'),
  ('OYO', 'travel.hotel'),
  ('Airbnb', 'travel.hotel'),
  ('Hotel', 'travel.hotel'),
  ('Hostel', 'travel.hotel'),
  ('booking.com', 'travel.hotel'),
  ('Petrol', 'travel.fuel'),
  ('Diesel', 'travel.fuel'),
  ('Fuel', 'travel.fuel'),
  ('Gas station', 'travel.fuel'),
  ('FASTag', 'travel.parking_tolls'),
  ('Toll', 'travel.parking_tolls'),
  ('Toll tax', 'travel.parking_tolls'),
  ('Parking', 'travel.parking_tolls'),
  // Entertainment.
  ('BookMyShow', 'entertainment.movies'),
  ('PVR', 'entertainment.movies'),
  ('INOX', 'entertainment.movies'),
  ('Movie', 'entertainment.movies'),
  ('Netflix', 'entertainment.movies'),
  ('Prime Video', 'entertainment.movies'),
  ('Amazon Prime', 'entertainment.movies'),
  ('Hotstar', 'entertainment.movies'),
  ('JioCinema', 'entertainment.movies'),
  ('Jio Cinema', 'entertainment.movies'),
  ('Spotify', 'entertainment.events'),
  ('Concert', 'entertainment.events'),
  ('Games', 'entertainment.games'),
  ('Bowling', 'entertainment.games'),
  ('Cricket turf', 'entertainment.sports'),
  ('Gym', 'entertainment.sports'),
  // Shopping.
  ('Amazon', 'shopping.other'),
  ('Flipkart', 'shopping.other'),
  ('Myntra', 'shopping.clothing'),
  ('Ajio', 'shopping.clothing'),
  ('Nykaa', 'shopping.other'),
  ('Meesho', 'shopping.other'),
  ('Croma', 'shopping.electronics'),
  ('Decathlon', 'shopping.other'),
  ('IKEA', 'shopping.other'),
  ('Clothes', 'shopping.clothing'),
  ('Shoes', 'shopping.clothing'),
  ('T-shirt', 'shopping.clothing'),
  ('Birthday gift', 'shopping.gifts'),
  ('Flowers', 'shopping.gifts'),
  ('Reliance Digital', 'shopping.electronics'),
  // Utilities.
  ('Electricity', 'utilities.electricity'),
  ('Electricity bill', 'utilities.electricity'),
  ('BESCOM', 'utilities.electricity'),
  ('Tata Power', 'utilities.electricity'),
  ('Adani', 'utilities.electricity'),
  ('Light bill', 'utilities.electricity'),
  ('Airtel', 'utilities.internet_phone'),
  ('Jio', 'utilities.internet_phone'),
  ('Jio recharge', 'utilities.internet_phone'),
  ('Vi', 'utilities.internet_phone'),
  ('BSNL', 'utilities.internet_phone'),
  ('Recharge', 'utilities.internet_phone'),
  ('Broadband', 'utilities.internet_phone'),
  ('Wi-Fi', 'utilities.internet_phone'),
  ('WiFi bill', 'utilities.internet_phone'),
  ('ACT Fibernet', 'utilities.internet_phone'),
  ('Gas', 'utilities.gas'),
  ('Gas cylinder', 'utilities.gas'),
  ('Cylinder', 'utilities.gas'),
  ('Adani Gas', 'utilities.gas'),
  ('HP Gas', 'utilities.gas'),
  ('Water', 'utilities.water'),
  ('Water bill', 'utilities.water'),
  ('DTH', 'utilities.subscriptions'),
  ('Tata Play', 'utilities.subscriptions'),
  ('Tata Play Fiber', 'utilities.internet_phone'),
  ('Airtel DTH', 'utilities.subscriptions'),
  ('Water park', 'entertainment.events'),
  // Rent and home.
  ('Rent', 'rent.rent'),
  ('November rent', 'rent.rent'),
  ('House rent', 'rent.rent'),
  ('PG', 'rent.rent'),
  ('Security deposit', 'rent.rent'),
  ('Maintenance', 'rent.maintenance'),
  ('Society maintenance', 'rent.maintenance'),
  ('Plumber', 'rent.maintenance'),
  // Other.
  ('Apollo Pharmacy', 'other.medical'),
  ('PharmEasy', 'other.medical'),
  ('1mg', 'other.medical'),
  ('Tata 1mg', 'other.medical'),
  ('Doctor', 'other.medical'),
  ('Medicines', 'other.medical'),
  ('Health insurance', 'other.medical'),
  ('School fees', 'other.education'),
  ('Udemy course', 'other.education'),
  ('Maid salary', 'other.services'),
  ('Laundry', 'other.services'),
  ('Haircut', 'other.services'),
  ('Urban Company', 'other.services'),
  ('Insurance', 'other.services'),
  // Hindi words in Devanagari, with and without the nukta.
  ('चाय', 'food.snacks'),
  ('सब्ज़ी', 'groceries.groceries'),
  ('सब्जी', 'groceries.groceries'),
  ('किराया', 'rent.rent'),
  ('पेट्रोल', 'travel.fuel'),
  // UPI IDs and payee names from the payment bubble.
  ('swiggy@icici', 'food.takeaway'),
  ('zomato.payu@axis', 'food.takeaway'),
  ('uber.india@hdfcbank', 'travel.cab_auto'),
  ('irctc.ticketing@sbi', 'travel.train_bus'),
  ('bigbasket@ybl', 'groceries.groceries'),
  ('Paid to SWIGGY LIMITED', 'food.takeaway'),
  ('BUNDL TECHNOLOGIES swiggy@axisbank', 'food.takeaway'),
  ('netflix.upi@icici', 'entertainment.movies'),
  // Mixed: the brand beats a plain word; the longest phrase beats both; the first plain word wins a tie.
  ('Uber to dinner', 'travel.cab_auto'),
  ('Dinner and a movie', 'food.dining_out'),
  ('Movie then dinner', 'entertainment.movies'),
  ('Lunch at Starbucks', 'food.snacks'),
  ('Cab to the hotel', 'travel.cab_auto'),
  ('Goa trip - flights', 'travel.flights'),
  // Words inside other words do not count.
  ('Barbados trip', null),
  ('Autumn holiday', null),
  ('Vijay', null),
  ('Olaf', null),
  ('Teammates', null),
  ('Rental of nothing', null),
  // No match → no change.
  ('', null),
  ('   ', null),
  ('Misc', null),
  ('Paid back Rahul', null),
  ('Goa', null),
  ('Asha owes this', null),
  ('12345', null),
  ('xyz@okaxis', null),
  ('9876543210@paytm', null),
  ('Stuff', null),
  ('???', null),
  ('Holiday', null),
];

void main() {
  group('keyword file', () {
    test('has a version, stays small and uses only known categories', () {
      expect(_json['version'], isA<int>());
      expect((_json['version']! as int) >= 1, isTrue);
      // rootBundle.loadString reads files over 50 KB on another isolate: stay under it.
      expect(_file.lengthSync(), lessThan(50 * 1024));
      for (final r in (_json['rules']! as List).cast<Map<String, Object?>>()) {
        expect(ExpenseCategories.isKnown(r['category']! as String), isTrue, reason: '$r');
        expect(['brand', 'word', 'weak'], contains(r['tier']));
      }
    });

    test('every phrase normalises to something and is listed once', () {
      final seen = <String, String>{};
      for (final r in (_json['rules']! as List).cast<Map<String, Object?>>()) {
        for (final p in (r['phrases']! as List).cast<String>()) {
          final n = CategorySuggester.normalize(p);
          expect(n, isNotEmpty, reason: p);
          expect(seen[n], isNull, reason: '"$p" is also under ${seen[n]}');
          seen[n] = r['category']! as String;
        }
      }
      expect(_s.phraseCount, seen.length);
      expect(_s.phraseCount, greaterThan(800));
    });

    test('covers every category the owner listed (D-028)', () {
      final used = {
        for (final r in (_json['rules']! as List).cast<Map<String, Object?>>()) r['category'],
      };
      for (final k in [
        'food.takeaway',
        'food.dining_out',
        'food.snacks',
        'groceries.groceries',
        'groceries.household',
        'travel.cab_auto',
        'travel.train_bus',
        'travel.flights',
        'travel.hotel',
        'travel.fuel',
        'travel.parking_tolls',
        'rent.rent',
        'rent.maintenance',
        'utilities.electricity',
        'utilities.water',
        'utilities.gas',
        'utilities.internet_phone',
        'utilities.subscriptions',
        'entertainment.movies',
        'entertainment.events',
        'entertainment.games',
        'entertainment.sports',
        'shopping.clothing',
        'shopping.electronics',
        'shopping.gifts',
        'shopping.other',
        'other.medical',
        'other.education',
        'other.services',
      ]) {
        expect(used, contains(k));
      }
    });
  });

  test('has at least 120 vectors', () => expect(_vectors.length, greaterThanOrEqualTo(120)));

  for (final (text, expected) in _vectors) {
    test('"$text" → ${expected ?? 'no match'}', () {
      expect(_s.suggest(text), expected, reason: '${_s.match(text)}');
    });
  }

  group('normalize', () {
    test('lower case, accents, apostrophes and punctuation', () {
      expect(CategorySuggester.normalize("  Café  DOMINO'S!! "), 'cafe dominos');
      expect(CategorySuggester.normalize('Häagen-Dazs'), 'haagen dazs');
      expect(CategorySuggester.normalize('McDonald’s'), 'mcdonalds');
      expect(CategorySuggester.normalize('F&B / drinks'), 'f b drinks');
      expect(CategorySuggester.normalize('Straße'), 'strasse');
    });

    test('a UPI ID keeps its name part', () {
      expect(CategorySuggester.normalize('zomato.payu@axis'), 'zomato payu');
      expect(CategorySuggester.normalize('Paid swiggy@icici ₹250'), 'paid swiggy 250');
      expect(CategorySuggester.normalize('@home'), 'home');
    });

    test('Devanagari keeps its vowel signs and drops the nukta', () {
      expect(CategorySuggester.normalize('सब्ज़ी'), 'सब्जी');
      expect(CategorySuggester.tokens('चाय पानी'), ['चाय', 'पानी']);
    });
  });

  group('ranking', () {
    CategorySuggester of(List<Object?> rules) =>
        CategorySuggester.fromJson({'version': 1, 'rules': rules});

    test('longer phrase beats a higher tier', () {
      final s = of([
        {
          'category': 'food.takeaway',
          'tier': 'brand',
          'phrases': ['swiggy'],
        },
        {
          'category': 'groceries.groceries',
          'tier': 'weak',
          'phrases': ['swiggy mart'],
        },
      ]);
      expect(s.suggest('Swiggy Mart order'), 'groceries.groceries');
    });

    test('same length: brand > word > weak, then the earliest', () {
      final s = of([
        {
          'category': 'travel.flights',
          'tier': 'weak',
          'phrases': ['yatra'],
        },
        {
          'category': 'travel.hotel',
          'tier': 'word',
          'phrases': ['hotel'],
        },
        {
          'category': 'food.dining_out',
          'tier': 'word',
          'phrases': ['dinner'],
        },
        {
          'category': 'travel.cab_auto',
          'tier': 'brand',
          'phrases': ['ola'],
        },
      ]);
      expect(s.suggest('Yatra hotel'), 'travel.hotel');
      expect(s.suggest('dinner hotel'), 'food.dining_out');
      expect(s.suggest('hotel dinner'), 'travel.hotel');
      expect(s.suggest('dinner ola'), 'travel.cab_auto');
      expect(s.match('dinner ola')!.tier, KeywordTier.brand);
    });

    test('unknown categories, tiers and a repeated phrase are skipped', () {
      final s = of([
        {
          'category': 'pets.food',
          'tier': 'word',
          'phrases': ['kibble'],
        },
        {
          'category': 'food.snacks',
          'tier': 'magic',
          'phrases': ['chips'],
        },
        {
          'category': 'food.snacks',
          'tier': 'word',
          'phrases': ['tea', 'TEA', ''],
        },
        {
          'category': 'groceries.groceries',
          'tier': 'word',
          'phrases': ['tea'],
        },
        'not a rule',
      ]);
      expect(s.suggest('kibble'), isNull);
      expect(s.suggest('chips'), isNull);
      expect(s.suggest('tea'), 'food.snacks');
      expect(s.phraseCount, 1);
      expect(CategorySuggester.fromJson(const {}).suggest('tea'), isNull);
    });
  });

  group('learned picks', () {
    test('a learned phrase beats the file at the same length', () {
      expect(_s.suggest('Starbucks', learned: {'starbucks': 'food.dining_out'}), 'food.dining_out');
      expect(
        _s.suggest('Starbucks with Asha', learned: {'starbucks': 'food.dining_out'}),
        'food.dining_out',
      );
      expect(
        _s.match('Starbucks', learned: {'starbucks': 'food.dining_out'})!.tier,
        KeywordTier.learned,
      );
    });

    test('a longer file phrase still wins; unknown learned categories are ignored', () {
      expect(
        _s.suggest('Swiggy Instamart', learned: {'swiggy': 'food.snacks'}),
        'groceries.groceries',
      );
      expect(_s.suggest('Swiggy', learned: {'swiggy': 'nope.nope'}), 'food.takeaway');
      expect(_s.suggest('Maid', learned: {'': 'food.snacks'}), 'other.services');
    });

    test('learned phrases work without a keyword file', () {
      expect(CategorySuggester.empty.suggest('Ravi tiffin'), isNull);
      expect(
        CategorySuggester.empty.suggest('Ravi tiffin', learned: {'ravi tiffin': 'food.takeaway'}),
        'food.takeaway',
      );
    });
  });

  group('lessons', () {
    test('an override teaches the normalised description', () {
      expect(_s.lessons('Starbucks', 'food.dining_out'), {'starbucks': 'food.dining_out'});
      expect(_s.lessons('  Swiggy  Dinner ', 'food.dining_out'), {
        'swiggy dinner': 'food.dining_out',
      });
      expect(
        _s.lessons('Ravi tiffin', 'food.takeaway'),
        isEmpty,
        reason: 'tiffin already says takeaway',
      );
      expect(_s.lessons('Maid Sunita', 'other.services'), isEmpty);
    });

    test('nothing to learn: empty, too long, unknown, or the default without a suggestion', () {
      expect(_s.lessons('', 'food.snacks'), isEmpty);
      expect(_s.lessons('one two three four five six seven eight nine', 'food.snacks'), isEmpty);
      expect(_s.lessons('Starbucks', 'nope'), isEmpty);
      expect(_s.lessons('Misc', ExpenseCategories.defaultKey), isEmpty);
      expect(_s.lessons('Misc', 'other.services'), {'misc': 'other.services'});
      expect(_s.lessons('Dinner', ExpenseCategories.defaultKey), {'dinner': 'other.general'});
    });

    test('a lesson is used next time', () {
      final learned = _s.lessons('Gift for Asha', 'food.snacks');
      expect(learned, {'gift for asha': 'food.snacks'});
      expect(_s.suggest('Gift for Asha', learned: learned), 'food.snacks');
      expect(_s.suggest('Gift', learned: learned), 'shopping.gifts');
      expect(_s.lessons('Gift for Asha', 'food.snacks', learned: learned), isEmpty);
    });
  });
}
