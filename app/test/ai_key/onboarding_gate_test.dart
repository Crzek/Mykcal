import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/features/ai_key/ai_key_guide_screen.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('tras el onboarding, una vez: guía con «Omitir», luego inicio', (
    tester,
  ) async {
    final h = Harness()..aiKeyStepSeen = false;
    await seedSession();
    await h.pumpApp(tester);
    expect(find.byType(AiKeyGuideScreen), findsOneWidget);
    expect(find.text('Omitir'), findsOneWidget);
    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();
    expect(find.byType(AiKeyGuideScreen), findsNothing);
    expect(find.text('Resumen del día'), findsOneWidget);
    expect(h.aiKeyStepSeen, isTrue); // no vuelve a salir
  });

  testWidgets('quien ya lo vio va directo al inicio', (tester) async {
    final h = Harness();
    await seedSession();
    await h.pumpApp(tester);
    expect(find.byType(AiKeyGuideScreen), findsNothing);
    expect(find.text('Resumen del día'), findsOneWidget);
  });
}
