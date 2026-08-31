import 'package:bgm_app/widgets/common/content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('adaptiveImageFit', () {
    test('keeps a regular poster filling a portrait frame', () {
      expect(
        adaptiveImageFit(sourceAspectRatio: 2 / 3, frameAspectRatio: 68 / 96),
        BoxFit.cover,
      );
    });

    test('shows a 1:2 tall resource without cropping', () {
      expect(
        adaptiveImageFit(sourceAspectRatio: 1 / 2, frameAspectRatio: 68 / 96),
        BoxFit.contain,
      );
    });

    test('shows a 2:1 wide resource without cropping', () {
      expect(
        adaptiveImageFit(sourceAspectRatio: 2, frameAspectRatio: 68 / 96),
        BoxFit.contain,
      );
    });

    testWidgets('decodes bounded network images without changing their ratio', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CoverImage(
              imageUrl: 'https://example.invalid/poster.jpg',
              width: 68,
              height: 96,
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).policy, ResizeImagePolicy.fit);
    });
  });
}
