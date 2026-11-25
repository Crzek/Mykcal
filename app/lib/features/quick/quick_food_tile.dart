import 'package:flutter/material.dart';

import '../../core/api/models.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';
import '../diary/entry_math.dart';
import 'favorite_star.dart';

/// Cantidad sugerida como texto: «2 raciones · 60 g» o «60 g».
String quickAmount(QuickFood item, AppLocalizations l10n) {
  final quantity = formatDecimal(item.suggestedQuantity);
  final servings = item.suggestedServings;
  final base = item.food.baseUnit;
  if (servings == null) return l10n.diaryEntryQuantity(quantity, base);
  return l10n.diaryEntryServings(
    formatDecimal(servings),
    servings == 1 ? l10n.diaryServingOne : l10n.diaryServingMany,
    quantity,
    base,
  );
}

/// Cantidad sugerida para el lector de pantalla: «2 raciones, 60 g» o «60 g».
String quickAmountSpoken(QuickFood item, AppLocalizations l10n) {
  final servings = item.suggestedServings;
  if (servings == null) {
    return l10n.diaryEntryQuantity(
      formatDecimal(item.suggestedQuantity),
      item.food.baseUnit,
    );
  }
  return l10n.quickAmountServings(
    formatDecimal(servings),
    servings == 1 ? l10n.diaryServingOne : l10n.diaryServingMany,
    formatDecimal(item.suggestedQuantity),
    item.food.baseUnit,
  );
}

/// Fila de Recientes o Favoritos: nombre, cantidad sugerida, estrella y «+» (FR-002, FR-003).
///
/// Tocar la fila abre la hoja de cantidad ([onOpen]); «+» añade con la cantidad sugerida
/// ([onAdd]) y mientras tarda no admite otro toque.
class QuickFoodTile extends StatefulWidget {
  const QuickFoodTile({
    super.key,
    required this.item,
    required this.onAdd,
    required this.onOpen,
    this.onFavoriteChanged,
  });

  final QuickFood item;
  final Future<void> Function(QuickFood item) onAdd;
  final void Function(QuickFood item) onOpen;
  final ValueChanged<bool>? onFavoriteChanged;

  @override
  State<QuickFoodTile> createState() => _QuickFoodTileState();
}

class _QuickFoodTileState extends State<QuickFoodTile> {
  bool _busy = false;

  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onAdd(widget.item);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    final food = item.food;
    final kcal = formatDecimal(
      valuesFor(food.per100, item.suggestedQuantity).kcal,
    );
    final detail = l10n.quickRowDetail(quickAmount(item, l10n), kcal);
    return ListTile(
      minTileHeight: 56,
      title: Text(food.name),
      subtitle: Text(food.brand == null ? detail : '${food.brand!}\n$detail'),
      isThreeLine: food.brand != null,
      onTap: () => widget.onOpen(item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FavoriteStar(
            foodId: food.id,
            foodName: food.name,
            onChanged: widget.onFavoriteChanged,
          ),
          _busy
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  tooltip: l10n.quickAddLabel(
                    food.name,
                    quickAmountSpoken(item, l10n),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _add,
                ),
        ],
      ),
    );
  }
}
