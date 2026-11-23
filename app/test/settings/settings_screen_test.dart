import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

Future<Harness> openSettings(WidgetTester tester, {Me? me}) async {
  final h = Harness();
  await seedSession();
  if (me != null) h.api.onMe = () async => me;
  await h.pumpApp(tester);
  await tester.tap(find.byTooltip('Menú'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ajustes'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> confirmInDialog(WidgetTester tester) => tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Darme de baja'),
    ));

void main() {
  testWidgets('menú: «Ajustes» para todos', (tester) async {
    for (final me in [meActive, meAdmin]) {
      final h = Harness();
      await seedSession();
      h.api.onMe = () async => me;
      await h.pumpApp(tester);
      await tester.tap(find.byTooltip('Menú'));
      await tester.pumpAndSettle();
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Compartir Mykcal'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('lista perfil, objetivo y baja, y es accesible', (tester) async {
    await openSettings(tester);
    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Mi objetivo'), findsOneWidget);
    expect(find.text('Darse de baja'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('«Mi objetivo» abre el detalle', (tester) async {
    await openSettings(tester);
    await tester.tap(find.text('Mi objetivo'));
    await tester.pumpAndSettle();
    expect(find.text('Tu objetivo diario'), findsOneWidget);
  });

  testWidgets('el diálogo explica las consecuencias y «Cancelar» no hace nada (US4.1)', (tester) async {
    final h = await openSettings(tester);
    await tester.tap(find.text('Darse de baja'));
    await tester.pumpAndSettle();
    expect(find.text('¿Darte de baja de Mykcal?'), findsOneWidget);
    expect(find.textContaining('no podrás volver a entrar'), findsOneWidget);
    expect(find.textContaining('Tus datos se conservan'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(h.api.deactivateCalls, 0);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('confirmar da de baja, cierra la sesión y avisa en el acceso (US4.2)', (tester) async {
    final h = await openSettings(tester);
    await tester.tap(find.text('Darse de baja'));
    await tester.pumpAndSettle();
    await confirmInDialog(tester);
    await tester.pumpAndSettle();
    expect(h.api.deactivateCalls, 1);
    expect(h.auth.revokeCalls, greaterThan(0));
    expect(find.text('Tu cuenta se ha dado de baja.'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('error de red: aviso y la cuenta sigue activa', (tester) async {
    final h = await openSettings(tester);
    h.api.onDeactivate = () async => throw const NetworkFailure();
    await tester.tap(find.text('Darse de baja'));
    await tester.pumpAndSettle();
    await confirmInDialog(tester);
    await tester.pumpAndSettle();
    expect(find.text('No se pudo dar de baja la cuenta. Inténtalo de nuevo.'), findsOneWidget);
    expect(find.text('Mi perfil'), findsOneWidget); // sigue en Ajustes
    expect(h.auth.revokeCalls, 0);
  });
}
