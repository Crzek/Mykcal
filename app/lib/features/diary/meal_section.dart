import 'package:flutter/material.dart';

import '../../core/api/models.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';
import 'meal_labels.dart';

/// Una comida del día: cabecera con su total, entradas y botón «+» (FR-001, FR-009).
class MealSection extends StatelessWidget {
  const MealSection({
    super.key,
    required this.meal,
    this.onAdd,
    this.onCopy,
    this.onTapEntry,
    this.onPhoto,
    this.aiKeyConfigured = false,
    this.analysisChip,
  });

  final DiaryMeal meal;
  final VoidCallback? onAdd;

  /// «Copiar de otro día» del menú ⋮ (005); sin él no hay menú.
  final VoidCallback? onCopy;
  final ValueChanged<DiaryEntry>? onTapEntry;

  /// «Registrar con foto» (006); sin él no hay icono. Sin clave de IA se ve atenuado y el toque
  /// lleva a la guía de la clave (FR-016).
  final VoidCallback? onPhoto;
  final bool aiKeyConfigured;

  /// Estado del análisis de foto de esta comida (006), bajo la cabecera.
  final Widget? analysisChip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = mealName(meal.meal, l10n);
    final kcal = l10n.diaryEntryKcal(formatDecimal(meal.totals.consumed.kcal));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    label: l10n.diaryMealTotal(
                      name,
                      formatDecimal(meal.totals.consumed.kcal),
                    ),
                    excludeSemantics: true,
                    child: Text(name, style: theme.textTheme.titleMedium),
                  ),
                ),
                Text(kcal, style: theme.textTheme.titleSmall),
                if (onPhoto != null)
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: aiKeyConfigured
                        ? l10n.photoTooltip(name)
                        : l10n.photoNeedsKeyTooltip(name),
                    icon: Icon(
                      Icons.photo_camera_outlined,
                      color: aiKeyConfigured
                          ? null
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onPhoto,
                  ),
                IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  tooltip: l10n.diaryAddToMeal(name),
                  icon: const Icon(Icons.add),
                  onPressed: onAdd,
                ),
                if (onCopy != null)
                  PopupMenuButton<void>(
                    tooltip: l10n.copyMenuTooltip(name),
                    constraints: const BoxConstraints(minWidth: 48),
                    itemBuilder: (_) => [
                      PopupMenuItem<void>(
                        onTap: onCopy,
                        child: Text(l10n.copyMenu),
                      ),
                    ],
                  ),
              ],
            ),
            ?analysisChip,
            if (meal.entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Text(
                  l10n.diaryEmptyMeal,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final entry in meal.entries)
                _EntryTile(
                  entry: entry,
                  onTap: onTapEntry == null ? null : () => onTapEntry!(entry),
                ),
          ],
        ),
      ),
    );
  }
}

String entryAmount(DiaryEntry entry, AppLocalizations l10n) {
  final quantity = formatDecimal(entry.quantity);
  final servings = entry.servings;
  if (servings == null) {
    return l10n.diaryEntryQuantity(quantity, entry.baseUnit);
  }
  return l10n.diaryEntryServings(
    formatDecimal(servings),
    servings == 1 ? l10n.diaryServingOne : l10n.diaryServingMany,
    quantity,
    entry.baseUnit,
  );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, this.onTap});

  final DiaryEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.foodName, style: theme.textTheme.bodyLarge),
                    if (entry.foodBrand != null)
                      Text(entry.foodBrand!, style: muted),
                    Text(entryAmount(entry, l10n), style: muted),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  l10n.diaryEntryKcal(formatDecimal(entry.values.kcal)),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
