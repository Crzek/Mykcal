import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/diary/entry_math.dart';

void main() {
  test('S2: 150 g de un alimento de 200 kcal/100 g son 300 kcal', () {
    const per100 = Nutrients(kcal: 200, proteinG: 10, carbsG: 20, fatG: 5);
    final v = valuesFor(per100, 150);
    expect(v.kcal, 300);
    expect(v.proteinG, 15);
    expect(v.carbsG, 30);
    expect(v.fatG, 7.5);
  });

  test('S3: 60 g de 389 kcal y 13,2 g de proteína', () {
    const per100 = Nutrients(kcal: 389, proteinG: 13.2, carbsG: 0, fatG: 0);
    final v = valuesFor(per100, 60);
    expect(v.kcal, 233); // 233,4
    expect(v.proteinG, 7.9); // 7,92
  });

  test('S8: 12,25 g de proteína por 100 g → 12,3 (mitad hacia arriba)', () {
    const per100 = Nutrients(kcal: 0, proteinG: 12.25, carbsG: 0, fatG: 0);
    expect(valuesFor(per100, 100).proteinG, 12.3);
  });

  test('kcal y micros a entero; macros y fibra a un decimal', () {
    const per100 = Nutrients(
      kcal: 10.5,
      proteinG: 3.46,
      carbsG: 0,
      fatG: 0,
      fiberG: 3.46,
      sodiumMg: 10.5,
      ironMg: 10.5,
    );
    final v = valuesFor(per100, 33); // 3,465
    expect(v.kcal, 3);
    expect(v.sodiumMg, 3);
    expect(v.ironMg, 3);
    expect(valuesFor(per100, 100).proteinG, 3.5);
    expect(valuesFor(per100, 100).fiberG, 3.5);
  });

  test('un null («sin dato») se conserva y un 0 explícito no', () {
    const per100 = Nutrients(
      kcal: 100,
      proteinG: 1,
      carbsG: 1,
      fatG: 1,
      fiberG: 0,
    );
    final v = valuesFor(per100, 50);
    expect(v.fiberG, 0);
    expect(v.sodiumMg, isNull);
    expect(v.vitaminCMg, isNull);
  });

  test('Q1: 1,5 raciones de 33,3 g son 50,0 g', () {
    expect(quantityFromServings(1.5, 33.3), 50.0);
    expect(quantityFromServings(2, 30), 60.0);
    expect(quantityFromServings(0.25, 30), 7.5);
  });

  test('límites de la hoja', () {
    expect(maxQuantity, 10000);
    expect(maxServings, 100);
    expect(confirmQuantityAbove, 5000);
  });
}
