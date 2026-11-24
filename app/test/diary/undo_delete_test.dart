import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/features/diary/diary_screen.dart';
import 'package:mykcal/features/diary/undo_delete.dart';

import '../helpers/fakes.dart';
import 'summary_card_test.dart' show target2000;

Future<Harness> pumpAndDelete(WidgetTester tester) async {
  await tallScreen(tester);
  final h = Harness();
  final entry = sampleEntry(id: 'e1', name: 'Pan integral', quantity: 60);
  var deleted = false;
  h.api.onDiaryDay = (_, _) async =>
      sampleDay(target: target2000, entries: deleted ? [] : [entry]);
  h.api.onDeleteEntry = (_, _) async {
    deleted = true;
    return sampleDay(target: target2000);
  };
  h.api.onRestoreEntry = (_, _) async {
    deleted = false;
    return sampleDay(target: target2000, entries: [entry]);
  };
  await h.pumpScreen(tester, const Scaffold(body: DiaryScreen()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Pan integral'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, 'Borrar'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('tras borrar: aviso de 10 s con «Deshacer» y la entrada fuera', (
    tester,
  ) async {
    await pumpAndDelete(tester);
    expect(find.text('Pan integral borrado'), findsOneWidget);
    expect(find.text('Deshacer'), findsOneWidget);
    expect(find.text('Aún no hay nada'), findsNWidgets(5));
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.duration, undoDuration);
    expect(undoDuration, const Duration(seconds: 10));
    expect(bar.persist, isFalse);
  });

  testWidgets(
    '«Deshacer» llama a restoreEntry y el diario vuelve a actualizarse',
    (tester) async {
      final h = await pumpAndDelete(tester);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(h.api.restoredEntries, ['e1']);
      expect(find.text('Pan integral'), findsOneWidget);
    },
  );

  testWidgets('pasados 10 s el aviso desaparece y no se llama a restoreEntry', (
    tester,
  ) async {
    final h = await pumpAndDelete(tester);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text('Pan integral borrado'), findsNothing);
    expect(h.api.restoredEntries, isEmpty);
  });

  testWidgets(
    'si «Deshacer» falla: «No se pudo deshacer» y el diario no cambia',
    (tester) async {
      final h = await pumpAndDelete(tester);
      h.api.onRestoreEntry = (_, _) async => throw const NetworkFailure();
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo deshacer'), findsOneWidget);
      expect(find.text('Aún no hay nada'), findsNWidgets(5));
      expect(find.text('Pan integral'), findsNothing);
    },
  );

  testWidgets('«Deshacer» con 404 también avisa', (tester) async {
    final h = await pumpAndDelete(tester);
    h.api.onRestoreEntry = (_, _) async =>
        throw const ApiError('ENTRY_NOT_FOUND', 404);
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo deshacer'), findsOneWidget);
  });
}
