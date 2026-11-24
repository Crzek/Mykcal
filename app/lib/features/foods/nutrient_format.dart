import '../../core/api/models.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';

/// Una fila de la tabla nutricional de un alimento.
class NutrientRow {
  const NutrientRow({
    required this.label,
    required this.unit,
    required this.value,
  });

  final String label;
  final String unit;

  /// `null` es «sin dato»: no es lo mismo que 0 (FR-003, FR-016).
  final double? value;

  String text(AppLocalizations l10n) =>
      formatNutrient(value, unit, noData: l10n.foodNoData);

  /// Para el lector de pantalla: «Vitamina D: sin dato».
  String semantics(AppLocalizations l10n) => '$label: ${text(l10n)}';
}

/// «12,5 g», «358 mg» o el texto de «sin dato». Nunca muestra 0 ni «—» cuando falta el dato.
String formatNutrient(double? value, String unit, {required String noData}) =>
    value == null ? noData : '${formatDecimal(value)} $unit';

/// Calorías, macros y fibra, en el orden de la pantalla de detalle.
List<NutrientRow> macroRows(Nutrients n, AppLocalizations l10n) => [
  NutrientRow(label: l10n.nutrientKcal, unit: 'kcal', value: n.kcal),
  NutrientRow(label: l10n.nutrientProtein, unit: 'g', value: n.proteinG),
  NutrientRow(label: l10n.nutrientCarbs, unit: 'g', value: n.carbsG),
  NutrientRow(label: l10n.nutrientFat, unit: 'g', value: n.fatG),
  NutrientRow(label: l10n.nutrientFiber, unit: 'g', value: n.fiberG),
];

/// Los 7 micronutrientes que se guardan.
List<NutrientRow> microRows(Nutrients n, AppLocalizations l10n) => [
  NutrientRow(label: l10n.nutrientSodium, unit: 'mg', value: n.sodiumMg),
  NutrientRow(label: l10n.nutrientPotassium, unit: 'mg', value: n.potassiumMg),
  NutrientRow(label: l10n.nutrientCalcium, unit: 'mg', value: n.calciumMg),
  NutrientRow(label: l10n.nutrientIron, unit: 'mg', value: n.ironMg),
  NutrientRow(label: l10n.nutrientMagnesium, unit: 'mg', value: n.magnesiumMg),
  NutrientRow(label: l10n.nutrientVitD, unit: 'µg', value: n.vitaminDUg),
  NutrientRow(label: l10n.nutrientVitC, unit: 'mg', value: n.vitaminCMg),
];

/// «Por 100 g» o «Por 100 ml» según la unidad base.
String perBaseLabel(String baseUnit, AppLocalizations l10n) =>
    baseUnit == 'ml' ? l10n.foodPer100ml : l10n.foodPer100g;
