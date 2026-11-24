/// Validación y normalización de códigos GTIN. Mismo algoritmo que
/// `backend/src/mykcal/foods/gtin.py` (research R9).
library;

const validGtinLengths = <int>[8, 12, 13, 14];

bool isValidGtin(String code) {
  if (!validGtinLengths.contains(code.length)) return false;
  var total = 0;
  final digits = <int>[];
  for (final unit in code.codeUnits) {
    if (unit < 0x30 || unit > 0x39) return false;
    digits.add(unit - 0x30);
  }
  final check = digits.last;
  final body = digits.sublist(0, digits.length - 1).reversed.toList();
  for (var i = 0; i < body.length; i++) {
    total += body[i] * (i.isEven ? 3 : 1);
  }
  return (10 - total % 10) % 10 == check;
}

/// Clave canónica: un UPC-A de 12 dígitos pasa a EAN-13 con un 0 delante.
/// Lanza [FormatException] si el código no es válido.
String normalizeGtin(String code) {
  final trimmed = code.trim();
  if (!isValidGtin(trimmed)) {
    throw const FormatException('código de barras no válido');
  }
  return trimmed.length == 12 ? '0$trimmed' : trimmed;
}
