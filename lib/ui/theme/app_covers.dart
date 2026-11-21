import 'package:flutter/widgets.dart';

/// Group cover families (planning/06-design-system.md §7, D-013).
enum CoverFamily { trip, home, couple, other, direct }

/// Three seed colours per family; the cover painter mixes them.
abstract final class CoverPalettes {
  static const Map<CoverFamily, List<Color>> colors = {
    CoverFamily.trip: [Color(0xFFFF7A59), Color(0xFFFDB022), Color(0xFF6E56CF)],
    CoverFamily.home: [Color(0xFF7FB77E), Color(0xFF2A9D8F), Color(0xFFE9C46A)],
    CoverFamily.couple: [Color(0xFFF28CA8), Color(0xFFB9A7F2), Color(0xFFFFC6A5)],
    CoverFamily.other: [Color(0xFF5057EA), Color(0xFF7CC4FA), Color(0xFF9BE3C6)],
    CoverFamily.direct: [Color(0xFF3A3F4B), Color(0xFF7A8699), Color(0xFFDCE3EC)],
  };

  /// Base gradient under the blobs: a deep version of the family hue.
  static const Map<CoverFamily, List<Color>> base = {
    CoverFamily.trip: [Color(0xFF3B1F5C), Color(0xFFB4473A)],
    CoverFamily.home: [Color(0xFF1D4E47), Color(0xFF6E8F4A)],
    CoverFamily.couple: [Color(0xFF5B2A55), Color(0xFFC0708F)],
    CoverFamily.other: [Color(0xFF1E2370), Color(0xFF3F7DB8)],
    CoverFamily.direct: [Color(0xFF1C2028), Color(0xFF4A5363)],
  };

  /// Hero art behind the Groups home glass card (lavender to dusk).
  static const List<Color> heroDusk = [Color(0xFF9293CB), Color(0xFF6B5E9E), Color(0xFF2E2A4F)];
}
