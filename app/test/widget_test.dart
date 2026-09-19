import 'package:flutter_test/flutter_test.dart';
import 'package:rps_lose/referee.dart';

void main() {
  test('canned rulings fill every placeholder and cite a section', () {
    for (var i = 0; i < 300; i++) {
      final r = cannedRuling(name: 'Juan', job: 'vibecoder', player: 'rock', appeal: i.isEven);
      expect(r.text.contains('{'), isFalse, reason: r.text);
      expect(RegExp(r'^[A-Z]+ \d+[A-Z]$').hasMatch(r.section), isTrue, reason: r.section);
    }
  });
}
