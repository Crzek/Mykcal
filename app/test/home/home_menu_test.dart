import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

void main() {
  testWidgets('usuario normal: saludo y menú sin «Invitaciones»', (
    tester,
  ) async {
    final h = Harness();
    await seedSession();
    await h.pumpApp(tester);
    expect(find.text('Resumen del día'), findsOneWidget);
    expect(find.text('Hola, Ana'), findsNothing);
    await expectAccessible(tester);
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Invitaciones'), findsNothing);
    expect(find.text('Compartir Mykcal'), findsOneWidget);
  });

  testWidgets('administrador: ve «Invitaciones» (US4-1)', (tester) async {
    final h = Harness();
    await seedSession();
    h.api.onMe = () async => meAdmin;
    await h.pumpApp(tester);
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    expect(find.text('Invitaciones'), findsOneWidget);
  });

  testWidgets('administrador: ve «Compartir Mykcal» y «Invitaciones»', (
    tester,
  ) async {
    final h = Harness();
    await seedSession();
    h.api.onMe = () async => meAdmin;
    await h.pumpApp(tester);
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    expect(find.text('Compartir Mykcal'), findsOneWidget);
    expect(find.text('Invitaciones'), findsOneWidget);
  });

  testWidgets('«Compartir Mykcal» abre la hoja con el enlace', (tester) async {
    final h = Harness();
    await seedSession();
    await h.pumpApp(tester);
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compartir Mykcal'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
  });

  testWidgets('el menú ⋮ → «Alimentos» abre la búsqueda', (tester) async {
    final h = Harness();
    await seedSession();
    await h.pumpApp(tester);
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alimentos'));
    await tester.pumpAndSettle();
    expect(find.text('Busca un alimento'), findsOneWidget);
  });

  testWidgets('el menú ⋮ → «Peso» abre la pantalla de peso', (tester) async {
    final h = Harness();
    await seedSession();
    await h.pumpApp(tester);
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Peso'));
    await tester.pumpAndSettle();
    expect(find.text('Peso de hoy'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Guardar'), findsOneWidget);
  });
}
