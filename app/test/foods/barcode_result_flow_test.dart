import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/foods/barcode_result_flow.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

const code = '8410000000016';

class Trigger extends ConsumerWidget {
  const Trigger({super.key, this.onCreate});

  final CreateFromBarcode? onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () =>
            lookupAndShowBarcode(context, ref, code, onCreate: onCreate),
        child: const Text('Consultar'),
      ),
    ),
  );
}

Future<void> run(
  WidgetTester tester,
  Harness h, {
  CreateFromBarcode? onCreate,
}) async {
  await h.pumpScreen(tester, Trigger(onCreate: onCreate));
  await tester.tap(find.text('Consultar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('found: abre el detalle y avisa si la copia es antigua', (
    tester,
  ) async {
    final h = Harness();
    h.api.onBarcode = (c) async => BarcodeLookup(
      result: BarcodeResult.found,
      code: c,
      food: sampleFood(kind: FoodKind.packaged),
      stale: true,
    );
    await tallScreen(tester);
    await run(tester, h);
    expect(find.text('Envasado · Open Food Facts'), findsOneWidget);
    expect(find.text('Datos de una copia de más de 30 días.'), findsOneWidget);
  });

  testWidgets('found propio lleva el distintivo «Tuyo»', (tester) async {
    final h = Harness();
    h.api.onBarcode = (c) async => BarcodeLookup(
      result: BarcodeResult.found,
      code: c,
      food: sampleFood(kind: FoodKind.custom, isMine: true),
    );
    await run(tester, h);
    expect(find.text('Tuyo'), findsOneWidget);
  });

  testWidgets('not_found: hoja con «Crear alimento con este código»', (
    tester,
  ) async {
    final h = Harness();
    h.api.onBarcode = (c) async =>
        BarcodeLookup(result: BarcodeResult.notFound, code: c);
    final created = <List<String?>>[];
    await run(tester, h, onCreate: (c, n, b) => created.add([c, n, b]));
    expect(find.text('No conocemos este producto.'), findsOneWidget);
    await expectAccessible(tester);
    await tester.tap(find.text('Crear alimento con este código'));
    await tester.pumpAndSettle();
    expect(created, [
      [code, null, null],
    ]);
  });

  testWidgets('incomplete: nombre y marca llegan al formulario', (
    tester,
  ) async {
    final h = Harness();
    h.api.onBarcode = (c) async => BarcodeLookup(
      result: BarcodeResult.incomplete,
      code: c,
      productName: 'Galletas',
      brand: 'Marca',
    );
    final created = <List<String?>>[];
    await run(tester, h, onCreate: (c, n, b) => created.add([c, n, b]));
    expect(
      find.text('Galletas no tiene información nutricional suficiente.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Crear alimento con este código'));
    await tester.pumpAndSettle();
    expect(created, [
      [code, 'Galletas', 'Marca'],
    ]);
  });

  testWidgets(
    '503: «Reintentar» consulta otra vez y «Crear alimento» ofrece crear',
    (tester) async {
      final h = Harness();
      var calls = 0;
      h.api.onBarcode = (c) async {
        calls++;
        if (calls == 1) throw const ServerFailure();
        return BarcodeLookup(result: BarcodeResult.notFound, code: c);
      };
      await run(tester, h, onCreate: (c, n, b) {});
      expect(
        find.text('No hemos podido consultar la base de productos.'),
        findsOneWidget,
      );
      expect(find.text('Crear alimento'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('No conocemos este producto.'), findsOneWidget);
    },
  );

  testWidgets('sin conexión: «Sin conexión…» con «Reintentar» y sin crear', (
    tester,
  ) async {
    final h = Harness();
    h.api.onBarcode = (_) async => throw const NetworkFailure();
    await run(tester, h, onCreate: (c, n, b) {});
    expect(find.text('Sin conexión. Inténtalo de nuevo.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Crear alimento'), findsNothing);
  });

  testWidgets('con el texto al 200 % no desborda', (tester) async {
    final h = Harness();
    h.api.onBarcode = (c) async =>
        BarcodeLookup(result: BarcodeResult.notFound, code: c);
    await h.pumpScreen(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Trigger(onCreate: (c, n, b) {}),
      ),
    );
    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
