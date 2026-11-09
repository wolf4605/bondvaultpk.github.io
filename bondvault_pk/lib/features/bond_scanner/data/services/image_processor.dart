import 'dart:async';
import 'dart:io';

class HsvColor {
  final double hue; // 0..360
  final double saturation; // 0..1
  final double value; // 0..1

  const HsvColor(this.hue, this.saturation, this.value);
}

class ImageProcessor {
  /// Converts RGB (0..255) to HSV color space.
  static HsvColor rgbToHsv(int r, int g, int b) {
    final double rd = r / 255.0;
    final double gd = g / 255.0;
    final double bd = b / 255.0;

    final double max = [rd, gd, bd].reduce((a, b) => a > b ? a : b);
    final double min = [rd, gd, bd].reduce((a, b) => a < b ? a : b);
    final double delta = max - min;

    double hue = 0.0;
    if (delta != 0) {
      if (max == rd) {
        hue = ((gd - bd) / delta) % 6;
      } else if (max == gd) {
        hue = ((bd - rd) / delta) + 2;
      } else {
        hue = ((rd - gd) / delta) + 4;
      }
      hue *= 60.0;
      if (hue < 0) hue += 360.0;
    }

    final double saturation = max == 0 ? 0 : delta / max;
    final double value = max;

    return HsvColor(hue, saturation, value);
  }

  /// Validates that an image file exists and is non-empty.
  static Future<bool> validateImage(File file) async {
    try {
      if (!await file.exists()) return false;
      final length = await file.length();
      return length > 1024; // > 1 KB
    } catch (_) {
      return false;
    }
  }
}
