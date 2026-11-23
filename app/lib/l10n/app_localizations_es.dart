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
      'BORRADOR — Para calcular tu objetivo diario y llevar tu diario de comidas, Mykcal guarda tus datos de salud: edad, sexo, altura, peso, actividad física, objetivo y lo que registres cada día. Solo tú puedes verlos. Las fotos de comida no se guardan en el servidor. Puedes darte de baja cuando quieras; tus datos se conservan tras la baja.';

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
}
