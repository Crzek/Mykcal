import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';
import 'macro_check.dart';
import 'target_controller.dart';

class _FieldDef {
  const _FieldDef(this.key, this.unit, {this.min = 0});

  final String key;
  final String unit;
  final int min;
}

const _fields = [
  _FieldDef('kcal', 'kcal', min: 1),
  _FieldDef('protein', 'g'),
  _FieldDef('carbs', 'g'),
  _FieldDef('fat', 'g'),
  _FieldDef('fiber', 'g'),
  _FieldDef('sodium', 'mg'),
  _FieldDef('potassium', 'mg'),
  _FieldDef('calcium', 'mg'),
  _FieldDef('iron', 'mg'),
  _FieldDef('magnesium', 'mg'),
  _FieldDef('vitD', 'µg'),
  _FieldDef('vitC', 'mg'),
];

/// Editar el objetivo a mano (pantalla 4 de contracts/ui-flows.md).
class TargetEditScreen extends ConsumerStatefulWidget {
  const TargetEditScreen({super.key, required this.initial});

  final TargetValues initial;

  @override
  ConsumerState<TargetEditScreen> createState() => _TargetEditScreenState();
}

class _TargetEditScreenState extends ConsumerState<TargetEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    final initial = <String, int>{
      'kcal': v.kcal,
      'protein': v.proteinG,
      'carbs': v.carbsG,
      'fat': v.fatG,
      'fiber': v.fiberG,
      'sodium': v.sodiumMg,
      'potassium': v.potassiumMg,
      'calcium': v.calciumMg,
      'iron': v.ironMg,
      'magnesium': v.magnesiumMg,
      'vitD': v.vitaminDUg,
      'vitC': v.vitaminCMg,
    };
    _c = {
      for (final f in _fields)
        f.key: TextEditingController(text: '${initial[f.key]}')
          ..addListener(_refresh),
    };
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  int? _int(String key) => int.tryParse(_c[key]!.text.trim());

  String _label(AppLocalizations l10n, String key) => switch (key) {
    'kcal' => l10n.nutrientKcal,
    'protein' => l10n.nutrientProtein,
    'carbs' => l10n.nutrientCarbs,
    'fat' => l10n.nutrientFat,
    'fiber' => l10n.nutrientFiber,
    'sodium' => l10n.nutrientSodium,
    'potassium' => l10n.nutrientPotassium,
    'calcium' => l10n.nutrientCalcium,
    'iron' => l10n.nutrientIron,
    'magnesium' => l10n.nutrientMagnesium,
    'vitD' => l10n.nutrientVitD,
    _ => l10n.nutrientVitC,
  };

  /// Aviso en vivo de macros que no cuadran con las kcal (FR-017); no bloquea guardar.
  String? _mismatch(AppLocalizations l10n) {
    final kcal = _int('kcal');
    final p = _int('protein');
    final c = _int('carbs');
    final f = _int('fat');
    if (kcal == null || p == null || c == null || f == null) return null;
    if (!macroEnergyMismatch(kcal, p, c, f)) return null;
    return l10n.macroMismatch(formatInt(macroEnergy(p, c, f)), formatInt(kcal));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(mykcalApiProvider)
          .saveTarget(
            TargetValues(
              kcal: _int('kcal')!,
              proteinG: _int('protein')!,
              carbsG: _int('carbs')!,
              fatG: _int('fat')!,
              fiberG: _int('fiber')!,
              sodiumMg: _int('sodium')!,
              potassiumMg: _int('potassium')!,
              calciumMg: _int('calcium')!,
              ironMg: _int('iron')!,
              magnesiumMg: _int('magnesium')!,
              vitaminDUg: _int('vitD')!,
              vitaminCMg: _int('vitC')!,
            ),
          );
      ref.invalidate(targetProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.targetSaved)));
      navigator.pop();
    } on NetworkFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errOffline)));
    } on ApiFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mismatch = _mismatch(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.targetEditTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              for (final f in _fields) ...[
                TextFormField(
                  controller: _c[f.key],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _label(l10n, f.key),
                    suffixText: f.unit,
                  ),
                  validator: (text) {
                    final value = int.tryParse((text ?? '').trim());
                    if (value == null || value < f.min) {
                      return f.min == 1 ? l10n.errIntMin1 : l10n.errIntMin0;
                    }
                    return null;
                  },
                ),
                if (f.key == 'kcal' && mismatch != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Theme.of(context).colorScheme.error,
                            semanticLabel: '',
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(mismatch)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(l10n.targetSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
