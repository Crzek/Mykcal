import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../profile/profile_screen.dart';
import '../target/target_screen.dart';
import 'deactivate_dialog.dart';

/// Ajustes: perfil, objetivo y baja (pantalla 6 de contracts/ui-flows.md).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              minTileHeight: 56,
              title: Text(l10n.settingsProfile),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileScreen(onboarding: false),
                ),
              ),
            ),
            ListTile(
              minTileHeight: 56,
              title: Text(l10n.settingsTarget),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TargetScreen()),
              ),
            ),
            const Divider(height: 32),
            ListTile(
              minTileHeight: 56,
              iconColor: errorColor,
              textColor: errorColor,
              leading: const Icon(Icons.person_off_outlined),
              title: Text(l10n.settingsDeactivate),
              onTap: () => confirmDeactivation(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
