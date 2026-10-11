import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roleImageAssetPath', () {
    test('keeps PNG as the default for extensionless legacy role data', () {
      expect(
        roleImageAssetPath('Icon_farmer'),
        'assets/images/characters/Icon_farmer.png',
      );
    });

    test('resolves extensionless WebP role data centrally', () {
      expect(
        roleImageAssetPath('Icon_bigwig'),
        'assets/images/characters/Icon_bigwig.webp',
      );
    });

    test('preserves explicit supported image extensions', () {
      expect(
        roleImageAssetPath('Icon_bigwig.webp'),
        'assets/images/characters/Icon_bigwig.webp',
      );
      expect(
        roleImageAssetPath('Icon_farmer.png'),
        'assets/images/characters/Icon_farmer.png',
      );
    });

    test('uses the token background for a missing image name', () {
      expect(
        roleImageAssetPath(''),
        'assets/images/backgrounds/token.png',
      );
    });
  });
}
