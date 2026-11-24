import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/ui/connection_error_view.dart';
import '../../l10n/app_localizations.dart';
import 'custom_food_form_screen.dart';
import 'food_detail_screen.dart';

/// Los alimentos personalizados del usuario, por nombre. Se invalida al crear, editar o eliminar.
final customFoodsProvider = FutureProvider.autoDispose<List<FoodSummary>>(
  (ref) => ref.watch(mykcalApiProvider).customFoods(),
);

enum _Action { edit, delete }

/// Mis alimentos (pantalla 5 de contracts/ui-flows.md).
class MyFoodsScreen extends ConsumerWidget {
  const MyFoodsScreen({super.key});

  void _create(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const CustomFoodFormScreen()));

  Future<void> _edit(BuildContext context, WidgetRef ref, FoodSummary f) async {
    final food = await ref.read(mykcalApiProvider).food(f.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomFoodFormScreen(existing: food),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FoodSummary f,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.myFoodsDeleteConfirm(f.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.myFoodsDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(mykcalApiProvider).deleteCustomFood(f.id);
    } on NetworkFailure {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.foodsOffline)));
      }
      return;
    }
    ref.invalidate(customFoodsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final foods = ref.watch(customFoodsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.foodsMyFoods)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.foodCreate,
        onPressed: () => _create(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: foods.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ConnectionErrorView(
            offline: e is NetworkFailure,
            onRetry: () => ref.invalidate(customFoodsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.myFoodsEmpty, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => _create(context),
                        child: Text(l10n.foodCreate),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final f in items)
                  ListTile(
                    minTileHeight: 56,
                    title: Text(f.name),
                    subtitle: f.brand == null ? null : Text(f.brand!),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FoodDetailScreen(foodId: f.id),
                      ),
                    ),
                    onLongPress: () => _edit(context, ref, f),
                    trailing: PopupMenuButton<_Action>(
                      tooltip: l10n.myFoodsMore(f.name),
                      onSelected: (a) => switch (a) {
                        _Action.edit => _edit(context, ref, f),
                        _Action.delete => _delete(context, ref, f),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: _Action.edit,
                          child: Text(l10n.myFoodsEdit),
                        ),
                        PopupMenuItem(
                          value: _Action.delete,
                          child: Text(l10n.myFoodsDelete),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
