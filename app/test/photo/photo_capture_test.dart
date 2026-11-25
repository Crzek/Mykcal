import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/photo/photo_capture_screen.dart';
import 'package:mykcal/features/photo/photo_picker.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

Future<void> open(WidgetTester tester, Harness h) async {
  await tallScreen(tester);
  await h.pumpScreen(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PhotoCaptureScreen(
                  date: DateTime(2026, 11, 25),
                  meal: Meal.lunch,
                ),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('abre la cámara y «Analizar» vuelve al diario sin esperar', (
    tester,
  ) async {
    final h = Harness();
    final never = Completer<PhotoAnalysisResult>();
    h.api.onAnalyzePhoto = (_) => never.future; // la respuesta no llega nunca
    await open(tester, h);
    expect(h.picker.sources, [PhotoSource.camera]);
    await tester.enterText(
      find.widgetWithText(TextField, 'Descripción'),
      'arroz con pollo',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Gramos totales del plato'),
      '350',
    );
    await tester.tap(find.text('Analizar'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoCaptureScreen), findsNothing); // ya está de vuelta
    expect(find.text('abrir'), findsOneWidget);
    final call = h.api.analyzeCalls.single;
    expect(call.description, 'arroz con pollo');
    expect(call.totalGrams, 350);
    expect(call.meal, Meal.lunch);
    expect(call.photoPath, photoPath);
  });

  testWidgets('sin permiso de cámara: mensaje y galería', (tester) async {
    final h = Harness();
    h.picker.denyCamera = true;
    await open(tester, h);
    expect(
      find.text('La cámara es necesaria para analizar la foto de tu plato.'),
      findsOneWidget,
    );
    expect(find.text('Analizar'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull, // sin foto no se puede enviar
    );
    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();
    expect(h.picker.sources.last, PhotoSource.gallery);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('accesible', (tester) async {
    final h = Harness();
    await open(tester, h);
    await expectAccessible(tester);
  });
}
