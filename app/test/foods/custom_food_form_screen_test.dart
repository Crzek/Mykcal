import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/foods/custom_food_form_screen.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> fill(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label), text);
  await tester.pump();
}

Future<void> fillRequired(WidgetTester tester) async {
  await fill(tester, 'Nombre *', 'Tarta de la abuela');
  await fill(tester, 'Calorías *', '320');
  await fill(tester, 'Proteína *', '6');
  await fill(tester, 'Carbohidratos *', '45');
  await fill(tester, 'Grasa *', '13');
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('errores junto al campo y no se guarda', (tester) async {
    final h = Harness();
    await tallScreen(tester);
    await h.pumpScreen(tester, const CustomFoodFormScreen());
    await save(tester);
    expect(find.text('Obligatorio'), findsNWidgets(5));
    expect(h.api.createdFoods, isEmpty);

    await fill(tester, 'Nombre *', 'Tarta');
    await fill(tester, 'Calorías *', '100');
    await fill(tester, 'Proteína *', '50');
    await fill(tester, 'Carbohidratos *', '40');
    await fill(tester, 'Grasa *', '20');
    await save(tester);
    expect(
      find.text(
        'Proteína, carbohidratos, grasa y fibra suman más de 100 g por 100 g',
      ),
      findsWidgets,
    );
    expect(h.api.createdFoods, isEmpty);
  });

  testWidgets('el aviso de kcal sale en vivo y no bloquea', (tester) async {
    final h = Harness();
    await tallScreen(tester);
    await h.pumpScreen(tester, const CustomFoodFormScreen());
    await fill(tester, 'Nombre *', 'Raro');
    await fill(tester, 'Calorías *', '100');
    await fill(tester, 'Proteína *', '10');
    await fill(tester, 'Carbohidratos *', '10');
    await fill(tester, 'Grasa *', '10');
    expect(
      find.text('Las kcal no cuadran con los macros (calculadas: 170 kcal)'),
      findsOneWidget,
    );
    await save(tester);
    expect(h.api.createdFoods, hasLength(1));
  });

  testWidgets('«Por ración» muestra el equivalente y exige la ración', (
    tester,
  ) async {
    final h = Harness();
    await tallScreen(tester);
    await h.pumpScreen(tester, const CustomFoodFormScreen());
    await tester.tap(find.text('Por ración'));
    await tester.pump();
    await fillRequired(tester);
    await fill(tester, 'Calorías *', '480');
    await save(tester);
    expect(find.text('Indica cuántos gramos tiene la ración'), findsOneWidget);
    expect(h.api.createdFoods, isEmpty);

    await fill(tester, 'Ración *', '150');
    expect(find.text('= 320 kcal por 100 g'), findsOneWidget);
    await save(tester);
    final sent = h.api.createdFoods.single;
    expect(sent.basis, FoodBasis.perServing);
    expect(sent.servingSize, 150);
    expect(sent.values.kcal, 480);
  });

  testWidgets('con los 5 campos y por 100 g se guarda y abre el detalle', (
    tester,
  ) async {
    final h = Harness();
    await tallScreen(tester);
    h.api.onCreateCustom = (input) async => CustomFoodSaved(
      food: sampleFood(name: input.name, kind: FoodKind.custom, isMine: true),
      warnings: const [],
    );
    await h.pumpScreen(tester, const CustomFoodFormScreen());
    await fillRequired(tester);
    await save(tester);
    expect(h.api.createdFoods.single.name, 'Tarta de la abuela');
    expect(h.api.createdFoods.single.basis, FoodBasis.per100);
    expect(find.text('Tuyo'), findsOneWidget); // detalle del alimento guardado
  });

  testWidgets('FOOD_BARCODE_TAKEN sale bajo «Código»', (tester) async {
    final h = Harness();
    await tallScreen(tester);
    h.api.onCreateCustom = (_) async =>
        throw const ApiError('FOOD_BARCODE_TAKEN', 409);
    await h.pumpScreen(
      tester,
      const CustomFoodFormScreen(initialBarcode: '8410000000016'),
    );
    await fillRequired(tester);
    await save(tester);
    expect(find.text('Ya tienes un alimento con este código'), findsOneWidget);
  });

  testWidgets('sin conexión conserva lo escrito', (tester) async {
    final h = Harness();
    await tallScreen(tester);
    h.api.onCreateCustom = (_) async => throw const NetworkFailure();
    await h.pumpScreen(tester, const CustomFoodFormScreen());
    await fillRequired(tester);
    await save(tester);
    expect(find.text('Sin conexión. Inténtalo de nuevo.'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Tarta de la abuela'),
      findsOneWidget,
    );
  });

  testWidgets('precarga nombre, código y marca desde el escáner', (
    tester,
  ) async {
    final h = Harness();
    await tallScreen(tester);
    await h.pumpScreen(
      tester,
      const CustomFoodFormScreen(
        initialName: 'Galletas',
        initialBrand: 'Panadería',
        initialBarcode: '8410000000016',
      ),
    );
    expect(find.widgetWithText(TextField, 'Galletas'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Panadería'), findsOneWidget);
    expect(find.widgetWithText(TextField, '8410000000016'), findsOneWidget);
  });

  testWidgets('editar envía un PUT con el id', (tester) async {
    final h = Harness();
    await tallScreen(tester);
    final food = sampleFood(id: 'mio-1', kind: FoodKind.custom, isMine: true);
    await h.pumpScreen(tester, CustomFoodFormScreen(existing: food));
    expect(find.text('Editar alimento'), findsOneWidget);
    await fill(tester, 'Nombre *', 'Nombre nuevo');
    await save(tester);
    expect(h.api.updatedFoods['mio-1']!.name, 'Nombre nuevo');
    expect(h.api.createdFoods, isEmpty);
  });

  testWidgets('al salir con cambios pregunta si se descartan', (tester) async {
    final h = Harness();
    await tallScreen(tester);
    await h.pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CustomFoodFormScreen(),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await fill(tester, 'Nombre *', 'Algo');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo alimento'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo alimento'), findsNothing);
  });

  testWidgets('accesible y sin desbordes con el texto al 200 %', (
    tester,
  ) async {
    final h = Harness();
    await tallScreen(tester);
    await h.pumpScreen(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: const CustomFoodFormScreen(),
      ),
    );
    await tester.tap(find.text('Guardar').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectAccessible(tester);
  });
}
