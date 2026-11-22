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
}
