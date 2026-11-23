import 'package:intl/intl.dart';

final NumberFormat _intFormat = NumberFormat('#,##0', 'es');
final NumberFormat _weightFormat = NumberFormat('#,##0.0', 'es');

/// Entero con separador de miles español: `2759` → `2.759`.
String formatInt(int value) => _intFormat.format(value);

/// Peso con un decimal y coma: `78.4` → `78,4`.
String formatWeight(double value) => _weightFormat.format(value);

/// Acepta coma o punto como separador decimal; `null` si no es un número (research R17).
double? parseDecimal(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
