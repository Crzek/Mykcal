import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/features/foods/gtin.dart';

String withCheck(String body) {
  var total = 0;
  final reversed = body.split('').reversed.toList();
  for (var i = 0; i < reversed.length; i++) {
    total += int.parse(reversed[i]) * (i.isEven ? 3 : 1);
  }
  return '$body${(10 - total % 10) % 10}';
}

void main() {
  test('acepta las longitudes válidas', () {
    for (final body in [
      '1234567',
      '12345678901',
      '841000000000',
      '1234567890123',
    ]) {
      expect(isValidGtin(withCheck(body)), isTrue, reason: body);
    }
  });

  test('EAN-13 conocidos', () {
    expect(isValidGtin('4006381333931'), isTrue);
    expect(isValidGtin('5449000000996'), isTrue);
  });

  test('rechaza longitudes, letras y dígito de control erróneo', () {
    for (final code in [
      '',
      '1234567',
      '123456789',
      '12345678901234567',
      'abcdefgh',
      '4006381333932',
      '40063813339 1',
    ]) {
      expect(isValidGtin(code), isFalse, reason: code);
    }
    expect(() => normalizeGtin('4006381333932'), throwsFormatException);
  });

  test('UPC-A pasa a EAN-13 con un 0 delante', () {
    final upc = withCheck('03600029145');
    expect(upc.length, 12);
    expect(normalizeGtin(upc), '0$upc');
    expect(normalizeGtin('0$upc'), '0$upc');
  });
}
