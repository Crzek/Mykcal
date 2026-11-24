import '../../core/api/models.dart';

/// Cálculo de una entrada en la app: misma fórmula y redondeo que el servidor
/// (`diary/summary.py`, research R10). Sirve para la vista previa; el servidor manda.
///
/// Kcal y micros se redondean a entero; proteína, carbohidratos, grasa y fibra, a 1 decimal;
/// siempre con la mitad hacia arriba. Un `null` («sin dato») se conserva.
const _epsilon = 1e-9;

double _roundHalfUp(double value, int decimals) {
  var factor = 1.0;
  for (var i = 0; i < decimals; i++) {
    factor *= 10;
  }
  // El epsilon evita que 12,25 × 10 = 122,49999… caiga por debajo de la mitad.
  return (value * factor + _epsilon).round() / factor;
}

double? _scale(double? per100, double quantity, int decimals) =>
    per100 == null ? null : _roundHalfUp(per100 * quantity / 100, decimals);

/// Valores de [quantity] g/ml de un alimento con los valores [per100] por 100.
Nutrients valuesFor(Nutrients per100, double quantity) => Nutrients(
  kcal: _scale(per100.kcal, quantity, 0)!,
  proteinG: _scale(per100.proteinG, quantity, 1)!,
  carbsG: _scale(per100.carbsG, quantity, 1)!,
  fatG: _scale(per100.fatG, quantity, 1)!,
  fiberG: _scale(per100.fiberG, quantity, 1),
  sodiumMg: _scale(per100.sodiumMg, quantity, 0),
  potassiumMg: _scale(per100.potassiumMg, quantity, 0),
  calciumMg: _scale(per100.calciumMg, quantity, 0),
  ironMg: _scale(per100.ironMg, quantity, 0),
  magnesiumMg: _scale(per100.magnesiumMg, quantity, 0),
  vitaminDUg: _scale(per100.vitaminDUg, quantity, 0),
  vitaminCMg: _scale(per100.vitaminCMg, quantity, 0),
);

/// g/ml de [servings] raciones de [servingSize] g/ml, a 1 decimal (research R6).
double quantityFromServings(double servings, double servingSize) =>
    _roundHalfUp(servings * servingSize, 1);

/// Máximos de la hoja de cantidad (research R6): el servidor acepta hasta 10.000 g/ml y 100
/// raciones; por encima de 5.000 g/ml se pide confirmación.
const maxQuantity = 10000.0;
const maxServings = 100.0;
const confirmQuantityAbove = 5000.0;
