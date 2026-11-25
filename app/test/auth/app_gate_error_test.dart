import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets(
    'un fallo inesperado al arrancar no deja el spinner: ofrece reintentar',
    (tester) async {
      final h = Harness();
      await seedSession();
      h.api.onMe = () async => throw StateError('fallo inesperado');
      await h.pumpApp(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);

      h.api.onMe = () async => meActive;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('Resumen del día'), findsOneWidget);
    },
  );
}
