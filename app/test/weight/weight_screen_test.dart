import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/weight/weight_screen.dart';

import '../helpers/fakes.dart';

final today = DateTime(2026, 11, 22);

WeightScreen screen() => WeightScreen(registeredAt: DateTime(2026, 11, 1));

Future<void> enterKg(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextFormField), text);
  await tester.pump();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('guardar 78,4 llama a la API con el día de hoy', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    await h.pumpScreen(tester, screen());
    await enterKg(tester, '78,4');
    await tapSave(tester);
    expect(h.api.savedWeights.single, (today, 78.4));
    expect(find.text('Peso guardado'), findsOneWidget);
    expect(h.api.recalcChecks, 1); // reevalúa la propuesta tras guardar
  });

  testWidgets('peso fuera de rango no llama a la API', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    await h.pumpScreen(tester, screen());
    for (final bad in ['25', '310', '78,44']) {
      await enterKg(tester, bad);
      await tapSave(tester);
      expect(
        find.text('Entre 30 y 300 kg, con un decimal como máximo'),
        findsOneWidget,
        reason: bad,
      );
    }
    expect(h.api.savedWeights, isEmpty);
  });

  testWidgets('el selector no ofrece fechas futuras', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    await h.pumpScreen(tester, screen());
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.lastDate, today);
    expect(picker.firstDate, DateTime(2026, 10, 31)); // alta − 1 día
  });

  testWidgets('un día con registro avisa de que lo sustituye', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    h.api.onWeightEntries = () async => [
      WeightEntry(measuredOn: today, weightKg: 78.0),
    ];
    await h.pumpScreen(tester, screen());
    expect(find.text('Sustituye el peso de ese día'), findsOneWidget);
  });

  testWidgets('editar y borrar (con confirmación) actualizan la lista', (
    tester,
  ) async {
    await tallScreen(tester);
    final h = Harness();
    var entries = [
      WeightEntry(measuredOn: today, weightKg: 78.0),
      WeightEntry(measuredOn: DateTime(2026, 11, 21), weightKg: 79.0),
    ];
    h.api.onWeightEntries = () async => entries;
    h.api.onUpdateWeight = (day, kg) async {
      entries = [
        for (final e in entries)
          if (e.measuredOn == day)
            WeightEntry(measuredOn: day, weightKg: kg)
          else
            e,
      ];
      return entries.first;
    };
    h.api.onDeleteWeight = (day) async {
      entries = entries.where((e) => e.measuredOn != day).toList();
    };
    await h.pumpScreen(tester, screen());
    expect(find.text('78,0 kg'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '77,5');
    await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(h.api.updatedWeights.single, (today, 77.5));
    expect(find.text('77,5 kg'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar este peso?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(h.api.deletedWeights.single, DateTime(2026, 11, 21));
    expect(find.text('79,0 kg'), findsNothing);
  });

  testWidgets('cancelar el borrado no llama a la API', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    h.api.onWeightEntries = () async => [
      WeightEntry(measuredOn: today, weightKg: 78.0),
    ];
    await h.pumpScreen(tester, screen());
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(h.api.deletedWeights, isEmpty);
  });

  testWidgets('con la API caída el campo conserva el valor', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    h.api.onSaveWeight = (_, _) async => throw const NetworkFailure();
    await h.pumpScreen(tester, screen());
    await enterKg(tester, '78,4');
    await tapSave(tester);
    expect(
      find.text('Sin conexión. Revisa la red y vuelve a intentarlo'),
      findsOneWidget,
    );
    expect(find.text('78,4'), findsOneWidget);
  });

  testWidgets('una fecha futura rechazada por el servidor se explica', (
    tester,
  ) async {
    await tallScreen(tester);
    final h = Harness();
    h.api.onSaveWeight = (_, _) async =>
        throw const ApiError('VALIDATION_ERROR', 400, fields: ['measured_on']);
    await h.pumpScreen(tester, screen());
    await enterKg(tester, '78,4');
    await tapSave(tester);
    expect(
      find.text('No puedes registrar un peso en una fecha futura'),
      findsOneWidget,
    );
  });

  testWidgets('los controles de cada fila tienen etiqueta semántica', (
    tester,
  ) async {
    await tallScreen(tester);
    final h = Harness();
    h.api.onWeightEntries = () async => [
      WeightEntry(measuredOn: today, weightKg: 78.0),
    ];
    await h.pumpScreen(tester, screen());
    expect(find.byTooltip('Corregir el peso del 22 nov 2026'), findsOneWidget);
    expect(find.byTooltip('Borrar el peso del 22 nov 2026'), findsOneWidget);
  });
}
