import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/profile/profile_controller.dart';
import 'package:mykcal/features/profile/profile_screen.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<Harness> onboarding(WidgetTester tester) async {
  await tallScreen(tester);
  final h = Harness();
  await seedSession();
  h.api.onMe = () async => meNeedsProfile;
  await h.pumpApp(tester);
  return h;
}

Future<void> fillValid(WidgetTester tester, {String weight = '80'}) async {
  await tester.enterText(field('Edad'), '30');
  await tester.tap(find.text('Hombre'));
  await tester.enterText(field('Altura'), '180');
  await tester.enterText(field('Peso'), weight);
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Moderada: 3–5 días/semana').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mantener'));
  await tester.pump();
}

void main() {
  testWidgets('errores junto al campo y no se llama a la API (US1.5)', (
    tester,
  ) async {
    final h = await onboarding(tester);
    await tester.enterText(field('Edad'), '17');
    await tester.enterText(field('Altura'), '30');
    await tester.enterText(field('Peso'), '29,9');
    await tester.tap(find.text('Calcular mi objetivo'));
    await tester.pumpAndSettle();
    expect(find.text('Entre 18 y 100 años'), findsOneWidget);
    expect(find.text('Entre 100 y 250 cm'), findsOneWidget);
    expect(
      find.text('Entre 30 y 300 kg, con un decimal como máximo'),
      findsOneWidget,
    );
    expect(
      find.text('Obligatorio'),
      findsWidgets,
    ); // sexo, actividad y objetivo
    expect(h.api.savedProfiles, isEmpty);
  });

  testWidgets('campos vacíos piden un valor', (tester) async {
    final h = await onboarding(tester);
    await tester.tap(find.text('Calcular mi objetivo'));
    await tester.pumpAndSettle();
    expect(find.text('Obligatorio'), findsNWidgets(6));
    expect(h.api.savedProfiles, isEmpty);
  });

  testWidgets(
    'el peso acepta coma y se envía con punto; el resultado muestra el objetivo',
    (tester) async {
      final h = await onboarding(tester);
      await fillValid(tester, weight: '80,5');
      await tester.tap(find.text('Calcular mi objetivo'));
      await tester.pumpAndSettle();
      final sent = h.api.savedProfiles.single;
      expect(sent.weightKg, 80.5);
      expect((sent.age, sent.sex, sent.heightCm), (30, 'male', 180));
      expect((sent.activityLevel, sent.goal), ('moderate', 'maintain'));
      expect(sent.measuredOn, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(find.text('Tu objetivo diario'), findsOneWidget);
      expect(find.text('2.759 kcal'), findsOneWidget);
      expect(find.text('Empezar'), findsOneWidget);
    },
  );

  testWidgets('«Empezar» lleva al inicio (US2.1)', (tester) async {
    final h = await onboarding(tester);
    await fillValid(tester);
    await tester.tap(find.text('Calcular mi objetivo'));
    await tester.pumpAndSettle();
    h.api.onMe = () async => meActive;
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.text('Resumen del día'), findsOneWidget);
  });

  testWidgets('sin conexión: aviso y los valores siguen en pantalla', (
    tester,
  ) async {
    final h = await onboarding(tester);
    h.api.onSaveProfile = (_) async => throw const NetworkFailure();
    await fillValid(tester);
    await tester.tap(find.text('Calcular mi objetivo'));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión. Inténtalo de nuevo.'), findsOneWidget);
    expect(tester.widget<TextFormField>(field('Edad')).controller!.text, '30');
    expect(
      tester.widget<TextFormField>(field('Altura')).controller!.text,
      '180',
    );
  });

  testWidgets('VALIDATION_ERROR con campos marca esos campos', (tester) async {
    final h = await onboarding(tester);
    h.api.onSaveProfile = (_) async =>
        throw const ApiError('VALIDATION_ERROR', 400, fields: ['height_cm']);
    await fillValid(tester);
    await tester.tap(find.text('Calcular mi objetivo'));
    await tester.pumpAndSettle();
    expect(find.text('Entre 100 y 250 cm'), findsOneWidget);
    expect(find.text('Entre 18 y 100 años'), findsNothing);
  });

  testWidgets('el borrador sobrevive a una reconstrucción de la pantalla', (
    tester,
  ) async {
    await onboarding(tester);
    await tester.enterText(field('Edad'), '33');
    await tester.enterText(field('Peso'), '77,5');
    await tester.tap(find.text('Mujer'));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfileScreen)),
    );
    final draft = container.read(profileDraftProvider);
    expect((draft.age, draft.weight, draft.sex), ('33', '77,5', 'female'));
  });

  testWidgets('accesible y sin desbordes con el texto al 200%', (tester) async {
    await onboarding(tester);
    await expectAccessible(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('edición desde Ajustes', () {
    Future<Harness> openEdit(WidgetTester tester) async {
      await tallScreen(tester);
      final h = Harness();
      await seedSession();
      await h.pumpApp(tester);
      await tester.tap(find.byTooltip('Menú'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi perfil'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('se rellena con el perfil guardado', (tester) async {
      await openEdit(tester);
      expect(
        tester.widget<TextFormField>(field('Edad')).controller!.text,
        '30',
      );
      expect(
        tester.widget<TextFormField>(field('Peso')).controller!.text,
        '80,0',
      );
      expect(find.text('Guardar'), findsOneWidget);
    });

    testWidgets('sin cambios: «Perfil guardado» y vuelve atrás', (
      tester,
    ) async {
      final h = await openEdit(tester);
      h.api.onSaveProfile = (_) async =>
          savedProfile(status: RecalculationStatus.none);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Perfil guardado'), findsOneWidget);
      expect(find.text('Mi perfil'), findsOneWidget); // de vuelta en Ajustes
    });

    testWidgets('recálculo automático: diálogo con antes y ahora (US2.4)', (
      tester,
    ) async {
      final h = await openEdit(tester);
      h.api.onSaveProfile = (_) async => savedProfile(
        status: RecalculationStatus.applied,
        previous: sampleValues,
        target: sampleTarget(values: losingValues),
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Tu objetivo se ha actualizado'), findsOneWidget);
      expect(
        find.textContaining('2.759 kcal · P 144 g · C 373 g · G 77 g'),
        findsOneWidget,
      );
      expect(
        find.textContaining('2.207 kcal · P 176 g · C 238 g · G 61 g'),
        findsOneWidget,
      );
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(find.text('Mi perfil'), findsOneWidget);
    });

    testWidgets('objetivo manual: «Mantener el mío» no recalcula (US3.2)', (
      tester,
    ) async {
      final h = await openEdit(tester);
      h.api.onSaveProfile = (_) async => savedProfile(
        status: RecalculationStatus.proposed,
        proposed: losingValues,
        target: sampleTarget(manual: true),
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Tu objetivo está editado a mano'), findsOneWidget);
      await tester.tap(find.text('Mantener el mío'));
      await tester.pumpAndSettle();
      expect(h.api.recalculateCalls, 0);
    });

    testWidgets('objetivo manual: «Recalcular» pide el recálculo', (
      tester,
    ) async {
      final h = await openEdit(tester);
      h.api.onSaveProfile = (_) async => savedProfile(
        status: RecalculationStatus.proposed,
        proposed: losingValues,
        target: sampleTarget(manual: true),
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recalcular'));
      await tester.pumpAndSettle();
      expect(h.api.recalculateCalls, 1);
    });
  });
}
