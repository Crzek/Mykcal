import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/foods/food_detail_screen.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

void main() {
  testWidgets('muestra «sin dato» y el aviso cuando falta un nutriente', (
    tester,
  ) async {
    final h = Harness();
    await tallScreen(tester);
    h.api.onFood = (_) async => sampleFood();
    await h.pumpScreen(tester, const FoodDetailScreen(foodId: 'food-1'));
    expect(find.text('Por 100 g'), findsOneWidget);
    expect(find.text('sin dato'), findsOneWidget);
    expect(find.bySemanticsLabel('Vitamina D: sin dato'), findsOneWidget);
    expect(
      find.text('Los nutrientes sin dato cuentan como 0 en los totales.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Editar alimento'), findsNothing);
    await expectAccessible(tester);
  });

  testWidgets('bebida: «Por 100 ml», ración y copia antigua', (tester) async {
    final h = Harness();
    await tallScreen(tester);
    await h.pumpScreen(
      tester,
      FoodDetailScreen(
        food: sampleFood(
          kind: FoodKind.packaged,
          baseUnit: 'ml',
          servingSize: 250,
          brand: 'Marca',
          barcode: '8410000000000',
        ),
        stale: true,
      ),
    );
    expect(find.text('Por 100 ml'), findsOneWidget);
    expect(find.text('Ración del envase: 250 ml'), findsOneWidget);
    expect(find.text('Marca: Marca'), findsOneWidget);
    expect(find.text('Código: 8410000000000'), findsOneWidget);
    expect(find.text('Datos de una copia de más de 30 días.'), findsOneWidget);
  });

  testWidgets('el lápiz solo sale si es mío', (tester) async {
    final h = Harness();
    await tallScreen(tester);
    Food? edited;
    await h.pumpScreen(
      tester,
      FoodDetailScreen(
        food: sampleFood(kind: FoodKind.custom, isMine: true),
        onEdit: (f) => edited = f,
      ),
    );
    await tester.tap(find.byTooltip('Editar alimento'));
    expect(edited, isNotNull);
  });
}
