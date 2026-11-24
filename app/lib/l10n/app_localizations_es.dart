// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Mykcal';

  @override
  String get accessTagline => 'Registra lo que comes y alcanza tu objetivo.';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get signInFailed => 'No se pudo iniciar sesión. Inténtalo de nuevo.';

  @override
  String get signInUnavailable =>
      'No se pudo contactar con el servicio de acceso. Inténtalo de nuevo.';

  @override
  String get sessionExpired => 'Tu sesión ha caducado. Inicia sesión de nuevo.';

  @override
  String get signingIn => 'Abriendo el acceso…';

  @override
  String get codeTitle => 'Código de invitación';

  @override
  String get codeIntro =>
      'Para crear tu cuenta de Mykcal necesitas el código de invitación.';

  @override
  String get codeHelp => 'Pídeselo a Erick.';

  @override
  String get codeLabel => 'Código';

  @override
  String get codeContinue => 'Continuar';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get signingOut => 'Cerrando sesión…';

  @override
  String get errInvitationInvalid =>
      'El código no es válido. Comprueba que es el último que te envió Erick.';

  @override
  String get errNoSeats => 'Ahora mismo no hay plazas libres en Mykcal.';

  @override
  String errTooManyAttempts(String time) {
    return 'Demasiados intentos. Podrás volver a probar en $time.';
  }

  @override
  String get errForbidden => 'No tienes permiso para esto.';

  @override
  String get errServer =>
      'El servidor no responde. Inténtalo de nuevo en unos minutos.';

  @override
  String get errGeneric => 'Algo ha fallado. Inténtalo de nuevo.';

  @override
  String get offlineBanner => 'Necesitas conexión a Internet.';

  @override
  String get retry => 'Reintentar';

  @override
  String homeGreeting(String name) {
    return 'Hola, $name';
  }

  @override
  String get homePlaceholder => 'Aquí irá tu diario de comidas.';

  @override
  String get menuLabel => 'Menú';

  @override
  String get menuInvitations => 'Invitaciones';

  @override
  String get disabledTitle => 'Tu cuenta está desactivada';

  @override
  String get disabledBody => 'Si crees que es un error, habla con Erick.';

  @override
  String get invitationsTitle => 'Invitaciones';

  @override
  String get invitationCurrentCode => 'Código vigente';

  @override
  String get invitationNoCode =>
      'Todavía no hay código. Genera uno para invitar a alguien.';

  @override
  String get invitationCopy => 'Copiar código';

  @override
  String get invitationCopied => 'Código copiado';

  @override
  String invitationSeats(int active, int max, int free) {
    return '$active de $max cuentas activas · $free plazas libres';
  }

  @override
  String get invitationChange => 'Cambiar código';

  @override
  String get invitationGenerate => 'Generar código';

  @override
  String get invitationConfirmTitle => '¿Cambiar el código?';

  @override
  String get invitationConfirmBody =>
      'El código anterior dejará de valer de inmediato. Las cuentas ya creadas no se ven afectadas.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get confirmChange => 'Cambiar';

  @override
  String get menuShareApp => 'Compartir Mykcal';

  @override
  String get shareTitle => 'Compartir Mykcal';

  @override
  String get shareIntro =>
      'Envía este enlace para que descarguen la app. Para crear la cuenta necesitarán un código de invitación.';

  @override
  String get shareCopy => 'Copiar';

  @override
  String get shareSend => 'Compartir';

  @override
  String get shareCopied => 'Enlace copiado';

  @override
  String get shareCopyFailed => 'No se pudo copiar el enlace';

  @override
  String shareText(String link) {
    return 'Prueba Mykcal, la app para registrar lo que comes: $link';
  }

  @override
  String get codeAdminHint => 'Si eres el administrador, puedes dejarlo vacío.';

  @override
  String get errInvitationRequired => 'Escribe el código de invitación.';

  @override
  String get errOffline => 'Sin conexión. Inténtalo de nuevo.';

  @override
  String get ok => 'Aceptar';

  @override
  String get consentTitle => 'Tus datos de salud';

  @override
  String get consentBody =>
      'Mykcal te pide permiso para guardar y tratar tus datos de salud: edad, sexo, altura, peso, actividad física semanal, tu objetivo (perder grasa, mantener o ganar músculo) y lo que registres cada día en tu diario de comidas.\n\nLos usamos solo para calcular tu objetivo diario y mostrarte tu progreso. Solo tú puedes verlos: ni el administrador ni otras personas de Mykcal tienen acceso a ellos.\n\nLas fotos de comida no se guardan en el servidor: se analizan en el momento y se descartan. Si usas la función de foto con tu propia clave de IA, la clave se guarda cifrada.\n\nPuedes darte de baja cuando quieras desde Ajustes. Al darte de baja tu cuenta se desactiva y tus datos se conservan, sin plazo, pero ya no podrás acceder a ellos desde la app. Sin tu consentimiento no guardamos ningún dato de salud.';

  @override
  String get consentCheckbox =>
      'He leído y acepto el tratamiento de mis datos de salud';

  @override
  String get consentAccept => 'Aceptar y continuar';

  @override
  String get consentTextVersion => '2026-11-1';

  @override
  String get errUpdateApp => 'Actualiza la app para continuar.';

  @override
  String get profileTitle => 'Tu perfil';

  @override
  String get profileAge => 'Edad';

  @override
  String get unitYears => 'años';

  @override
  String get profileSex => 'Sexo';

  @override
  String get profileSexHint => 'Solo se usa para el cálculo';

  @override
  String get sexMale => 'Hombre';

  @override
  String get sexFemale => 'Mujer';

  @override
  String get profileHeight => 'Altura';

  @override
  String get unitCm => 'cm';

  @override
  String get profileWeight => 'Peso';

  @override
  String get unitKg => 'kg';

  @override
  String get profileActivity => 'Actividad física';

  @override
  String get activitySedentary => 'Sedentario';

  @override
  String get activityLight => 'Ligera: 1–3 días/semana';

  @override
  String get activityModerate => 'Moderada: 3–5 días/semana';

  @override
  String get activityHigh => 'Alta: 6–7 días/semana';

  @override
  String get activityVeryHigh =>
      'Muy alta: trabajo físico o dos sesiones al día';

  @override
  String get profileGoal => 'Objetivo';

  @override
  String get goalLose => 'Perder grasa';

  @override
  String get goalMaintain => 'Mantener';

  @override
  String get goalGain => 'Ganar músculo';

  @override
  String get profileCalculate => 'Calcular mi objetivo';

  @override
  String get profileSave => 'Guardar';

  @override
  String get profileSaved => 'Perfil guardado';

  @override
  String get errRequired => 'Obligatorio';

  @override
  String get errAgeRange => 'Entre 18 y 100 años';

  @override
  String get errHeightRange => 'Entre 100 y 250 cm';

  @override
  String get errWeightRange => 'Entre 30 y 300 kg, con un decimal como máximo';

  @override
  String get targetUpdatedTitle => 'Tu objetivo se ha actualizado';

  @override
  String get targetBefore => 'Antes';

  @override
  String get targetNow => 'Ahora';

  @override
  String get proposedTitle => 'Tu objetivo está editado a mano';

  @override
  String get proposedBody => '¿Recalcularlo con tus datos nuevos?';

  @override
  String get targetCurrent => 'Actual';

  @override
  String get targetProposed => 'Propuesto';

  @override
  String get keepMine => 'Mantener el mío';

  @override
  String get recalculate => 'Recalcular';

  @override
  String macroSummary(String kcal, String protein, String carbs, String fat) {
    return '$kcal kcal · P $protein g · C $carbs g · G $fat g';
  }

  @override
  String get targetTitle => 'Tu objetivo diario';

  @override
  String get targetEditedBadge => 'Editado a mano';

  @override
  String get nutrientKcal => 'Calorías';

  @override
  String get nutrientProtein => 'Proteína';

  @override
  String get nutrientCarbs => 'Carbohidratos';

  @override
  String get nutrientFat => 'Grasa';

  @override
  String get nutrientFiber => 'Fibra';

  @override
  String get nutrientSodium => 'Sodio';

  @override
  String get nutrientPotassium => 'Potasio';

  @override
  String get nutrientCalcium => 'Calcio';

  @override
  String get nutrientIron => 'Hierro';

  @override
  String get nutrientMagnesium => 'Magnesio';

  @override
  String get nutrientVitD => 'Vitamina D';

  @override
  String get nutrientVitC => 'Vitamina C';

  @override
  String get kindMin => 'mínimo';

  @override
  String get kindMax => 'máximo';

  @override
  String get targetMicrosTitle => 'Fibra y micronutrientes';

  @override
  String noticeMinKcal(String min) {
    return 'Hemos subido tus calorías al mínimo seguro de $min kcal.';
  }

  @override
  String get noticeCarbsClamped =>
      'Tus macros no cuadran con las calorías: el objetivo no es coherente.';

  @override
  String get targetStart => 'Empezar';

  @override
  String get targetEdit => 'Editar';

  @override
  String get targetBackToCalc => 'Volver al cálculo';

  @override
  String get backToCalcTitle => '¿Volver al cálculo automático?';

  @override
  String get backToCalcBody =>
      'Se recalculará tu objetivo con tus datos actuales y perderás tus cambios.';

  @override
  String get targetRecalculated => 'Objetivo recalculado';

  @override
  String get targetEditTitle => 'Editar objetivo';

  @override
  String get targetSave => 'Guardar';

  @override
  String get targetSaved => 'Objetivo guardado';

  @override
  String macroMismatch(String macros, String kcal) {
    return 'Las calorías de tus macros ($macros kcal) no coinciden con tu objetivo ($kcal kcal).';
  }

  @override
  String get errIntMin0 => 'Escribe un número entero de 0 o más';

  @override
  String get errIntMin1 => 'Escribe un número entero de 1 o más';

  @override
  String get homeTargetTitle => 'Tu objetivo de hoy';

  @override
  String get homeTargetDetail => 'Ver detalle';

  @override
  String get menuSettings => 'Ajustes';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsProfile => 'Mi perfil';

  @override
  String get settingsTarget => 'Mi objetivo';

  @override
  String get settingsDeactivate => 'Darse de baja';

  @override
  String get deactivateAction => 'Darme de baja';

  @override
  String get deactivateTitle => '¿Darte de baja de Mykcal?';

  @override
  String get deactivateBody =>
      'Tu cuenta se desactivará y no podrás volver a entrar. Tus datos se conservan, pero no podrás verlos ni recuperar la cuenta desde la app.';

  @override
  String get deactivatedNotice => 'Tu cuenta se ha dado de baja.';

  @override
  String get errDeactivate =>
      'No se pudo dar de baja la cuenta. Inténtalo de nuevo.';

  @override
  String get foodNoData => 'sin dato';

  @override
  String get foodPer100g => 'Por 100 g';

  @override
  String get foodPer100ml => 'Por 100 ml';

  @override
  String get foodMicrosTitle => 'Micronutrientes';

  @override
  String get homeFoods => 'Alimentos';

  @override
  String get foodsTitle => 'Alimentos';

  @override
  String get foodsScan => 'Escanear código de barras';

  @override
  String get foodsSearchHint => 'Busca un alimento';

  @override
  String get foodsSearchClear => 'Borrar búsqueda';

  @override
  String get foodsMinChars => 'Escribe al menos 2 letras';

  @override
  String get foodsSearching => 'Buscando…';

  @override
  String foodsNoResults(String q) {
    return 'No hemos encontrado “$q”.';
  }

  @override
  String foodsCreateNamed(String q) {
    return 'Crear alimento “$q”';
  }

  @override
  String get foodsSectionMine => 'Mis alimentos';

  @override
  String get foodsSectionGeneric => 'Alimentos';

  @override
  String get foodsSectionPackaged => 'Productos envasados';

  @override
  String get foodsMineBadge => 'Mío';

  @override
  String get foodsMyFoods => 'Mis alimentos';

  @override
  String get foodsOffline => 'Sin conexión. Inténtalo de nuevo.';

  @override
  String foodsRowKcalG(String kcal) {
    return '$kcal kilocalorías por 100 gramos';
  }

  @override
  String foodsRowKcalMl(String kcal) {
    return '$kcal kilocalorías por 100 mililitros';
  }

  @override
  String get foodsRowMineSemantics => 'tuyo';

  @override
  String get foodDetailTitle => 'Alimento';

  @override
  String get foodSourceGeneric => 'Genérico · CIQUAL';

  @override
  String get foodSourcePackaged => 'Envasado · Open Food Facts';

  @override
  String get foodSourceCustom => 'Tuyo';

  @override
  String foodBrand(String brand) {
    return 'Marca: $brand';
  }

  @override
  String foodBarcode(String code) {
    return 'Código: $code';
  }

  @override
  String foodServing(String amount) {
    return 'Ración del envase: $amount';
  }

  @override
  String get foodMissingNotice =>
      'Los nutrientes sin dato cuentan como 0 en los totales.';

  @override
  String get foodStaleNotice => 'Datos de una copia de más de 30 días.';

  @override
  String get foodEdit => 'Editar alimento';

  @override
  String get scanTitle => 'Escanear';

  @override
  String get scanHint => 'Apunta al código de barras del envase';

  @override
  String get scanManual => 'Introducir el código a mano';

  @override
  String get scanTorch => 'Linterna';

  @override
  String get scanManualLabel => 'Código de barras (8 a 14 cifras)';

  @override
  String get scanManualInvalid => 'Revisa el código: no es válido';

  @override
  String get scanManualSearch => 'Buscar';

  @override
  String get scanLooking => 'Buscando producto…';

  @override
  String get scanNotFound => 'No conocemos este producto.';

  @override
  String scanIncomplete(String name) {
    return '$name no tiene información nutricional suficiente.';
  }

  @override
  String get scanIncompleteNoName =>
      'Este producto no tiene información nutricional suficiente.';

  @override
  String get scanCreateWithCode => 'Crear alimento con este código';

  @override
  String get scanSourceDown =>
      'No hemos podido consultar la base de productos.';

  @override
  String get scanCreateFood => 'Crear alimento';

  @override
  String get scanPermissionBody =>
      'Mykcal usa la cámara solo para leer códigos de barras. No guarda fotos.';

  @override
  String get scanPermissionAllow => 'Permitir cámara';

  @override
  String get scanPermissionSettings =>
      'Puedes activarlo en Ajustes del sistema → Aplicaciones → Mykcal → Permisos.';

  @override
  String get scanUnsupported =>
      'No se puede usar la cámara en este dispositivo.';

  @override
  String get formNewTitle => 'Nuevo alimento';

  @override
  String get fieldName => 'Nombre';

  @override
  String get fieldBrand => 'Marca';

  @override
  String get fieldBarcode => 'Código';

  @override
  String get fieldUnit => 'Unidad';

  @override
  String get unitGrams => 'Gramos';

  @override
  String get unitMl => 'Mililitros';

  @override
  String get fieldBasis => 'Valores';

  @override
  String get basisPer100g => 'Por 100 g';

  @override
  String get basisPer100ml => 'Por 100 ml';

  @override
  String get basisPerServing => 'Por ración';

  @override
  String get fieldServing => 'Ración';

  @override
  String get formMicrosExpand => 'Fibra y micronutrientes (opcional)';

  @override
  String get formSave => 'Guardar';

  @override
  String get errNegative => 'No puede ser negativo';

  @override
  String get errNotNumber => 'Escribe un número';

  @override
  String errTooHigh(String max, String unit, String base) {
    return 'Como máximo $max $unit por 100 $base';
  }

  @override
  String errMassSum(String base) {
    return 'Proteína, carbohidratos, grasa y fibra suman más de 100 $base por 100 $base';
  }

  @override
  String errServingRequired(String unitWord) {
    return 'Indica cuántos $unitWord tiene la ración';
  }

  @override
  String get errBarcodeInvalid => 'Revisa el código: no es válido';

  @override
  String get errBarcodeTaken => 'Ya tienes un alimento con este código';

  @override
  String get errNameTooLong => 'Como máximo 120 caracteres';

  @override
  String get errBrandTooLong => 'Como máximo 80 caracteres';

  @override
  String kcalMismatchWarning(String n) {
    return 'Las kcal no cuadran con los macros (calculadas: $n kcal)';
  }

  @override
  String equivalentPer100(String value, String unit, String base) {
    return '= $value $unit por 100 $base';
  }

  @override
  String get discardTitle => '¿Descartar los cambios?';

  @override
  String get discardConfirm => 'Descartar';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String get myFoodsEmpty => 'Aún no has creado alimentos.';

  @override
  String get myFoodsDelete => 'Eliminar';

  @override
  String get myFoodsEdit => 'Editar';

  @override
  String myFoodsMore(String name) {
    return 'Más opciones de $name';
  }

  @override
  String myFoodsDeleteConfirm(String name) {
    return '¿Eliminar “$name”? Las comidas ya registradas no cambian.';
  }

  @override
  String get foodCreate => 'Crear alimento';

  @override
  String get errInvalidValue => 'Valor no válido';

  @override
  String get settingsSources => 'Fuentes de datos';

  @override
  String get sourcesGenericTitle => 'Alimentos genéricos';

  @override
  String sourcesGeneric(String edition) {
    return 'Anses, Table de composition nutritionnelle des aliments Ciqual, edición $edition. Licencia CC BY 4.0. Nombres traducidos y selección por Mykcal.';
  }

  @override
  String get sourcesPackagedTitle => 'Productos envasados';

  @override
  String get sourcesPackaged =>
      'Open Food Facts, disponible bajo la Open Database License (ODbL).';
}
