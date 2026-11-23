import 'package:flutter_test/flutter_test.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

void main() {
  testWidgets('usuario normal: saludo y menú sin «Invitaciones»', (tester) async {
    final h = Harness();
    await seedSession();
    await h.pumpApp(tester);
    expect(find.text('Hola, Ana'), findsOneWidget);
    await expectAccessible(tester);
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Invitaciones'), findsNothing);
  });

  testWidgets('administrador: ve «Invitaciones» (US4-1)', (tester) async {
    final h = Harness();
    await seedSession();
    h.api.onMe = () async => meAdmin;
    await h.pumpApp(tester);
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    expect(find.text('Invitaciones'), findsOneWidget);
  });
}
