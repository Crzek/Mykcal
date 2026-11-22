import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// No description provided for @appName.
  ///
  /// In es, this message translates to:
  /// **'Mykcal'**
  String get appName;

  /// No description provided for @accessTagline.
  ///
  /// In es, this message translates to:
  /// **'Registra lo que comes y alcanza tu objetivo.'**
  String get accessTagline;

  /// No description provided for @signIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get createAccount;

  /// No description provided for @signInFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar sesión. Inténtalo de nuevo.'**
  String get signInFailed;

  /// No description provided for @signInUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo contactar con el servicio de acceso. Inténtalo de nuevo.'**
  String get signInUnavailable;

  /// No description provided for @sessionExpired.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión ha caducado. Inicia sesión de nuevo.'**
  String get sessionExpired;

  /// No description provided for @signingIn.
  ///
  /// In es, this message translates to:
  /// **'Abriendo el acceso…'**
  String get signingIn;

  /// No description provided for @codeTitle.
  ///
  /// In es, this message translates to:
  /// **'Código de invitación'**
  String get codeTitle;

  /// No description provided for @codeIntro.
  ///
  /// In es, this message translates to:
  /// **'Para crear tu cuenta de Mykcal necesitas el código de invitación.'**
  String get codeIntro;

  /// No description provided for @codeHelp.
  ///
  /// In es, this message translates to:
  /// **'Pídeselo a Erick.'**
  String get codeHelp;

  /// No description provided for @codeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get codeLabel;

  /// No description provided for @codeContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get codeContinue;

  /// No description provided for @signOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get signOut;

  /// No description provided for @signingOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrando sesión…'**
  String get signingOut;

  /// No description provided for @errInvitationInvalid.
  ///
  /// In es, this message translates to:
  /// **'El código no es válido. Comprueba que es el último que te envió Erick.'**
  String get errInvitationInvalid;

  /// No description provided for @errNoSeats.
  ///
  /// In es, this message translates to:
  /// **'Ahora mismo no hay plazas libres en Mykcal.'**
  String get errNoSeats;

  /// No description provided for @errTooManyAttempts.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos. Podrás volver a probar en {time}.'**
  String errTooManyAttempts(String time);

  /// No description provided for @errForbidden.
  ///
  /// In es, this message translates to:
  /// **'No tienes permiso para esto.'**
  String get errForbidden;

  /// No description provided for @errServer.
  ///
  /// In es, this message translates to:
  /// **'El servidor no responde. Inténtalo de nuevo en unos minutos.'**
  String get errServer;

  /// No description provided for @errGeneric.
  ///
  /// In es, this message translates to:
  /// **'Algo ha fallado. Inténtalo de nuevo.'**
  String get errGeneric;

  /// No description provided for @offlineBanner.
  ///
  /// In es, this message translates to:
  /// **'Necesitas conexión a Internet.'**
  String get offlineBanner;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @homeGreeting.
  ///
  /// In es, this message translates to:
  /// **'Hola, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homePlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Aquí irá tu diario de comidas.'**
  String get homePlaceholder;

  /// No description provided for @menuLabel.
  ///
  /// In es, this message translates to:
  /// **'Menú'**
  String get menuLabel;

  /// No description provided for @menuInvitations.
  ///
  /// In es, this message translates to:
  /// **'Invitaciones'**
  String get menuInvitations;

  /// No description provided for @disabledTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta está desactivada'**
  String get disabledTitle;

  /// No description provided for @disabledBody.
  ///
  /// In es, this message translates to:
  /// **'Si crees que es un error, habla con Erick.'**
  String get disabledBody;

  /// No description provided for @invitationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Invitaciones'**
  String get invitationsTitle;

  /// No description provided for @invitationCurrentCode.
  ///
  /// In es, this message translates to:
  /// **'Código vigente'**
  String get invitationCurrentCode;

  /// No description provided for @invitationNoCode.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay código. Genera uno para invitar a alguien.'**
  String get invitationNoCode;

  /// No description provided for @invitationCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar código'**
  String get invitationCopy;

  /// No description provided for @invitationCopied.
  ///
  /// In es, this message translates to:
  /// **'Código copiado'**
  String get invitationCopied;

  /// No description provided for @invitationSeats.
  ///
  /// In es, this message translates to:
  /// **'{active} de {max} cuentas activas · {free} plazas libres'**
  String invitationSeats(int active, int max, int free);

  /// No description provided for @invitationChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar código'**
  String get invitationChange;

  /// No description provided for @invitationGenerate.
  ///
  /// In es, this message translates to:
  /// **'Generar código'**
  String get invitationGenerate;

  /// No description provided for @invitationConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cambiar el código?'**
  String get invitationConfirmTitle;

  /// No description provided for @invitationConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'El código anterior dejará de valer de inmediato. Las cuentas ya creadas no se ven afectadas.'**
  String get invitationConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @confirmChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get confirmChange;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
