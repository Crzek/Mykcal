import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/format/numbers.dart';

void main() {
  test('formatInt usa punto de miles', () {
    expect(formatInt(2759), '2.759');
    expect(formatInt(144), '144');
    expect(formatInt(10000), '10.000');
  });

  test('formatWeight usa coma decimal', () {
    expect(formatWeight(78.4), '78,4');
    expect(formatWeight(80), '80,0');
  });

  test('parseDecimal acepta coma o punto', () {
    expect(parseDecimal('80,5'), 80.5);
    expect(parseDecimal('80.5'), 80.5);
    expect(parseDecimal(' 80 '), 80);
    expect(parseDecimal(''), isNull);
    expect(parseDecimal('abc'), isNull);
  });
}
