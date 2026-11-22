import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/auth/auth_service.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

void main() {
  testWidgets('sin sesión muestra el acceso con los dos botones y es accesible', (tester) async {
    final h = Harness();
    await h.pumpApp(tester);
    expect(find.text('Mykcal'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('accesible en tema oscuro y con el texto al 200 %', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final h = Harness();
    await h.pumpApp(tester);
    expect(tester.takeException(), isNull);
    await expectAccessible(tester);
  });

  testWidgets('«Iniciar sesión» abre el acceso y entra', (tester) async {
    final h = Harness();
    await h.pumpApp(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(h.auth.signInCalls, 1);
    expect(h.auth.lastSignInRegister, isFalse);
    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('«Crear cuenta» abre la página de registro', (tester) async {
    final h = Harness();
    await h.pumpApp(tester);
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(h.auth.lastSignInRegister, isTrue);
  });

  testWidgets('un fallo del acceso muestra el aviso', (tester) async {
    final h = Harness()..auth.signInError = const SignInFailed();
    await h.pumpApp(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo iniciar sesión. Inténtalo de nuevo.'), findsOneWidget);
    await expectAccessible(tester);
  });
}
