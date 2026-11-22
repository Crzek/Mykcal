import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../admin/invitations_screen.dart';

enum _MenuAction { invitations, signOut }

/// Inicio: saludo con el nombre visible y marcador de las siguientes features.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          PopupMenuButton<_MenuAction>(
            tooltip: l10n.menuLabel,
            onSelected: (action) {
              switch (action) {
                case _MenuAction.invitations:
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const InvitationsScreen()),
                  );
                case _MenuAction.signOut:
                  ref.read(authControllerProvider.notifier).signOut();
              }
            },
            itemBuilder: (_) => [
              if (me.isAdmin)
                PopupMenuItem(
                  value: _MenuAction.invitations,
                  child: Text(l10n.menuInvitations),
                ),
              PopupMenuItem(value: _MenuAction.signOut, child: Text(l10n.signOut)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.homeGreeting(me.displayName),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.homePlaceholder, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
