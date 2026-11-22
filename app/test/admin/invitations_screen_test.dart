import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

Future<Harness> pumpAdmin(WidgetTester tester) async {
  final h = Harness();
  await seedSession();
  h.api.onMe = () async => meAdmin;
  await h.pumpApp(tester);
  await tester.tap(find.byTooltip('Menú'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Invitaciones'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('muestra el código como ABCD-EFGH, las plazas y es accesible', (tester) async {
    await pumpAdmin(tester);
    expect(find.text('ABCD-2345'), findsOneWidget);
    expect(find.text('3 de 50 cuentas activas · 47 plazas libres'), findsOneWidget);
    expect(find.byTooltip('Copiar código'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('cambiar el código pide confirmación y actualiza', (tester) async {
    final h = await pumpAdmin(tester);
    var rotated = 0;
    h.api.onRotate = () async {
      rotated++;
      return status(code: 'WXYZ6789', active: 3, free: 47);
    };
    await tester.tap(find.text('Cambiar código'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cambiar el código?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(rotated, 0);
    await tester.tap(find.text('Cambiar código'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cambiar'));
    await tester.pumpAndSettle();
    expect(rotated, 1);
    expect(find.text('WXYZ-6789'), findsOneWidget);
  });

  testWidgets('sin código vigente ofrece generarlo', (tester) async {
    final h = Harness();
    await seedSession();
    h.api.onMe = () async => meAdmin;
    h.api.onInvitation = () async => status(code: null, active: 1, free: 49);
    await h.pumpApp(tester);
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invitaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay código. Genera uno para invitar a alguien.'), findsOneWidget);
    expect(find.text('Generar código'), findsOneWidget);
  });
}
