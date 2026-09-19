import 'package:flutter_test/flutter_test.dart';
import 'package:rps_lose/rps_game.dart';

void main() {
  test('canned rulings fill every placeholder and cite a section', () {
    for (var i = 0; i < 300; i++) {
      final (section, text) = rpsCannedRuling(name: 'Juan', job: 'vibecoder', move: 'rock', appeal: i.isEven);
      expect(text.contains('{'), isFalse, reason: text);
      expect(RegExp(r'^[A-Z]+ \d+[A-Z]$').hasMatch(section), isTrue, reason: section);
    }
  });
}
