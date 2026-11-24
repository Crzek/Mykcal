import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/features/foods/custom_food_check.dart';

CustomFoodDraft draft({
  bool perServing = false,
  Map<CustomField, String> over = const {},
}) => CustomFoodDraft(
  perServing: perServing,
  texts: {
    CustomField.name: 'Tarta',
    CustomField.kcal: '100',
    CustomField.protein: '5',
    CustomField.carbs: '10',
    CustomField.fat: '2',
    ...over,
  },
);

void main() {
  test(
    'correcto no da errores',
    () => expect(checkCustomFood(draft()), isEmpty),
  );

  test('por ración convierte a 100 y redondea', () {
    final v = per100Values(
      draft(
        perServing: true,
        over: {CustomField.serving: '150', CustomField.kcal: '480'},
      ),
    );
    expect(v[CustomField.kcal], 320);
    final third = per100Values(
      draft(
        perServing: true,
        over: {CustomField.serving: '3', CustomField.kcal: '1'},
      ),
    );
    expect(third[CustomField.kcal], 33.33);
    expect(per100Values(draft())[CustomField.fiber], isNull);
  });

  test('acepta coma decimal', () {
    expect(
      per100Values(
        draft(over: {CustomField.protein: '1,5'}),
      )[CustomField.protein],
      1.5,
    );
  });

  test('obligatorios vacíos', () {
    final e = checkCustomFood(
      draft(over: {CustomField.name: ' ', CustomField.kcal: ''}),
    );
    expect(e[CustomField.name], FieldError.required);
    expect(e[CustomField.kcal], FieldError.required);
  });

  test('negativo y no numérico', () {
    final e = checkCustomFood(
      draft(over: {CustomField.fat: '-1', CustomField.sodium: 'abc'}),
    );
    expect(e[CustomField.fat], FieldError.negative);
    expect(e[CustomField.sodium], FieldError.notNumber);
  });

  test('máximos por 100', () {
    expect(
      checkCustomFood(draft(over: {CustomField.kcal: '901'}))[CustomField.kcal],
      FieldError.tooHigh,
    );
    expect(
      checkCustomFood(
        draft(
          over: {
            CustomField.kcal: '900',
            CustomField.protein: '0',
            CustomField.carbs: '0',
            CustomField.fat: '0',
          },
        ),
      ),
      isEmpty,
    );
    expect(
      checkCustomFood(
        draft(over: {CustomField.sodium: '40001'}),
      )[CustomField.sodium],
      FieldError.tooHigh,
    );
  });

  test('P + C + G + fibra > 100 marca los cuatro campos', () {
    final e = checkCustomFood(
      draft(
        over: {
          CustomField.protein: '50',
          CustomField.carbs: '40',
          CustomField.fat: '20',
        },
      ),
    );
    for (final f in massFields) {
      expect(e[f], FieldError.massSum);
    }
    expect(
      checkCustomFood(
        draft(
          over: {
            CustomField.protein: '40',
            CustomField.carbs: '40',
            CustomField.fat: '20',
          },
        ),
      ),
      isEmpty,
    );
    final fiber = checkCustomFood(
      draft(
        over: {
          CustomField.protein: '0',
          CustomField.carbs: '60',
          CustomField.fat: '0',
          CustomField.fiber: '60',
        },
      ),
    );
    expect(fiber[CustomField.fiber], FieldError.massSum);
  });

  test('«Por ración» exige ración y la suma se comprueba tras convertir', () {
    expect(
      checkCustomFood(draft(perServing: true))[CustomField.serving],
      FieldError.servingRequired,
    );
    expect(
      checkCustomFood(
        draft(perServing: true, over: {CustomField.serving: '0'}),
      )[CustomField.serving],
      FieldError.servingRequired,
    );
    final e = checkCustomFood(
      draft(
        perServing: true,
        over: {
          CustomField.serving: '50',
          CustomField.protein: '30',
          CustomField.carbs: '30',
        },
      ),
    );
    expect(e[CustomField.carbs], FieldError.massSum);
  });

  test('nombre, marca y código', () {
    expect(
      checkCustomFood(
        draft(over: {CustomField.name: 'a' * 121}),
      )[CustomField.name],
      FieldError.nameTooLong,
    );
    expect(
      checkCustomFood(draft(over: {CustomField.name: 'a' * 120})),
      isEmpty,
    );
    expect(
      checkCustomFood(
        draft(over: {CustomField.brand: 'm' * 81}),
      )[CustomField.brand],
      FieldError.brandTooLong,
    );
    expect(
      checkCustomFood(
        draft(over: {CustomField.barcode: '8410000000017'}),
      )[CustomField.barcode],
      FieldError.barcodeInvalid,
    );
    expect(
      checkCustomFood(draft(over: {CustomField.barcode: '8410000000016'})),
      isEmpty,
    );
  });

  test('aviso de kcal en el límite del 15 %', () {
    Map<CustomField, double?> v(String kcal) => per100Values(
      draft(
        over: {
          CustomField.kcal: kcal,
          CustomField.protein: '25',
          CustomField.carbs: '0',
          CustomField.fat: '0',
        },
      ),
    );
    expect(customKcalMismatch(v('115')), isFalse);
    expect(customKcalMismatch(v('116')), isTrue);
    expect(customKcalMismatch(v('85')), isFalse);
    expect(customKcalMismatch(v('84')), isTrue);
    final zero = per100Values(
      draft(
        over: {
          CustomField.kcal: '10',
          CustomField.protein: '0',
          CustomField.carbs: '0',
          CustomField.fat: '0',
        },
      ),
    );
    expect(customKcalMismatch(zero), isTrue);
  });

  test('nombres de campo de la API', () {
    expect(CustomField.fromWire('fat_g'), CustomField.fat);
    expect(CustomField.fromWire('serving_size'), CustomField.serving);
    expect(CustomField.fromWire('zzz'), isNull);
  });
}
