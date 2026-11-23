import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/features/consent/consent_screen.dart';
import 'package:mykcal/l10n/app_localizations_es.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

Finder accept() => find.widgetWithText(FilledButton, 'Aceptar y continuar');

Future<Harness> start(WidgetTester tester) async {
  await tallScreen(tester);
  final h = Harness();
  await seedSession();
  h.api.onMe = () async => meNeedsConsent;
  await h.pumpApp(tester);
  return h;
}

void main() {
  testWidgets('sin casilla no se avanza; salidas: cerrar sesión y darse de baja (US1.2)', (tester) async {
    await start(tester);
    expect(find.text('Tus datos de salud'), findsOneWidget);
    expect(tester.widget<FilledButton>(accept()).onPressed, isNull);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Darme de baja'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('aceptar llama con la versión vigente y lleva al perfil (US1.3)', (tester) async {
    final h = await start(tester);
    h.api.onConsent = (_) async => h.api.onMe = () async => meNeedsProfile;
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(tester.widget<FilledButton>(accept()).onPressed, isNotNull);
    await tester.tap(accept());
    await tester.pumpAndSettle();
    expect(h.api.consentVersions, [AppLocalizationsEs().consentTextVersion]);
    expect(find.text('Tu perfil'), findsWidgets);
  });

  testWidgets('sin conexión: aviso y la casilla sigue marcada', (tester) async {
    final h = await start(tester);
    h.api.onConsent = (_) async => throw const NetworkFailure();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(accept());
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión. Inténtalo de nuevo.'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isTrue);
  });

  testWidgets('versión desconocida: pide actualizar la app', (tester) async {
    final h = await start(tester);
    h.api.onConsent = (_) async => throw const ApiError('CONSENT_VERSION_MISMATCH', 409);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(accept());
    await tester.pumpAndSettle();
    expect(find.text('Actualiza la app para continuar.'), findsOneWidget);
  });

  testWidgets('«Darme de baja» abre el diálogo y al confirmar da de baja (G1)', (tester) async {
    final h = await start(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Darme de baja'));
    await tester.pumpAndSettle();
    expect(find.text('¿Darte de baja de Mykcal?'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Darme de baja'),
    ));
    await tester.pumpAndSettle();
    expect(h.api.deactivateCalls, 1);
    expect(find.text('Tu cuenta se ha dado de baja.'), findsOneWidget);
  });

  testWidgets('el texto del consentimiento definitivo no es un borrador (T073)', (tester) async {
    final text = AppLocalizationsEs().consentBody;
    expect(text.contains('BORRADOR'), isFalse);
  });

  testWidgets('pantalla de consentimiento legible con el texto al 200%', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await start(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(ConsentScreen), findsOneWidget);
  });
}
