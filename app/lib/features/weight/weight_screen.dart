import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';
import '../diary/diary_day_controller.dart';
import '../diary/local_day.dart';
import '../profile/profile_controller.dart';
import 'recalc_proposal_controller.dart';
import 'weight_chart.dart';
import 'weight_controller.dart';

/// Registro, gráfica y lista de pesos (US1, US2). [registeredAt] limita el selector por abajo.
class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key, this.registeredAt});

  final DateTime? registeredAt;

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kg = TextEditingController();
  DateTime? _day;
  bool _saving = false;
  bool _offline = false;
  bool _serverError = false;
  bool _futureDate = false;
  bool _serverRange = false;

  DateTime get _today => LocalDay.today(ref.read(diaryNowProvider)());

  DateTime get _first {
    final registered = widget.registeredAt;
    return registered == null
        ? DateTime(2000)
        : LocalDay.addDays(LocalDay.dateOnly(registered.toLocal()), -1);
  }

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime d) => DateFormat('d MMM y', 'es').format(d);

  Future<void> _pickDate(DateTime day) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: _first,
      lastDate: _today,
      helpText: AppLocalizations.of(context).weightDayLabel,
    );
    if (picked != null) {
      setState(() {
        _day = LocalDay.dateOnly(picked);
        _futureDate = false;
      });
    }
  }

  Future<void> _save(List<WeightEntry> entries) async {
    final day = _day ?? _today;
    if (LocalDay.isAfter(day, _today)) {
      setState(() => _futureDate = true);
      return;
    }
    setState(() {
      _serverRange = false;
      _offline = false;
      _serverError = false;
    });
    if (!_formKey.currentState!.validate()) return;
    final replaces = entries.any((e) => LocalDay.sameDay(e.measuredOn, day));
    setState(() => _saving = true);
    try {
      await ref
          .read(weightControllerProvider.notifier)
          .save(day, parseDecimal(_kg.text)!);
      if (!mounted) return;
      _kg.clear();
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(replaces ? l10n.weightReplaced : l10n.weightSaved),
        ),
      );
      await ref.read(recalcProposalControllerProvider).check(context);
    } on NetworkFailure {
      // El valor escrito se conserva (research R9).
      if (mounted) setState(() => _offline = true);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'VALIDATION_ERROR' && e.fields.contains('weight_kg')) {
          _serverRange = true;
        } else if (e.code == 'VALIDATION_ERROR') {
          _futureDate = true;
        } else {
          _serverError = true;
        }
      });
      _formKey.currentState?.validate();
    } on ApiFailure {
      if (mounted) setState(() => _serverError = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(WeightEntry entry) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _EditWeightDialog(initial: entry.weightKg),
    );
    if (value == null || !mounted) return;
    await _run(
      () => ref
          .read(weightControllerProvider.notifier)
          .edit(entry.measuredOn, value),
    );
  }

  Future<void> _delete(WeightEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.weightDeleteTitle),
        content: Text(
          '${_dateLabel(entry.measuredOn)} · ${formatWeight(entry.weightKg)} ${l10n.unitKg}',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.weightDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () =>
          ref.read(weightControllerProvider.notifier).delete(entry.measuredOn),
    );
  }

  /// Ejecuta un cambio de la lista y reevalúa la propuesta de recálculo (F1.5, F3.1).
  Future<void> _run(Future<void> Function() change) async {
    try {
      await change();
      if (mounted) {
        await ref.read(recalcProposalControllerProvider).check(context);
      }
    } on ApiFailure catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is NetworkFailure ? l10n.errOffline : l10n.errServer),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entries = ref.watch(weightControllerProvider);
    final day = _day ?? _today;
    final list = entries.valueOrNull ?? const <WeightEntry>[];
    final replaces = list.any((e) => LocalDay.sameDay(e.measuredOn, day));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.weightTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _kg,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.weightFieldLabel,
                      suffixText: l10n.unitKg,
                    ),
                    onChanged: (_) {
                      if (_serverRange) setState(() => _serverRange = false);
                    },
                    validator: (t) => _serverRange
                        ? l10n.errWeightRange
                        : switch (validateWeight(t ?? '')) {
                            null => null,
                            FieldProblem.required => l10n.errRequired,
                            FieldProblem.range => l10n.errWeightRange,
                          },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(day),
                    icon: const Icon(Icons.calendar_today),
                    label: Text('${l10n.weightDayLabel}: ${_dateLabel(day)}'),
                  ),
                  if (replaces)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(l10n.weightReplacesDay),
                    ),
                  if (_futureDate)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.errWeightFutureDate,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  if (_offline || _serverError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _offline ? l10n.entryOffline : l10n.errServer,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : () => _save(list),
                    child: Text(l10n.weightSave),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const WeightChartSection(),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                l10n.weightHistory,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (entries.isLoading && list.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (entries.hasError && list.isEmpty)
              Text(l10n.errServer)
            else if (list.isEmpty)
              Text(l10n.weightEmpty)
            else
              for (final entry in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${formatWeight(entry.weightKg)} ${l10n.unitKg}'),
                  subtitle: Text(_dateLabel(entry.measuredOn)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        tooltip: l10n.weightEditAction(
                          _dateLabel(entry.measuredOn),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(entry),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        tooltip: l10n.weightDeleteAction(
                          _dateLabel(entry.measuredOn),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(entry),
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

/// Diálogo para corregir el peso de un día. Es un widget propio para que su controlador se libere
/// con el diálogo y no mientras se anima su cierre.
class _EditWeightDialog extends StatefulWidget {
  const _EditWeightDialog({required this.initial});

  final double initial;

  @override
  State<_EditWeightDialog> createState() => _EditWeightDialogState();
}

class _EditWeightDialogState extends State<_EditWeightDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: formatWeight(widget.initial),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.weightEditTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: l10n.weightFieldLabel,
          suffixText: l10n.unitKg,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            if (validateWeight(_controller.text) != null) {
              setState(() => _error = l10n.errWeightRange);
              return;
            }
            Navigator.of(context).pop(parseDecimal(_controller.text));
          },
          child: Text(l10n.weightSave),
        ),
      ],
    );
  }
}
