import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';
import '../diary/diary_day_controller.dart';
import '../diary/local_day.dart';
import '../diary/meal_labels.dart';
import '../foods/custom_food_form_screen.dart';
import '../foods/food_search_screen.dart';
import 'draft_model.dart';
import 'drafts_controller.dart';
import 'proposed_item_tile.dart';

/// Revisión de lo que ha visto la IA: se corrigen gramos, se sustituyen alimentos y se guarda en
/// el diario (`contracts/ui-flows.md` §5). Nada se guarda hasta pulsar «Guardar».
class ProposalEditScreen extends ConsumerStatefulWidget {
  const ProposalEditScreen({super.key, required this.draft});

  final PhotoDraft draft;

  @override
  ConsumerState<ProposalEditScreen> createState() => _ProposalEditScreenState();
}

class _ProposalEditScreenState extends ConsumerState<ProposalEditScreen> {
  late final List<ProposalLine> _lines;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final items = widget.draft.proposal?.items ?? const <ProposedItem>[];
    _lines = [for (final item in items) _fromItem(item)];
    for (final line in _lines) {
      if (line.matched && line.per100 == null) _loadPer100(line);
    }
  }

  ProposalLine _fromItem(ProposedItem item) {
    final food = item.matchedFood;
    Per100? per100;
    if (food != null &&
        item.aiGrams > 0 &&
        item.kcal != null &&
        item.proteinG != null &&
        item.carbsG != null &&
        item.fatG != null) {
      final k = 100 / item.aiGrams;
      per100 = Per100(
        kcal: item.kcal! * k,
        proteinG: item.proteinG! * k,
        carbsG: item.carbsG! * k,
        fatG: item.fatG! * k,
      );
    }
    return ProposalLine(
      aiName: item.aiName,
      grams: item.aiGrams,
      foodId: food?.id,
      foodName: food?.name,
      per100: per100,
      flagged: item.flagged,
    );
  }

  /// Con 0 g la IA no dio base para calcular por 100: se pide el alimento completo.
  Future<void> _loadPer100(ProposalLine line) async {
    try {
      final food = await ref.read(mykcalApiProvider).food(line.foodId!);
      if (mounted) setState(() => line.per100 = _per100Of(food));
    } on ApiFailure {
      // Sin valores no se podrá guardar esa línea hasta cambiarla o reintentar.
    }
  }

  Per100 _per100Of(Food food) => Per100(
    kcal: food.per100.kcal,
    proteinG: food.per100.proteinG,
    carbsG: food.per100.carbsG,
    fatG: food.per100.fatG,
  );

  void _apply(ProposalLine line, Food food) {
    setState(() {
      line.foodId = food.id;
      line.foodName = food.name;
      line.per100 = _per100Of(food);
    });
  }

  Future<void> _editGrams(ProposalLine line) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _GramsDialog(initial: line.grams),
    );
    if (value != null && mounted) {
      setState(() {
        line.grams = value;
        line.flagged = false;
      });
    }
  }

  /// Abre la búsqueda en modo selección; al elegir, cierra lo abierto desde aquí y aplica.
  void _search(ProposalLine? line) {
    final navigator = Navigator.of(context);
    final home = ModalRoute.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => FoodSearchScreen(
          onSelected: (food) {
            navigator.popUntil((route) => route == home);
            _choose(line, food);
          },
        ),
      ),
    );
  }

  void _create(ProposalLine line) {
    final navigator = Navigator.of(context);
    final home = ModalRoute.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => CustomFoodFormScreen(
          initialName: line.aiName,
          onSaved: (food) {
            navigator.popUntil((route) => route == home);
            _choose(line, food);
          },
        ),
      ),
    );
  }

  void _choose(ProposalLine? line, Food food) {
    if (line != null) {
      _apply(line, food);
      return;
    }
    // Alimento que la IA no detectó: una porción o 100 g.
    final added = ProposalLine(
      aiName: food.name,
      grams: food.servingSize ?? 100,
    );
    _apply(added, food);
    setState(() => _lines.add(added));
  }

  bool get _canSave =>
      !_saving && _lines.isNotEmpty && _lines.every((l) => l.valid);

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = widget.draft;
    final date = draft.entryDate;
    final offset = LocalDay.utcOffsetMin(date);
    final api = ref.read(mykcalApiProvider);
    final day = ref.read(diaryDayControllerProvider(date).notifier);
    final name = mealName(draft.meal, l10n);
    setState(() => _saving = true);
    DiaryDay? last;
    try {
      // Las ya guardadas salen de la lista: si algo falla, reintentar no las duplica.
      for (final line in [..._lines]) {
        final added = await api.addEntry(
          date: date,
          meal: draft.meal,
          foodId: line.foodId!,
          quantity: line.grams,
          utcOffsetMin: offset,
        );
        last = added.day;
        if (mounted) setState(() => _lines.remove(line));
      }
    } on ApiFailure {
      if (last != null) day.apply(last);
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(SnackBar(content: Text(l10n.proposalSaveError)));
      }
      return;
    }
    if (last != null) day.apply(last);
    await ref
        .read(draftsControllerProvider.notifier)
        .completeManually(draft.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.proposalSaved(name))));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = mealName(widget.draft.meal, l10n);
    var kcal = 0.0, p = 0.0, c = 0.0, f = 0.0;
    for (final line in _lines) {
      final per = line.per100;
      if (!line.matched || per == null) continue;
      final k = line.grams / 100;
      kcal += per.kcal * k;
      p += per.proteinG * k;
      c += per.carbsG * k;
      f += per.fatG * k;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.proposalTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_lines.isEmpty) Text(l10n.proposalEmpty),
                  for (final line in _lines)
                    ProposedItemTile(
                      line: line,
                      onEditGrams: () => _editGrams(line),
                      onChange: () => _search(line),
                      onCreate: () => _create(line),
                      onRemove: () => setState(() => _lines.remove(line)),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(l10n.proposalAdd),
                      onPressed: () => _search(null),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.proposalTotals(
                      formatDecimal(kcal.roundToDouble()),
                      formatDecimal(p),
                      formatDecimal(c),
                      formatDecimal(f),
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: Text(l10n.proposalSave(name)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pide los gramos de una línea. Tiene su propio controlador para liberarlo cuando el diálogo
/// termina de cerrarse.
class _GramsDialog extends StatefulWidget {
  const _GramsDialog({required this.initial});

  final double initial;

  @override
  State<_GramsDialog> createState() => _GramsDialogState();
}

class _GramsDialogState extends State<_GramsDialog> {
  late final _controller = TextEditingController(
    text: formatDecimal(widget.initial),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _accept() {
    final v = parseDecimal(_controller.text);
    if (v != null && v > 0 && v <= 10000) Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.proposalGramsTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: l10n.proposalGramsField),
        onSubmitted: (_) => _accept(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _accept, child: Text(l10n.ok)),
      ],
    );
  }
}
