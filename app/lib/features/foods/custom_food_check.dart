import '../../core/format/numbers.dart';
import 'gtin.dart';

/// Reglas del formulario de alimento personalizado. Mismas que
/// `backend/src/mykcal/foods/custom_rules.py` (research R10); el servidor tiene la última palabra.

enum CustomField {
  name('name'),
  brand('brand'),
  barcode('barcode'),
  serving('serving_size'),
  kcal('kcal'),
  protein('protein_g'),
  carbs('carbs_g'),
  fat('fat_g'),
  fiber('fiber_g'),
  sodium('sodium_mg'),
  potassium('potassium_mg'),
  calcium('calcium_mg'),
  iron('iron_mg'),
  magnesium('magnesium_mg'),
  vitaminD('vitamin_d_ug'),
  vitaminC('vitamin_c_mg');

  const CustomField(this.wire);

  /// Nombre del campo en la API.
  final String wire;

  static CustomField? fromWire(String name) {
    for (final f in values) {
      if (f.wire == name) return f;
    }
    return null;
  }

  bool get isNutrient => index >= CustomField.kcal.index;
  bool get isRequiredNutrient =>
      this == kcal || this == protein || this == carbs || this == fat;
}

enum FieldError {
  required,
  notNumber,
  negative,
  tooHigh,
  massSum,
  servingRequired,
  barcodeInvalid,
  nameTooLong,
  brandTooLong,

  /// Lo rechaza el servidor sin más detalle.
  invalid,
}

const nameMax = 120;
const brandMax = 80;
const servingMax = 5000.0;

/// Máximos por 100 g o ml (data-model.md).
const maxPer100 = <CustomField, double>{
  CustomField.kcal: 900,
  CustomField.protein: 100,
  CustomField.carbs: 100,
  CustomField.fat: 100,
  CustomField.fiber: 100,
  CustomField.sodium: 40000,
  CustomField.potassium: 10000,
  CustomField.calcium: 5000,
  CustomField.iron: 500,
  CustomField.magnesium: 2000,
  CustomField.vitaminD: 1000,
  CustomField.vitaminC: 5000,
};

const massFields = [
  CustomField.protein,
  CustomField.carbs,
  CustomField.fat,
  CustomField.fiber,
];

/// Lo escrito en el formulario, sin interpretar.
class CustomFoodDraft {
  const CustomFoodDraft({required this.texts, this.perServing = false});

  /// Texto de cada campo; los que faltan cuentan como vacíos.
  final Map<CustomField, String> texts;
  final bool perServing;

  String text(CustomField f) => (texts[f] ?? '').trim();

  /// `null` si está vacío o no es un número.
  double? number(CustomField f) => parseDecimal(text(f));
}

double _round2(double v) => (v * 100).round() / 100;

/// Valores por 100 g/ml (FR-013). Con «Por ración» convierte con `valor × 100 / ración`.
/// Los campos vacíos o ilegibles quedan en `null`.
Map<CustomField, double?> per100Values(CustomFoodDraft d) {
  final serving = d.number(CustomField.serving);
  final factor = d.perServing && serving != null && serving > 0
      ? 100 / serving
      : 1.0;
  return {
    for (final f in CustomField.values.where((f) => f.isNutrient))
      f: d.number(f) == null ? null : _round2(d.number(f)! * factor),
  };
}

/// Errores por campo. Vacío si el borrador se puede guardar.
Map<CustomField, FieldError> checkCustomFood(CustomFoodDraft d) {
  final errors = <CustomField, FieldError>{};

  final name = d.text(CustomField.name);
  if (name.isEmpty) {
    errors[CustomField.name] = FieldError.required;
  } else if (name.length > nameMax) {
    errors[CustomField.name] = FieldError.nameTooLong;
  }
  if (d.text(CustomField.brand).length > brandMax) {
    errors[CustomField.brand] = FieldError.brandTooLong;
  }
  final barcode = d.text(CustomField.barcode);
  if (barcode.isNotEmpty && !isValidGtin(barcode)) {
    errors[CustomField.barcode] = FieldError.barcodeInvalid;
  }

  final servingText = d.text(CustomField.serving);
  final serving = d.number(CustomField.serving);
  if (servingText.isNotEmpty &&
      (serving == null || serving <= 0 || serving > servingMax)) {
    errors[CustomField.serving] = FieldError.servingRequired;
  } else if (d.perServing && serving == null) {
    errors[CustomField.serving] = FieldError.servingRequired;
  }

  for (final f in CustomField.values.where((f) => f.isNutrient)) {
    final text = d.text(f);
    if (text.isEmpty) {
      if (f.isRequiredNutrient) errors[f] = FieldError.required;
      continue;
    }
    final value = d.number(f);
    if (value == null || !value.isFinite) {
      errors[f] = FieldError.notNumber;
    } else if (value < 0) {
      errors[f] = FieldError.negative;
    }
  }
  if (errors.containsKey(CustomField.serving) && d.perServing) return errors;

  final per100 = per100Values(d);
  for (final f in per100.keys) {
    final v = per100[f];
    if (v != null && !errors.containsKey(f) && v > maxPer100[f]!) {
      errors[f] = FieldError.tooHigh;
    }
  }
  // La fibra cuenta: en CIQUAL y en OFF no forma parte de los carbohidratos (R10).
  final mass = massFields.fold<double>(0, (sum, f) => sum + (per100[f] ?? 0));
  if (mass > 100) {
    for (final f in massFields) {
      errors.putIfAbsent(f, () => FieldError.massSum);
    }
  }
  return errors;
}

/// `4·P + 4·C + 9·G` por 100, o `null` si faltan macros.
double? calculatedKcal(Map<CustomField, double?> per100) {
  final p = per100[CustomField.protein];
  final c = per100[CustomField.carbs];
  final g = per100[CustomField.fat];
  if (p == null || c == null || g == null) return null;
  return 4 * p + 4 * c + 9 * g;
}

/// Aviso (no bloquea) si las kcal difieren más de un 15 % de las calculadas (R10).
bool customKcalMismatch(Map<CustomField, double?> per100) {
  final kcal = per100[CustomField.kcal];
  final calc = calculatedKcal(per100);
  if (kcal == null || calc == null) return false;
  if (calc == 0) return kcal > 0;
  return (kcal - calc).abs() / calc > 0.15;
}
