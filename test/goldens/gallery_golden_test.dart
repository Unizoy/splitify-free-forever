import 'package:alchemist/alchemist.dart';
import 'package:splitify/features/debug/presentation/gallery/gallery_sections.dart';

import 'golden_support.dart';

void main() {
  // TC-B3-03 + T9: every gallery section (every component variant) in light and dark at
  // text scale 1.0 and 2.0.
  for (final section in gallerySections) {
    for (final (suffix, scale) in goldenScales) {
      goldenTest(
        'TC-B3-03 gallery ${section.id} $suffix',
        fileName: 'gallery_${section.id}_$suffix',
        textScaleFactor: scale,
        pumpBeforeTest: pumpFixedFrames,
        builder: () => lightDarkGroup((context) => section.builder(context)),
      );
    }
  }
}
