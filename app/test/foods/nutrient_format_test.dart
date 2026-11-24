import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/foods/nutrient_format.dart';
import 'package:mykcal/l10n/app_localizations_es.dart';

import '../helpers/fakes.dart';

void main() {
  final l10n = AppLocalizationsEs();

  test('un null se muestra «sin dato» y un 0 explícito se muestra «0»', () {
    expect(formatNutrient(null, 'g', noData: 'sin dato'), 'sin dato');
    expect(formatNutrient(0, 'g', noData: 'sin dato'), '0 g');
  });

  test('decimales con coma y sin ceros sobrantes', () {
    expect(formatNutrient(1.1, 'g', noData: 'x'), '1,1 g');
    expect(formatNutrient(90, 'kcal', noData: 'x'), '90 kcal');
    expect(formatNutrient(0.25, 'mg', noData: 'x'), '0,25 mg');
  });

  test('filas de macros y micros, con la vitamina D sin dato', () {
    final food = sampleFood();
    final macros = macroRows(food.per100, l10n);
    expect(macros.map((r) => r.label), [
      'Calorías',
      'Proteína',
      'Carbohidratos',
      'Grasa',
      'Fibra',
    ]);
    final micros = microRows(food.per100, l10n);
    expect(micros, hasLength(7));
    final vitD = micros.firstWhere((r) => r.label == 'Vitamina D');
    expect(vitD.unit, 'µg');
    expect(vitD.text(l10n), 'sin dato');
    expect(vitD.semantics(l10n), 'Vitamina D: sin dato');
    expect(micros.first.semantics(l10n), 'Sodio: 1 mg');
  });

  test('hasMissing detecta fibra o micros sin dato', () {
    expect(sampleFood().per100.hasMissing, isTrue);
    const full = Nutrients(
      kcal: 1,
      proteinG: 1,
      carbsG: 1,
      fatG: 1,
      fiberG: 0,
      sodiumMg: 0,
      potassiumMg: 0,
      calciumMg: 0,
      ironMg: 0,
      magnesiumMg: 0,
      vitaminDUg: 0,
      vitaminCMg: 0,
    );
    expect(full.hasMissing, isFalse);
  });

  test('«Por 100 g» o «Por 100 ml» según la unidad base', () {
    expect(perBaseLabel('g', l10n), 'Por 100 g');
    expect(perBaseLabel('ml', l10n), 'Por 100 ml');
  });
}
