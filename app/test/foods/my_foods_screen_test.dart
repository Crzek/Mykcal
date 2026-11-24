import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/foods/my_foods_screen.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

List<FoodSummary> two() => [
  sampleSummary(id: 'a', name: 'Bizcocho', kind: FoodKind.custom, isMine: true),
  sampleSummary(
    id: 'b',
    name: 'Tarta',
    kind: FoodKind.custom,
    isMine: true,
    brand: 'Casa',
  ),
];

void main() {
  testWidgets('lista vacía ofrece crear', (tester) async {
    final h = Harness();
    await h.pumpScreen(tester, const MyFoodsScreen());
    expect(find.text('Aún no has creado alimentos.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Crear alimento'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo alimento'), findsOneWidget);
  });

  testWidgets('lista los alimentos y el FAB tiene etiqueta', (tester) async {
    final h = Harness();
    h.api.onCustomFoods = () async => two();
    await h.pumpScreen(tester, const MyFoodsScreen());
    expect(find.text('Bizcocho'), findsOneWidget);
    expect(find.text('Casa'), findsOneWidget);
    expect(find.byTooltip('Crear alimento'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('eliminar pide confirmación y borra', (tester) async {
    final h = Harness();
    var items = two();
    h.api.onCustomFoods = () async => items;
    h.api.onDeleteCustom = (id) async =>
        items = items.where((f) => f.id != id).toList();
    await h.pumpScreen(tester, const MyFoodsScreen());
    await tester.tap(find.byTooltip('Más opciones de Bizcocho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(
      find.text('¿Eliminar “Bizcocho”? Las comidas ya registradas no cambian.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(h.api.deletedFoods, ['a']);
    expect(find.text('Bizcocho'), findsNothing);
    expect(find.text('Tarta'), findsOneWidget);
  });

  testWidgets('cancelar no elimina', (tester) async {
    final h = Harness();
    h.api.onCustomFoods = () async => two();
    await h.pumpScreen(tester, const MyFoodsScreen());
    await tester.tap(find.byTooltip('Más opciones de Tarta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(h.api.deletedFoods, isEmpty);
  });

  testWidgets('«Editar» abre el formulario con el alimento', (tester) async {
    final h = Harness();
    h.api.onCustomFoods = () async => two();
    h.api.onFood = (id) async => sampleFood(
      id: id,
      name: 'Bizcocho',
      kind: FoodKind.custom,
      isMine: true,
    );
    await h.pumpScreen(tester, const MyFoodsScreen());
    await tester.tap(find.byTooltip('Más opciones de Bizcocho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar alimento'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Bizcocho'), findsOneWidget);
  });

  testWidgets('sin conexión ofrece reintentar', (tester) async {
    final h = Harness();
    h.api.onCustomFoods = () async => throw const NetworkFailure();
    await h.pumpScreen(tester, const MyFoodsScreen());
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
