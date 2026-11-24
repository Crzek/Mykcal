import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/features/diary/undo_snack.dart';

void main() {
  Future<int> pumpSnack(WidgetTester tester) async {
    var undone = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showUndoSnack(
                ScaffoldMessenger.of(context),
                message: 'Pan añadido',
                undoLabel: 'Deshacer',
                onUndo: () => undone++,
              ),
              child: const Text('mostrar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return undone;
  }

  testWidgets('dura 5 s, sin persistir, y luego desaparece', (tester) async {
    await pumpSnack(tester);
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.duration, const Duration(seconds: 5));
    expect(quickUndoDuration, const Duration(seconds: 5));
    expect(bar.persist, isFalse);
    expect(find.text('Pan añadido'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Pan añadido'), findsNothing);
    expect(find.text('Deshacer'), findsNothing);
  });

  testWidgets('«Deshacer» llama a onUndo una sola vez y cierra el aviso', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showUndoSnack(
                ScaffoldMessenger.of(context),
                message: 'Copiado',
                undoLabel: 'Deshacer',
                onUndo: () => calls++,
              ),
              child: const Text('mostrar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Copiado'), findsNothing);
  });

  testWidgets('un aviso nuevo sustituye al anterior', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showUndoSnack(
                    ScaffoldMessenger.of(context),
                    message: 'Primero',
                    undoLabel: 'Deshacer',
                    onUndo: () {},
                  ),
                  child: const Text('uno'),
                ),
                TextButton(
                  onPressed: () => showUndoSnack(
                    ScaffoldMessenger.of(context),
                    message: 'Segundo',
                    undoLabel: 'Deshacer',
                    onUndo: () {},
                  ),
                  child: const Text('dos'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('uno'));
    await tester.pump();
    await tester.tap(find.text('dos'));
    await tester.pumpAndSettle();
    expect(find.text('Primero'), findsNothing);
    expect(find.text('Segundo'), findsOneWidget);
  });
}
