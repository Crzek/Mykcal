import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';
import 'custom_food_check.dart';
import 'food_detail_screen.dart';
import 'my_foods_screen.dart';

/// Crear o editar un alimento personalizado (pantalla 4 de contracts/ui-flows.md).
///
/// Con [existing] edita ese alimento; si no, crea uno nuevo precargando lo que se sepa
/// ([initialName], [initialBarcode], [initialBrand]). Al guardar sustituye esta pantalla por el
/// detalle del alimento guardado.
class CustomFoodFormScreen extends ConsumerStatefulWidget {
  const CustomFoodFormScreen({
    super.key,
    this.existing,
    this.initialName,
    this.initialBarcode,
    this.initialBrand,
  });

  final Food? existing;
  final String? initialName;
  final String? initialBarcode;
  final String? initialBrand;

  @override
  ConsumerState<CustomFoodFormScreen> createState() =>
      _CustomFoodFormScreenState();
}

class _CustomFoodFormScreenState extends ConsumerState<CustomFoodFormScreen> {
  final _controllers = <CustomField, TextEditingController>{};
  late final Map<CustomField, String> _initial;
  late String _baseUnit;
  bool _perServing = false;
  bool _saving = false;
  bool _submitted = false;
  Map<CustomField, FieldError> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    _baseUnit = f?.baseUnit ?? 'g';
    final n = f?.per100;
    String? fmt(double? v) =>
        v == null ? null : formatDecimal(v).replaceAll('.', '');
    final texts = <CustomField, String?>{
      CustomField.name: f?.name ?? widget.initialName,
      CustomField.brand: f?.brand ?? widget.initialBrand,
      CustomField.barcode: f?.barcode ?? widget.initialBarcode,
      CustomField.serving: fmt(f?.servingSize),
      CustomField.kcal: fmt(n?.kcal),
      CustomField.protein: fmt(n?.proteinG),
      CustomField.carbs: fmt(n?.carbsG),
      CustomField.fat: fmt(n?.fatG),
      CustomField.fiber: fmt(n?.fiberG),
      CustomField.sodium: fmt(n?.sodiumMg),
      CustomField.potassium: fmt(n?.potassiumMg),
      CustomField.calcium: fmt(n?.calciumMg),
      CustomField.iron: fmt(n?.ironMg),
      CustomField.magnesium: fmt(n?.magnesiumMg),
      CustomField.vitaminD: fmt(n?.vitaminDUg),
      CustomField.vitaminC: fmt(n?.vitaminCMg),
    };
    _initial = {for (final e in texts.entries) e.key: e.value ?? ''};
    for (final field in CustomField.values) {
      _controllers[field] = TextEditingController(text: _initial[field]);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  CustomFoodDraft get _draft => CustomFoodDraft(
    perServing: _perServing,
    texts: {for (final e in _controllers.entries) e.key: e.value.text},
  );

  bool get _dirty =>
      _perServing ||
      _baseUnit != (widget.existing?.baseUnit ?? 'g') ||
      _controllers.entries.any((e) => e.value.text != _initial[e.key]);

  Map<CustomField, FieldError> get _errors => {
    if (_submitted) ...checkCustomFood(_draft),
    ..._serverErrors,
  };

  void _changed(CustomField field) => setState(() {
    _serverErrors = Map.of(_serverErrors)..remove(field);
  });

  String _message(AppLocalizations l10n, CustomField field, FieldError e) {
    final unit = _unitOf(field);
    return switch (e) {
      FieldError.required => l10n.errRequired,
      FieldError.notNumber => l10n.errNotNumber,
      FieldError.negative => l10n.errNegative,
      FieldError.tooHigh => l10n.errTooHigh(
        formatDecimal(maxPer100[field]!),
        unit,
        _baseUnit,
      ),
      FieldError.massSum => l10n.errMassSum(_baseUnit),
      FieldError.servingRequired => l10n.errServingRequired(
        (_baseUnit == 'ml' ? l10n.unitMl : l10n.unitGrams).toLowerCase(),
      ),
      FieldError.barcodeInvalid =>
        _serverBarcodeTaken.contains(field)
            ? l10n.errBarcodeTaken
            : l10n.errBarcodeInvalid,
      FieldError.nameTooLong => l10n.errNameTooLong,
      FieldError.brandTooLong => l10n.errBrandTooLong,
      FieldError.invalid => l10n.errInvalidValue,
    };
  }

  // El servidor devuelve 409 con el código repetido; se muestra bajo «Código».
  final Set<CustomField> _serverBarcodeTaken = {};

  String _unitOf(CustomField f) => switch (f) {
    CustomField.kcal => 'kcal',
    CustomField.sodium ||
    CustomField.potassium ||
    CustomField.calcium ||
    CustomField.iron ||
    CustomField.magnesium ||
    CustomField.vitaminC => 'mg',
    CustomField.vitaminD => 'µg',
    _ => 'g',
  };

  String _labelOf(AppLocalizations l10n, CustomField f) => switch (f) {
    CustomField.kcal => l10n.nutrientKcal,
    CustomField.protein => l10n.nutrientProtein,
    CustomField.carbs => l10n.nutrientCarbs,
    CustomField.fat => l10n.nutrientFat,
    CustomField.fiber => l10n.nutrientFiber,
    CustomField.sodium => l10n.nutrientSodium,
    CustomField.potassium => l10n.nutrientPotassium,
    CustomField.calcium => l10n.nutrientCalcium,
    CustomField.iron => l10n.nutrientIron,
    CustomField.magnesium => l10n.nutrientMagnesium,
    CustomField.vitaminD => l10n.nutrientVitD,
    CustomField.vitaminC => l10n.nutrientVitC,
    _ => '',
  };

  CustomFoodInput _input() {
    final d = _draft;
    double? n(CustomField f) => d.number(f);
    String? text(CustomField f) {
      final t = d.text(f);
      return t.isEmpty ? null : t;
    }

    return CustomFoodInput(
      name: d.text(CustomField.name),
      brand: text(CustomField.brand),
      barcode: text(CustomField.barcode),
      baseUnit: _baseUnit,
      basis: _perServing ? FoodBasis.perServing : FoodBasis.per100,
      servingSize: n(CustomField.serving),
      values: Nutrients(
        kcal: n(CustomField.kcal)!,
        proteinG: n(CustomField.protein)!,
        carbsG: n(CustomField.carbs)!,
        fatG: n(CustomField.fat)!,
        fiberG: n(CustomField.fiber),
        sodiumMg: n(CustomField.sodium),
        potassiumMg: n(CustomField.potassium),
        calciumMg: n(CustomField.calcium),
        ironMg: n(CustomField.iron),
        magnesiumMg: n(CustomField.magnesium),
        vitaminDUg: n(CustomField.vitaminD),
        vitaminCMg: n(CustomField.vitaminC),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _serverErrors = {};
      _serverBarcodeTaken.clear();
    });
    if (checkCustomFood(_draft).isNotEmpty) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final api = ref.read(mykcalApiProvider);
      final id = widget.existing?.id;
      final saved = id == null
          ? await api.createCustomFood(_input())
          : await api.updateCustomFood(id, _input());
      ref.invalidate(customFoodsProvider);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => FoodDetailScreen(food: saved.food),
        ),
      );
    } on NetworkFailure {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.foodsOffline)));
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e.code == 'FOOD_BARCODE_TAKEN') {
          _serverErrors = {CustomField.barcode: FieldError.barcodeInvalid};
          _serverBarcodeTaken.add(CustomField.barcode);
        } else if (e.code == 'VALIDATION_ERROR') {
          _serverErrors = {
            for (final name in e.fields)
              if (CustomField.fromWire(name) != null)
                CustomField.fromWire(name)!: FieldError.invalid,
          };
        }
      });
    } on ApiFailure {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.errServer)));
    }
  }

  Future<void> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.discardConfirm),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) Navigator.of(context).pop();
  }

  Widget _field(
    AppLocalizations l10n,
    CustomField field, {
    required String label,
    bool numeric = true,
    bool required = false,
    String? suffix,
    TextInputType? keyboard,
    int? maxLength,
  }) {
    final errors = _errors;
    final error = errors[field];
    final per100 = per100Values(_draft)[field];
    final raw = _draft.number(field);
    final showEquivalent =
        _perServing && field.isNutrient && raw != null && per100 != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controllers[field],
            onChanged: (_) => _changed(field),
            keyboardType:
                keyboard ??
                (numeric
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text),
            inputFormatters: numeric && field != CustomField.barcode
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
                : field == CustomField.barcode
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            maxLength: maxLength,
            decoration: InputDecoration(
              labelText: required ? '$label *' : label,
              suffixText: suffix,
              errorText: error == null ? null : _message(l10n, field, error),
              errorMaxLines: 3,
              counterText: '',
            ),
          ),
          if (showEquivalent)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                l10n.equivalentPer100(
                  formatDecimal(per100),
                  _unitOf(field),
                  _baseUnit,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.existing != null;
    final per100 = per100Values(_draft);
    final mismatch = customKcalMismatch(per100);
    final calc = calculatedKcal(per100);
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(editing ? l10n.foodEdit : l10n.formNewTitle),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(l10n.formSave),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(
                l10n,
                CustomField.name,
                label: l10n.fieldName,
                numeric: false,
                required: true,
              ),
              _field(
                l10n,
                CustomField.brand,
                label: l10n.fieldBrand,
                numeric: false,
              ),
              _field(
                l10n,
                CustomField.barcode,
                label: l10n.fieldBarcode,
                keyboard: TextInputType.number,
                maxLength: 14,
              ),
              _unitSelector(l10n),
              _basisSelector(l10n),
              _field(
                l10n,
                CustomField.serving,
                label: l10n.fieldServing,
                suffix: _baseUnit,
                required: _perServing,
              ),
              for (final f in const [
                CustomField.kcal,
                CustomField.protein,
                CustomField.carbs,
                CustomField.fat,
              ])
                _field(
                  l10n,
                  f,
                  label: _labelOf(l10n, f),
                  suffix: _unitOf(f),
                  required: true,
                ),
              ExpansionTile(
                title: Text(l10n.formMicrosExpand),
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: _optionalHasValues,
                children: [
                  for (final f in const [
                    CustomField.fiber,
                    CustomField.sodium,
                    CustomField.potassium,
                    CustomField.calcium,
                    CustomField.iron,
                    CustomField.magnesium,
                    CustomField.vitaminD,
                    CustomField.vitaminC,
                  ])
                    _field(
                      l10n,
                      f,
                      label: _labelOf(l10n, f),
                      suffix: _unitOf(f),
                    ),
                ],
              ),
              if (mismatch && calc != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_outlined,
                          semanticLabel: '',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.kcalMismatchWarning(formatDecimal(calc)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.formSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _optionalHasValues => const [
    CustomField.fiber,
    CustomField.sodium,
    CustomField.potassium,
    CustomField.calcium,
    CustomField.iron,
    CustomField.magnesium,
    CustomField.vitaminD,
    CustomField.vitaminC,
  ].any((f) => (_initial[f] ?? '').isNotEmpty);

  Widget _unitSelector(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.fieldUnit, style: Theme.of(context).textTheme.labelLarge),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'g', label: Text(l10n.unitGrams)),
            ButtonSegment(value: 'ml', label: Text(l10n.unitMl)),
          ],
          selected: {_baseUnit},
          onSelectionChanged: (s) => setState(() => _baseUnit = s.first),
        ),
      ],
    ),
  );

  Widget _basisSelector(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.fieldBasis, style: Theme.of(context).textTheme.labelLarge),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(
                _baseUnit == 'ml' ? l10n.basisPer100ml : l10n.basisPer100g,
              ),
            ),
            ButtonSegment(value: true, label: Text(l10n.basisPerServing)),
          ],
          selected: {_perServing},
          onSelectionChanged: (s) => setState(() => _perServing = s.first),
        ),
      ],
    ),
  );
}
