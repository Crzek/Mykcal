import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/features/target/macro_check.dart';

void main() {
  test('macros que cuadran con las kcal no avisan', () {
    expect(macroEnergyMismatch(2759, 144, 373, 77), isFalse); // 2.761 kcal
  });

  test('justo el 5% no avisa; por encima, sí (FR-017)', () {
    expect(macroEnergyMismatch(2000, 475, 0, 0), isFalse); // 1.900 → 5,0%
    expect(macroEnergyMismatch(2000, 525, 0, 0), isFalse); // 2.100 → 5,0%
    expect(macroEnergyMismatch(2000, 474, 0, 0), isTrue); //  1.896 → 5,2%
    expect(macroEnergyMismatch(2000, 526, 0, 0), isTrue); //  2.104 → 5,2%
  });

  test('con kcal a cero no divide ni avisa', () {
    expect(macroEnergyMismatch(0, 10, 10, 10), isFalse);
  });

  test('la energía de los macros usa 4/4/9 kcal por gramo', () {
    expect(macroEnergy(144, 373, 77), 2761);
  });
}
