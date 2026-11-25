import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../admin/invitations_screen.dart';
import '../diary/diary_screen.dart';
import '../foods/food_search_screen.dart';
import '../settings/settings_screen.dart';
import '../weight/recalc_proposal_controller.dart';
import '../weight/weight_screen.dart';
import '../share/share_app_sheet.dart';

enum _MenuAction { foods, weight, invitations, shareApp, settings, signOut }

/// Inicio: el diario del día (FR-012). El menú ⋮ da acceso a Alimentos, ajustes y cuenta.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.me});

  final Me me;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Me get me => widget.me;

  @override
  void initState() {
    super.initState();
    // Al abrir la app se consulta la propuesta de recálculo del objetivo (007, F3.1).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(recalcProposalControllerProvider).check(context);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                case _MenuAction.weight:
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          WeightScreen(registeredAt: me.registeredAt),
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
              PopupMenuItem(
                value: _MenuAction.weight,
                child: Text(l10n.menuWeight),
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
