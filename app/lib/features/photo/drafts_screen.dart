import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../diary/meal_labels.dart';
import '../foods/food_search_screen.dart';
import '../diary/entry_quantity_sheet.dart';
import 'draft_model.dart';
import 'drafts_controller.dart';
import 'failure_text.dart';
import 'proposal_edit_screen.dart';

/// Borradores de fotos: causa de cada uno y qué hacer (`contracts/ui-flows.md` §6).
class DraftsScreen extends ConsumerWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final drafts = ref.watch(visibleDraftsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.draftsTitle)),
      body: SafeArea(
        child: drafts.isEmpty
            ? Center(child: Text(l10n.draftsEmpty))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final draft in drafts.reversed) _DraftTile(draft: draft),
                ],
              ),
      ),
    );
  }
}

class _DraftTile extends ConsumerWidget {
  const _DraftTile({required this.draft});

  final PhotoDraft draft;

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.draftsDiscardTitle),
        content: Text(l10n.draftsDiscardBody),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.draftsDiscard),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(draftsControllerProvider.notifier).discard(draft.id);
    }
  }

  /// Búsqueda de la 003 para la comida y el día del borrador; al añadir, el borrador sobra.
  Future<void> _manual(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final home = ModalRoute.of(context);
    final controller = ref.read(draftsControllerProvider.notifier);
    final name = mealName(draft.meal, l10n);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (searchContext) => FoodSearchScreen(
          title: l10n.diaryAddToMeal(name),
          onSelected: (food) async {
            final added = await showEntryQuantitySheet(
              searchContext,
              food: food,
              date: draft.entryDate,
              meal: draft.meal,
            );
            if (!added) return;
            navigator.popUntil((route) => route == home);
            await controller.completeManually(draft.id);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final meal = mealName(draft.meal, l10n);
    final date = DateFormat('d MMM y', 'es').format(draft.entryDate);
    final cause = draft.hasProposal
        ? l10n.draftsReady
        : failureText(l10n, draft.failureCode);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: '${l10n.draftsRowTitle(meal, date)}. $cause',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.draftsRowTitle(meal, date),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(cause),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                if (draft.hasProposal)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProposalEditScreen(draft: draft),
                      ),
                    ),
                    child: Text(l10n.draftsReview),
                  )
                else ...[
                  TextButton(
                    onPressed: () => ref
                        .read(draftsControllerProvider.notifier)
                        .retry(draft.id),
                    child: Text(l10n.draftsRetry),
                  ),
                  TextButton(
                    onPressed: () => _manual(context, ref),
                    child: Text(l10n.draftsManual),
                  ),
                ],
                TextButton(
                  onPressed: () => _discard(context, ref),
                  child: Text(l10n.draftsDiscard),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
