import 'dart:typed_data';

import 'package:image/image.dart' as img;

// Simulate a washed-out strip down the left side with a soft edge. Paper in the
// strip stays bright enough to grade, but black ink approaches the marker cutoff.
Uint8List withUnevenLighting(Uint8List photo) {
  final image = img.decodeImage(photo)!;
  for (final pixel in image) {
    final strength = ((.105 - pixel.x / image.width) / .030).clamp(0.0, 1.0);
    final gray = pixel.luminance;
    final washed = 158 + gray * .34;
    final value = (gray + (washed - gray) * strength).round();
    pixel.setRgb(value, value, value);
  }
  return img.encodePng(image);
}
