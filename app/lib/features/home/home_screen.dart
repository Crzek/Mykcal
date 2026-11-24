import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../admin/invitations_screen.dart';
import '../diary/diary_screen.dart';
import '../foods/food_search_screen.dart';
import '../settings/settings_screen.dart';
import '../share/share_app_sheet.dart';

enum _MenuAction { foods, invitations, shareApp, settings, signOut }

/// Inicio: el diario del día (FR-012). El menú ⋮ da acceso a Alimentos, ajustes y cuenta.
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
                case _MenuAction.foods:
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FoodSearchScreen(),
                    ),
                  );
                case _MenuAction.invitations:
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const InvitationsScreen(),
                    ),
                  );
                case _MenuAction.shareApp:
                  showShareAppSheet(context);
                case _MenuAction.settings:
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                case _MenuAction.signOut:
                  ref.read(authControllerProvider.notifier).signOut();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _MenuAction.foods,
                child: Text(l10n.homeFoods),
              ),
              if (me.isAdmin)
                PopupMenuItem(
                  value: _MenuAction.invitations,
                  child: Text(l10n.menuInvitations),
                ),
              PopupMenuItem(
                value: _MenuAction.shareApp,
                child: Text(l10n.menuShareApp),
              ),
              PopupMenuItem(
                value: _MenuAction.settings,
                child: Text(l10n.menuSettings),
              ),
              PopupMenuItem(
                value: _MenuAction.signOut,
                child: Text(l10n.signOut),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(child: DiaryScreen(registeredAt: me.registeredAt)),
    );
  }
}
