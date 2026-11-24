import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';
import '../quick/favorite_star.dart';
import 'diary_day_controller.dart';
import 'entry_math.dart';
import 'local_day.dart';
import 'meal_labels.dart';
import 'undo_delete.dart';

/// Hoja «Cantidad» para añadir un alimento a una comida (contracts/ui-flows.md §2).
///
/// Devuelve `true` si la entrada se añadió; el día de la respuesta ya se ha aplicado.
Future<bool> showEntryQuantitySheet(
  BuildContext context, {
  required Food food,
  required DateTime date,
  required Meal meal,
  double? initialQuantity,
  double? initialServings,
}) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => EntryQuantitySheet(
      food: food,
      date: date,
      meal: meal,
      initialQuantity: initialQuantity,
      initialServings: initialServings,
    ),
  );
  return added ?? false;
}

/// La misma hoja para editar o borrar una entrada (§3 y §4). Tras borrar ofrece «Deshacer».
Future<void> showEditEntrySheet(
  BuildContext context,
  WidgetRef ref, {
  required DiaryEntry entry,
  required DateTime date,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final deleted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => EntryQuantitySheet(entry: entry, date: date),
  );
  if (deleted ?? false) {
    showUndoDelete(messenger, l10n, ref, entry: entry, date: date);
  }
}

/// Modo añadir (con [food]) o modo editar (con [entry]).
class EntryQuantitySheet extends ConsumerStatefulWidget {
  const EntryQuantitySheet({
    super.key,
    required this.date,
    this.food,
    this.entry,
    this.meal,
    this.initialQuantity,
    this.initialServings,
  }) : assert((food == null) != (entry == null)),
       assert(food == null || meal != null);

  final Food? food;
  final DiaryEntry? entry;
  final DateTime date;
  final Meal? meal;

  /// Cantidad inicial al añadir (la sugerida de Recientes o Favoritos): raciones si hay
  /// [initialServings] y el alimento tiene ración; si no, g/ml.
  final double? initialQuantity;
  final double? initialServings;

  @override
  ConsumerState<EntryQuantitySheet> createState() => _EntryQuantitySheetState();
}

enum _Problem { none, invalid, max }

class _EntryQuantitySheetState extends ConsumerState<EntryQuantitySheet> {
  final _text = TextEditingController();
  late final String _name = widget.food?.name ?? widget.entry!.foodName;
  late final String _baseUnit = widget.food?.baseUnit ?? widget.entry!.baseUnit;
  late final double? _servingSize =
      widget.food?.servingSize ?? widget.entry?.servingSize;

