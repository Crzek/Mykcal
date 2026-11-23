import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('la tarjeta muestra kcal y macros y «Ver detalle» abre el objetivo', (tester) async {
    final h = Harness();
    await seedSession();
    await h.pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.text('Tu objetivo de hoy'), findsOneWidget);
    expect(find.text('2.759 kcal'), findsOneWidget);
    expect(find.textContaining('Proteína: 144 g'), findsOneWidget);
    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.text('Tu objetivo diario'), findsOneWidget);
  });

  testWidgets('un fallo muestra el error de conexión con «Reintentar»', (tester) async {
    final h = Harness();
    await seedSession();
    h.api.onTarget = () async => throw const NetworkFailure();
    await h.pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.text('Necesitas conexión a Internet.'), findsOneWidget);
    h.api.onTarget = () async => sampleTarget();
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('2.759 kcal'), findsOneWidget);
  });
}
