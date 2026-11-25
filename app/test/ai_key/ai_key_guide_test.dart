import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/ai_key/ai_key_guide_screen.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

final configured = AiKeyStatus(
  provider: 'gemini',
  configuredAt: DateTime.utc(2026, 11, 25, 10),
);

void main() {
  testWidgets('sin clave: pasos, campo oscurecido y guardar', (tester) async {
    final h = Harness();
    var done = 0;
    await h.pumpScreen(tester, AiKeyGuideScreen(onDone: () => done++));
    expect(find.textContaining('aistudio.google.com'), findsOneWidget);
    expect(find.textContaining('Copia la clave'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(find.text('Omitir'), findsNothing); // fuera de onboarding

    h.api.onAiKey = () async => configured;
    await tester.enterText(find.byType(TextField), '  AIzaClave  ');
    await tester.tap(find.text('Guardar clave'));
    await tester.pumpAndSettle();
    expect(h.api.savedAiKeys, ['AIzaClave']);
    expect(find.text('Clave configurada'), findsOneWidget); // snackbar
    expect(
      find.textContaining('Clave configurada el 25 nov 2026'),
      findsOneWidget,
    );
    expect(done, 1);
  });

  testWidgets('clave inválida: mensaje bajo el campo y no navega', (
    tester,
  ) async {
    final h = Harness();
    h.api.onSaveAiKey = (_) async =>
        throw const ApiError('AI_KEY_INVALID', 422);
    var done = 0;
    await h.pumpScreen(tester, AiKeyGuideScreen(onDone: () => done++));
    await tester.enterText(find.byType(TextField), 'mala');
    await tester.tap(find.text('Guardar clave'));
    await tester.pumpAndSettle();
    expect(find.textContaining('La clave no es válida'), findsOneWidget);
    expect(find.text('Guardar clave'), findsOneWidget);
    expect(done, 0);
  });

  testWidgets('proveedor caído: aviso de reintentar más tarde', (tester) async {
    final h = Harness();
    h.api.onSaveAiKey = (_) async =>
        throw const ApiError('AI_PROVIDER_UNAVAILABLE', 503);
    await h.pumpScreen(tester, const AiKeyGuideScreen());
    await tester.enterText(find.byType(TextField), 'k');
    await tester.tap(find.text('Guardar clave'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se ha podido comprobar'), findsOneWidget);
  });

  testWidgets('con clave: Cambiar muestra el campo para pegar otra', (
    tester,
  ) async {
    final h = Harness();
    h.api.onAiKey = () async => configured;
    await h.pumpScreen(tester, const AiKeyGuideScreen());
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Proveedor: Google Gemini'), findsOneWidget);
    await tester.tap(find.text('Cambiar clave'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Quitar pide confirmación y vuelve al estado sin clave', (
    tester,
  ) async {
    final h = Harness();
    h.api.onAiKey = () async => configured;
    await h.pumpScreen(tester, const AiKeyGuideScreen());
    await tester.tap(find.text('Quitar clave'));
    await tester.pumpAndSettle();
    expect(find.text('¿Quitar la clave de IA?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(h.api.deleteAiKeyCalls, 0);
    await tester.tap(find.text('Quitar clave'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Quitar clave').last);
    await tester.pumpAndSettle();
    expect(h.api.deleteAiKeyCalls, 1);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('en onboarding se ve «Omitir»', (tester) async {
    final h = Harness();
    var done = 0;
    await h.pumpScreen(
      tester,
      AiKeyGuideScreen(onboarding: true, onDone: () => done++),
    );
    await tester.tap(find.text('Omitir'));
    expect(done, 1);
  });

  testWidgets('accesible, con pasos etiquetados y campo con etiqueta', (
    tester,
  ) async {
    final h = Harness();
    await h.pumpScreen(tester, const AiKeyGuideScreen(onboarding: true));
    await expectAccessible(tester);
    expect(find.bySemanticsLabel(RegExp('Paso 1: Entra')), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Clave de API'), findsOneWidget);
  });

  testWidgets('con el texto al 200 % no desborda', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await h.pumpScreen(tester, const AiKeyGuideScreen(onboarding: true));
    expect(tester.takeException(), isNull);
  });
}
