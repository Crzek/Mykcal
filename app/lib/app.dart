import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api/models.dart';
import 'core/auth/auth_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/connection_error_view.dart';
import 'features/access/access_screen.dart';
import 'features/consent/consent_screen.dart';
import 'features/home/disabled_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/registration/code_screen.dart';
import 'l10n/app_localizations.dart';

class MykcalApp extends StatelessWidget {
  const MykcalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppGate(),
    );
  }
}

/// Elige la pantalla según el estado de la cuenta (contracts/ui-flows.md).
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final value = state.valueOrNull;
    if (value == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return switch (value) {
      SignedOut(:final notice, :final busy) => AccessScreen(
        notice: notice,
        busy: busy,
      ),
      NeedsRegistration() => const CodeScreen(),
      Active(:final me) => switch (me.onboarding) {
        Onboarding.consent => const ConsentScreen(),
        Onboarding.profile => const ProfileScreen(onboarding: true),
        Onboarding.done => HomeScreen(me: me),
      },
      Disabled() => const DisabledScreen(),
      ConnectionError(:final offline) => Scaffold(
        body: SafeArea(
          child: ConnectionErrorView(
            offline: offline,
            onRetry: () => ref.read(authControllerProvider.notifier).retry(),
          ),
        ),
      ),
    };
  }
}
