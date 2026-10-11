import 'package:blood_on_the_clocktower/screens/rules_selection_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all five rulebooks use direct PDF download endpoints', () {
    const names = [
      'main',
      'trouble_brewing',
      'sects_and_violets',
      'bad_moon_rising',
      'traveller_and_fabled',
    ];

    for (final name in names) {
      final uri = rulePdfUriFor(name);
      expect(uri.host, 'drive.usercontent.google.com');
      expect(uri.path, '/download');
      expect(uri.queryParameters['id'], isNotEmpty);
      expect(uri.queryParameters['export'], 'download');
    }
  });

  test('unknown rulebook ids are rejected', () {
    expect(() => rulePdfUriFor('unknown'), throwsArgumentError);
  });
}
