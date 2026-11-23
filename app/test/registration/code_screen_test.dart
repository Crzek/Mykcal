import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

Future<Harness> pumpCode(WidgetTester tester) async {
  final h = Harness();
  await seedSession();
  h.api.onMe = () async => throw const ApiError('ACCOUNT_NOT_REGISTERED', 404);
  await h.pumpApp(tester);
  return h;
}

Future<void> submit(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra el formulario y es accesible', (tester) async {
    await pumpCode(tester);
    expect(find.text('Código de invitación'), findsWidgets);
    expect(find.text('Pídeselo a Erick.'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('el botón está habilitado con el campo vacío y hay ayuda para el admin', (tester) async {
    await pumpCode(tester);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
    expect(find.text('Si eres el administrador, puedes dejarlo vacío.'), findsOneWidget);
  });

  testWidgets('INVITATION_REQUIRED: pide el código', (tester) async {
    final h = await pumpCode(tester);
    h.api.onRegister = (_) async => throw const ApiError('INVITATION_REQUIRED', 400);
    await submit(tester, '');
    expect(find.text('Escribe el código de invitación.'), findsOneWidget);
    expect(h.api.registerCodes, ['']);
  });

  testWidgets('envía el código tal cual (minúsculas y espacios los normaliza el servidor) y entra', (tester) async {
    final h = await pumpCode(tester);
    await submit(tester, '  abcd-2345 ');
    expect(h.api.registerCodes, ['  abcd-2345 ']);
    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('código no válido: mensaje claro y se queda en la pantalla (US1-2)', (tester) async {
    final h = await pumpCode(tester);
    h.api.onRegister = (_) async => throw const ApiError('INVITATION_INVALID', 400);
    await submit(tester, 'ZZZZ');
    expect(find.text('El código no es válido. Comprueba que es el último que te envió Erick.'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('sin plazas (US1-3)', (tester) async {
    final h = await pumpCode(tester);
    h.api.onRegister = (_) async => throw const ApiError('NO_SEATS', 409);
    await submit(tester, 'ABCD2345');
    expect(find.text('Ahora mismo no hay plazas libres en Mykcal.'), findsOneWidget);
  });

  testWidgets('demasiados intentos: cuenta atrás y botón desactivado (FR-013)', (tester) async {
    final h = await pumpCode(tester);
    h.api.onRegister = (_) async => throw const ApiError('TOO_MANY_ATTEMPTS', 429, retryAfterSeconds: 90);
    await submit(tester, 'ABCD2345');
    expect(find.text('Demasiados intentos. Podrás volver a probar en 1 min 30 s.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  testWidgets('sin conexión: banner y el texto se conserva (FR-015)', (tester) async {
    final h = await pumpCode(tester);
    h.api.onRegister = (_) async => throw const NetworkFailure();
    await submit(tester, 'ABCD2345');
    expect(find.text('Necesitas conexión a Internet.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'ABCD2345'), findsOneWidget);
    // Reintentar con red
    h.api.onRegister = (_) async => meActive;
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('sesión caducada: vuelve al acceso y el borrador sigue al volver', (tester) async {
    final h = await pumpCode(tester);
    h.api.onRegister = (_) async => throw const SessionExpired();
    await submit(tester, 'ABCD2345');
    expect(find.text('Tu sesión ha caducado. Inicia sesión de nuevo.'), findsOneWidget);
    // Inicia sesión de nuevo: Zitadel devuelve la sesión y la cuenta sigue sin registrar.
    h.api.onMe = () async => throw const ApiError('ACCOUNT_NOT_REGISTERED', 404);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'ABCD2345'), findsOneWidget);
  });

  testWidgets('cerrar sesión desde el formulario', (tester) async {
    await pumpCode(tester);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
