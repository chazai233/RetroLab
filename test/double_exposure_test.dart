import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:retrolab/core/constants.dart';
import 'package:retrolab/utils/image_processor.dart';

void main() {
  test('double exposure downscales oversized sources and blends mismatched '
      'dimensions', () {
    // Used to blend at full sensor resolution; now capped like the main path.
    final first = img.Image(width: 3000, height: 2000);
    final second = img.Image(width: 1500, height: 1000);
    img.fill(first, color: img.ColorRgb8(128, 0, 0));
    img.fill(second, color: img.ColorRgb8(0, 128, 0));

    final composed =
        img.decodeImage(
          ImageProcessor.composeDoubleExposureBytes(
            img.encodeJpg(first),
            img.encodeJpg(second),
          ),
        )!;

    expect(composed.width, 2400);
    final pixel = composed.getPixel(1200, 800);
    expect(pixel.r, greaterThan(120));
    expect(pixel.g, greaterThan(120));
  });

  test('every processing stage has a label', () {
    // ProcessingScreen indexes this list by ProcessingStage.index; a mismatch
    // is a range error mid-capture.
    expect(
      RetroStrings.processingStages.length,
      ProcessingStage.values.length,
    );
  });

  test('double exposure uses screen blend across both sources', () {
    final first = img.Image(width: 1, height: 1);
    final second = img.Image(width: 1, height: 1);

    first.setPixelRgba(0, 0, 128, 0, 0, 255);
    second.setPixelRgba(0, 0, 0, 128, 0, 255);

    final bytes = ImageProcessor.composeDoubleExposureBytes(
      img.encodeJpg(first),
      img.encodeJpg(second),
    );
    final composed = img.decodeImage(bytes)!;
    final pixel = composed.getPixel(0, 0);

    expect(pixel.r, greaterThan(120));
    expect(pixel.g, greaterThan(120));
    expect(pixel.b, lessThan(20));
  });
}
