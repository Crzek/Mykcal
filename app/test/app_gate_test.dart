import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('onboarding consent → pantalla de consentimiento', (tester) async {
    final h = Harness();
    await seedSession();
    h.api.onMe = () async => meNeedsConsent;
    await h.pumpApp(tester);
    expect(find.text('Tus datos de salud'), findsOneWidget);
  });

  testWidgets('onboarding profile → pantalla de perfil', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    await seedSession();
    h.api.onMe = () async => meNeedsProfile;
    await h.pumpApp(tester);
    expect(find.text('Tu perfil'), findsOneWidget);
    expect(find.text('Calcular mi objetivo'), findsOneWidget);
  });

  testWidgets('onboarding done → inicio', (tester) async {
    final h = Harness();
    await seedSession();
    await h.pumpApp(tester);
    expect(find.text('Hola, Ana'), findsOneWidget);
  });
}