  /// En modo editar, los valores son los de la copia de la entrada, no los del alimento actual
  /// (FR-004).
  late final Nutrients _per100 = widget.food?.per100 ?? widget.entry!.per100;
  late bool _servings;
  late Meal _meal = widget.meal ?? widget.entry!.meal;
  late final String _initialText;
  late final bool _initialServings;
  bool _saving = false;
  bool _offline = false;
  bool _serverError = false;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      _servings = entry.servings != null;
      _text.text = formatDecimal(_servings ? entry.servings! : entry.quantity);
    } else {
      final servings = widget.initialServings;
      final quantity = widget.initialQuantity;
      if (servings != null && _servingSize != null) {
        _servings = true;
        _text.text = formatDecimal(servings);
      } else if (quantity != null) {
        _servings = false;
        _text.text = formatDecimal(quantity);
      } else {
        _servings = _servingSize != null;
        if (_servings) _text.text = '1';
      }
    }
    _initialText = _text.text;
    _initialServings = _servings;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  double? get _value => parseDecimal(_text.text);

  /// g/ml equivalentes a lo escrito, o `null` si no hay un valor válido.
  double? get _grams {
    final v = _value;
    if (v == null || v <= 0) return null;
    return _servings ? quantityFromServings(v, _servingSize!) : v;
  }

  _Problem get _problem {
    final v = _value;
    if (v == null || v <= 0) return _Problem.invalid;
    final grams = _grams!;
    if (grams <= 0) return _Problem.invalid;
    if (_servings && v > maxServings) return _Problem.max;
    if (grams > maxQuantity) return _Problem.max;
    return _Problem.none;
  }

  bool get _quantityChanged =>
      _servings != _initialServings || _text.text != _initialText;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _offline = false;
      _serverError = false;
    });
    try {
      await action();
    } on NetworkFailure {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _offline = true;
      });
    } on ApiFailure {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = true;
      });
    }
  }

  void _apply(DiaryDay day) =>
      ref.read(diaryDayControllerProvider(widget.date).notifier).apply(day);

  int get _offset => LocalDay.utcOffsetMin(widget.date);

  Future<void> _submit() async {
    final grams = _grams!;
    if (grams > confirmQuantityAbove) {
      final ok = await _confirm(grams);
      if (ok != true || !mounted) return;
    }
    await _run(() async {
      final api = ref.read(mykcalApiProvider);
      final entry = widget.entry;
      final DiaryDay day;
      if (entry == null) {
        day = (await api.addEntry(
          date: widget.date,
          meal: _meal,
          foodId: widget.food!.id,
          quantity: _servings ? null : _value,
          servings: _servings ? _value : null,
          utcOffsetMin: _offset,
        )).day;
      } else {
        final moved = _meal != entry.meal;
        if (!moved && !_quantityChanged) {
          if (mounted) Navigator.of(context).pop(false);
          return;
        }
        day = await api.updateEntry(
          entry.id,
          meal: moved ? _meal : null,
          quantity: _quantityChanged && !_servings ? _value : null,
          servings: _quantityChanged && _servings ? _value : null,
          utcOffsetMin: _offset,
        );
      }
      _apply(day);
      // Añadir devuelve «añadido»; editar devuelve «borrado», que aquí es siempre falso.
      if (mounted) Navigator.of(context).pop(!_editing);
    });
  }

  Future<void> _delete() => _run(() async {
    final day = await ref
        .read(mykcalApiProvider)
        .deleteEntry(widget.entry!.id, _offset);
    _apply(day);
    if (mounted) Navigator.of(context).pop(true);
  });

  Future<bool?> _confirm(double grams) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.entryConfirmTitle(formatDecimal(grams), _baseUnit)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.entryChange),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.entryConfirmAdd),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final problem = _problem;
    final grams = _grams;
    final servingSize = _servingSize;
    final unit = _servings ? l10n.entryUnitServings : _baseUnit;
    final errorText = _text.text.isEmpty || problem == _Problem.invalid
        ? l10n.entryQuantityInvalid
        : problem == _Problem.max
        ? l10n.entryQuantityMax
        : null;
    final preview = problem == _Problem.none
        ? valuesFor(_per100, grams!)
        : null;
    final canSubmit = problem == _Problem.none && !_saving;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(_name, style: theme.textTheme.titleMedium),
                  ),
                ),
                if (_editing)
                  FavoriteStar(foodId: widget.entry!.foodId, foodName: _name),
              ],
            ),
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<Meal>(
                  initialValue: _meal,
                  decoration: InputDecoration(labelText: l10n.entryMealLabel),
                  items: [
                    for (final m in Meal.values)
                      DropdownMenuItem(
                        value: m,
                        child: Text(mealName(m, l10n)),
                      ),
                  ],
                  onChanged: (m) => setState(() => _meal = m ?? _meal),
                ),
              )
            else
              Text(mealName(_meal, l10n)),
            const SizedBox(height: 16),
            if (servingSize != null) ...[
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.entryUnitServings),
                  ),
                  ButtonSegment(value: false, label: Text(_baseUnit)),
                ],
                selected: {_servings},
                onSelectionChanged: (s) => setState(() {
                  _servings = s.first;
                  _text.text = _servings ? '1' : formatDecimal(servingSize);
                }),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _text,
              autofocus: !_servings && !_editing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {
                _offline = false;
                _serverError = false;
              }),
              decoration: InputDecoration(
                labelText: l10n.entryQuantityLabel,
                suffixText: unit,
                errorText: errorText,
              ),
            ),
            if (servingSize != null && _servings) ...[
              const SizedBox(height: 4),
              Text(
                l10n.entryServingEquals(formatDecimal(servingSize), _baseUnit),
              ),
            ],
            const SizedBox(height: 12),
            if (preview != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.entryPreview(
                    formatDecimal(preview.kcal),
                    formatDecimal(preview.proteinG),
                    formatDecimal(preview.carbsG),
                    formatDecimal(preview.fatG),
                  ),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            if (_offline || _serverError) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _offline ? l10n.entryOffline : l10n.errServer,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              TextButton(
                onPressed: canSubmit ? _submit : null,
                child: Text(l10n.retry),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: canSubmit ? _submit : null,
              child: Text(_editing ? l10n.entrySave : l10n.entryAdd),
            ),
            if (_editing) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _saving ? null : _delete,
                child: Text(l10n.entryDelete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
