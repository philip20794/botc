import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('script complexity icon assets are present', () {
    expect(
      File('assets/ui/script_meta/storyteller_complexity.png').existsSync(),
      isTrue,
    );
    expect(
      File('assets/ui/script_meta/player_complexity.png').existsSync(),
      isTrue,
    );
  });
}
