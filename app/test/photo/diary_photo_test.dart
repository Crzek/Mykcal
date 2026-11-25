import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/ai_key/ai_key_guide_screen.dart';
import 'package:mykcal/features/diary/diary_screen.dart';
import 'package:mykcal/features/diary/meal_section.dart';
import 'package:mykcal/features/foods/food_search_screen.dart';
import 'package:mykcal/features/photo/photo_capture_screen.dart';

import '../diary/summary_card_test.dart' show target2000;
import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

final configured = AiKeyStatus(
  provider: 'gemini',
  configuredAt: DateTime.utc(2026, 11, 25),
);

Future<Harness> pumpDiary(WidgetTester tester, {bool withKey = true}) async {
  await tallScreen(tester);
  final h = Harness();
  h.api.onDiaryDay = (date, _) async => sampleDay(target: target2000);
  h.api.onAiKey = () async => withKey ? configured : null;
  h.api.onSearchFoods = (_) async => [sampleSummary(name: 'Pan integral')];
  await h.pumpScreen(tester, const Scaffold(body: DiaryScreen()));
  await tester.pumpAndSettle();
  return h;
}

Future<void> sendPhoto(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Registrar con foto en Cena'));
  await tester.pumpAndSettle();
  expect(find.byType(PhotoCaptureScreen), findsOneWidget);
  await tester.tap(find.text('Analizar'));
  // Con el análisis en vuelo el chip tiene un indicador que no para: sin pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('con clave: cámara activa que abre la captura', (tester) async {
    await pumpDiary(tester);
    expect(find.byTooltip('Registrar con foto en Cena'), findsOneWidget);
    await tester.tap(find.byTooltip('Registrar con foto en Cena'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoCaptureScreen), findsOneWidget);
  });

  testWidgets('sin clave: cámara atenuada con el motivo y lleva a la guía', (
    tester,
  ) async {
    await pumpDiary(tester, withKey: false);
    final tooltip = 'Registrar con foto en Cena: necesitas una clave de IA';
    expect(find.byTooltip(tooltip), findsOneWidget);
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    expect(find.byType(AiKeyGuideScreen), findsOneWidget);
    expect(find.byType(PhotoCaptureScreen), findsNothing);
  });

  testWidgets('sin clave el resto de añadir funciona igual (FR-016)', (
    tester,
  ) async {
    final h = await pumpDiary(tester, withKey: false);
    await tester.tap(find.byTooltip('Añadir a Cena'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pan');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Pan integral'), findsOneWidget);
    expect(h.api.searchQueries, isNotEmpty);
  });

  testWidgets('analizando → listo: chip y aviso; no bloquea el diario', (
    tester,
  ) async {
    final h = await pumpDiary(tester);
    final gate = Completer<PhotoAnalysisResult>();
    h.api.onAnalyzePhoto = (_) => gate.future;
    await sendPhoto(tester);
    expect(find.text('Analizando…'), findsOneWidget);
    // Mientras tanto se puede seguir registrando por búsqueda.
    await tester.tap(find.byTooltip('Añadir a Desayuno'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byType(FoodSearchScreen),
      findsOneWidget,
    ); // se abre sin esperar al análisis
    await tester.tap(find.byType(BackButton));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    gate.complete(sampleProposal());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Análisis listo ✓'), findsOneWidget);
    expect(find.text('Foto analizada — toca para revisar'), findsWidgets);
  });

  testWidgets(
    'fallo: chip «fallido», causa en el aviso y borrador en el diario',
    (tester) async {
      final h = await pumpDiary(tester);
      h.api.onAnalyzePhoto = (_) async =>
          throw const ApiError('AI_TIMEOUT', 504);
      await sendPhoto(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Análisis fallido ✕'), findsOneWidget);
      expect(
        find.text('El análisis ha tardado demasiado. Puedes reintentar.'),
        findsOneWidget,
      );
      expect(find.text('Borradores de fotos: 1'), findsOneWidget);
    },
  );

  testWidgets('la cámara y el chip son accesibles', (tester) async {
    await pumpDiary(tester);
    await expectAccessible(tester);
    expect(find.byType(MealSection), findsNWidgets(5));
  });
}
