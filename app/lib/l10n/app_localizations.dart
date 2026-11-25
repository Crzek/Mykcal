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

  /// No description provided for @menuShareApp.
  ///
  /// In es, this message translates to:
  /// **'Compartir Mykcal'**
  String get menuShareApp;

  /// No description provided for @shareTitle.
  ///
  /// In es, this message translates to:
  /// **'Compartir Mykcal'**
  String get shareTitle;

  /// No description provided for @shareIntro.
  ///
  /// In es, this message translates to:
  /// **'Envía este enlace para que descarguen la app. Para crear la cuenta necesitarán un código de invitación.'**
  String get shareIntro;

  /// No description provided for @shareCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar'**
  String get shareCopy;

  /// No description provided for @shareSend.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get shareSend;

  /// No description provided for @shareCopied.
  ///
  /// In es, this message translates to:
  /// **'Enlace copiado'**
  String get shareCopied;

  /// No description provided for @shareCopyFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo copiar el enlace'**
  String get shareCopyFailed;

  /// No description provided for @shareText.
  ///
  /// In es, this message translates to:
  /// **'Prueba Mykcal, la app para registrar lo que comes: {link}'**
  String shareText(String link);

  /// No description provided for @codeAdminHint.
  ///
  /// In es, this message translates to:
  /// **'Si eres el administrador, puedes dejarlo vacío.'**
  String get codeAdminHint;

  /// No description provided for @errInvitationRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe el código de invitación.'**
  String get errInvitationRequired;

  /// No description provided for @errOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Inténtalo de nuevo.'**
  String get errOffline;

  /// No description provided for @ok.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get ok;

  /// No description provided for @consentTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus datos de salud'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In es, this message translates to:
  /// **'Mykcal te pide permiso para guardar y tratar tus datos de salud: edad, sexo, altura, peso, actividad física semanal, tu objetivo (perder grasa, mantener o ganar músculo) y lo que registres cada día en tu diario de comidas.\n\nLos usamos solo para calcular tu objetivo diario y mostrarte tu progreso. Solo tú puedes verlos: ni el administrador ni otras personas de Mykcal tienen acceso a ellos.\n\nLas fotos de comida no se guardan en el servidor: se analizan en el momento y se descartan. Si usas la función de foto con tu propia clave de IA, la clave se guarda cifrada.\n\nPuedes darte de baja cuando quieras desde Ajustes. Al darte de baja tu cuenta se desactiva y tus datos se conservan, sin plazo, pero ya no podrás acceder a ellos desde la app. Sin tu consentimiento no guardamos ningún dato de salud.'**
  String get consentBody;

  /// No description provided for @consentCheckbox.
  ///
  /// In es, this message translates to:
  /// **'He leído y acepto el tratamiento de mis datos de salud'**
  String get consentCheckbox;

  /// No description provided for @consentAccept.
  ///
  /// In es, this message translates to:
  /// **'Aceptar y continuar'**
  String get consentAccept;

  /// No description provided for @consentTextVersion.
  ///
  /// In es, this message translates to:
  /// **'2026-11-1'**
  String get consentTextVersion;

  /// No description provided for @errUpdateApp.
  ///
  /// In es, this message translates to:
  /// **'Actualiza la app para continuar.'**
  String get errUpdateApp;

  /// No description provided for @profileTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu perfil'**
  String get profileTitle;

  /// No description provided for @profileAge.
  ///
  /// In es, this message translates to:
  /// **'Edad'**
  String get profileAge;

  /// No description provided for @unitYears.
  ///
  /// In es, this message translates to:
  /// **'años'**
  String get unitYears;

  /// No description provided for @profileSex.
  ///
  /// In es, this message translates to:
  /// **'Sexo'**
  String get profileSex;

  /// No description provided for @profileSexHint.
  ///
  /// In es, this message translates to:
  /// **'Solo se usa para el cálculo'**
  String get profileSexHint;

  /// No description provided for @sexMale.
  ///
  /// In es, this message translates to:
  /// **'Hombre'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In es, this message translates to:
  /// **'Mujer'**
  String get sexFemale;

  /// No description provided for @profileHeight.
  ///
  /// In es, this message translates to:
  /// **'Altura'**
  String get profileHeight;

  /// No description provided for @unitCm.
  ///
  /// In es, this message translates to:
  /// **'cm'**
  String get unitCm;

  /// No description provided for @profileWeight.
  ///
  /// In es, this message translates to:
  /// **'Peso'**
  String get profileWeight;

  /// No description provided for @unitKg.
  ///
  /// In es, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @profileActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad física'**
  String get profileActivity;

  /// No description provided for @activitySedentary.
  ///
  /// In es, this message translates to:
  /// **'Sedentario'**
  String get activitySedentary;

  /// No description provided for @activityLight.
  ///
  /// In es, this message translates to:
  /// **'Ligera: 1–3 días/semana'**
  String get activityLight;

  /// No description provided for @activityModerate.
  ///
  /// In es, this message translates to:
  /// **'Moderada: 3–5 días/semana'**
  String get activityModerate;

  /// No description provided for @activityHigh.
  ///
  /// In es, this message translates to:
  /// **'Alta: 6–7 días/semana'**
  String get activityHigh;

  /// No description provided for @activityVeryHigh.
  ///
  /// In es, this message translates to:
  /// **'Muy alta: trabajo físico o dos sesiones al día'**
  String get activityVeryHigh;

  /// No description provided for @profileGoal.
  ///
  /// In es, this message translates to:
  /// **'Objetivo'**
  String get profileGoal;

  /// No description provided for @goalLose.
  ///
  /// In es, this message translates to:
  /// **'Perder grasa'**
  String get goalLose;

  /// No description provided for @goalMaintain.
  ///
  /// In es, this message translates to:
  /// **'Mantener'**
  String get goalMaintain;

  /// No description provided for @goalGain.
  ///
  /// In es, this message translates to:
  /// **'Ganar músculo'**
  String get goalGain;

  /// No description provided for @profileCalculate.
  ///
  /// In es, this message translates to:
  /// **'Calcular mi objetivo'**
  String get profileCalculate;

  /// No description provided for @profileSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get profileSave;

  /// No description provided for @profileSaved.
  ///
  /// In es, this message translates to:
  /// **'Perfil guardado'**
  String get profileSaved;

  /// No description provided for @errRequired.
  ///
  /// In es, this message translates to:
  /// **'Obligatorio'**
  String get errRequired;

  /// No description provided for @errAgeRange.
  ///
  /// In es, this message translates to:
  /// **'Entre 18 y 100 años'**
  String get errAgeRange;

  /// No description provided for @errHeightRange.
  ///
  /// In es, this message translates to:
  /// **'Entre 100 y 250 cm'**
  String get errHeightRange;

  /// No description provided for @errWeightRange.
  ///
  /// In es, this message translates to:
  /// **'Entre 30 y 300 kg, con un decimal como máximo'**
  String get errWeightRange;

  /// No description provided for @targetUpdatedTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu objetivo se ha actualizado'**
  String get targetUpdatedTitle;

  /// No description provided for @targetBefore.
  ///
  /// In es, this message translates to:
  /// **'Antes'**
  String get targetBefore;

  /// No description provided for @targetNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get targetNow;

  /// No description provided for @proposedTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu objetivo está editado a mano'**
  String get proposedTitle;

  /// No description provided for @proposedBody.
  ///
  /// In es, this message translates to:
  /// **'¿Recalcularlo con tus datos nuevos?'**
  String get proposedBody;

  /// No description provided for @targetCurrent.
  ///
  /// In es, this message translates to:
  /// **'Actual'**
  String get targetCurrent;

  /// No description provided for @targetProposed.
  ///
  /// In es, this message translates to:
  /// **'Propuesto'**
  String get targetProposed;

  /// No description provided for @keepMine.
  ///
  /// In es, this message translates to:
  /// **'Mantener el mío'**
  String get keepMine;

  /// No description provided for @recalculate.
  ///
  /// In es, this message translates to:
  /// **'Recalcular'**
  String get recalculate;

  /// No description provided for @macroSummary.
  ///
  /// In es, this message translates to:
  /// **'{kcal} kcal · P {protein} g · C {carbs} g · G {fat} g'**
  String macroSummary(String kcal, String protein, String carbs, String fat);

  /// No description provided for @targetTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu objetivo diario'**
  String get targetTitle;

  /// No description provided for @targetEditedBadge.
  ///
  /// In es, this message translates to:
  /// **'Editado a mano'**
  String get targetEditedBadge;

  /// No description provided for @nutrientKcal.
  ///
  /// In es, this message translates to:
  /// **'Calorías'**
  String get nutrientKcal;

  /// No description provided for @nutrientProtein.
  ///
  /// In es, this message translates to:
  /// **'Proteína'**
  String get nutrientProtein;

  /// No description provided for @nutrientCarbs.
  ///
  /// In es, this message translates to:
  /// **'Carbohidratos'**
  String get nutrientCarbs;

  /// No description provided for @nutrientFat.
  ///
  /// In es, this message translates to:
  /// **'Grasa'**
  String get nutrientFat;

  /// No description provided for @nutrientFiber.
  ///
  /// In es, this message translates to:
  /// **'Fibra'**
  String get nutrientFiber;

  /// No description provided for @nutrientSodium.
  ///
  /// In es, this message translates to:
  /// **'Sodio'**
  String get nutrientSodium;

  /// No description provided for @nutrientPotassium.
  ///
  /// In es, this message translates to:
  /// **'Potasio'**
  String get nutrientPotassium;

  /// No description provided for @nutrientCalcium.
  ///
  /// In es, this message translates to:
  /// **'Calcio'**
  String get nutrientCalcium;

  /// No description provided for @nutrientIron.
  ///
  /// In es, this message translates to:
  /// **'Hierro'**
  String get nutrientIron;

  /// No description provided for @nutrientMagnesium.
  ///
  /// In es, this message translates to:
  /// **'Magnesio'**
  String get nutrientMagnesium;

  /// No description provided for @nutrientVitD.
  ///
  /// In es, this message translates to:
  /// **'Vitamina D'**
  String get nutrientVitD;

  /// No description provided for @nutrientVitC.
  ///
  /// In es, this message translates to:
  /// **'Vitamina C'**
  String get nutrientVitC;

  /// No description provided for @kindMin.
  ///
  /// In es, this message translates to:
  /// **'mínimo'**
  String get kindMin;

  /// No description provided for @kindMax.
  ///
  /// In es, this message translates to:
  /// **'máximo'**
  String get kindMax;

  /// No description provided for @targetMicrosTitle.
  ///
  /// In es, this message translates to:
  /// **'Fibra y micronutrientes'**
  String get targetMicrosTitle;

  /// No description provided for @noticeMinKcal.
  ///
  /// In es, this message translates to:
  /// **'Hemos subido tus calorías al mínimo seguro de {min} kcal.'**
  String noticeMinKcal(String min);

  /// No description provided for @noticeCarbsClamped.
  ///
  /// In es, this message translates to:
  /// **'Tus macros no cuadran con las calorías: el objetivo no es coherente.'**
  String get noticeCarbsClamped;

  /// No description provided for @targetStart.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get targetStart;

  /// No description provided for @targetEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get targetEdit;

  /// No description provided for @targetBackToCalc.
  ///
  /// In es, this message translates to:
  /// **'Volver al cálculo'**
  String get targetBackToCalc;

  /// No description provided for @backToCalcTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Volver al cálculo automático?'**
  String get backToCalcTitle;

  /// No description provided for @backToCalcBody.
  ///
  /// In es, this message translates to:
  /// **'Se recalculará tu objetivo con tus datos actuales y perderás tus cambios.'**
  String get backToCalcBody;

  /// No description provided for @targetRecalculated.
  ///
  /// In es, this message translates to:
  /// **'Objetivo recalculado'**
  String get targetRecalculated;

  /// No description provided for @targetEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar objetivo'**
  String get targetEditTitle;

  /// No description provided for @targetSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get targetSave;

  /// No description provided for @targetSaved.
  ///
  /// In es, this message translates to:
  /// **'Objetivo guardado'**
  String get targetSaved;

  /// No description provided for @macroMismatch.
  ///
  /// In es, this message translates to:
  /// **'Las calorías de tus macros ({macros} kcal) no coinciden con tu objetivo ({kcal} kcal).'**
  String macroMismatch(String macros, String kcal);

  /// No description provided for @errIntMin0.
  ///
  /// In es, this message translates to:
  /// **'Escribe un número entero de 0 o más'**
  String get errIntMin0;

  /// No description provided for @errIntMin1.
  ///
  /// In es, this message translates to:
  /// **'Escribe un número entero de 1 o más'**
  String get errIntMin1;

  /// No description provided for @menuSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get menuSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsProfile.
  ///
  /// In es, this message translates to:
  /// **'Mi perfil'**
  String get settingsProfile;

  /// No description provided for @settingsTarget.
  ///
  /// In es, this message translates to:
  /// **'Mi objetivo'**
  String get settingsTarget;

  /// No description provided for @settingsDeactivate.
  ///
  /// In es, this message translates to:
  /// **'Darse de baja'**
  String get settingsDeactivate;

  /// No description provided for @deactivateAction.
  ///
  /// In es, this message translates to:
  /// **'Darme de baja'**
  String get deactivateAction;

  /// No description provided for @deactivateTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Darte de baja de Mykcal?'**
  String get deactivateTitle;

  /// No description provided for @deactivateBody.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta se desactivará y no podrás volver a entrar. Tus datos se conservan, pero no podrás verlos ni recuperar la cuenta desde la app.'**
  String get deactivateBody;

  /// No description provided for @deactivatedNotice.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta se ha dado de baja.'**
  String get deactivatedNotice;

  /// No description provided for @errDeactivate.
  ///
  /// In es, this message translates to:
  /// **'No se pudo dar de baja la cuenta. Inténtalo de nuevo.'**
  String get errDeactivate;

  /// No description provided for @foodNoData.
  ///
  /// In es, this message translates to:
  /// **'sin dato'**
  String get foodNoData;

  /// No description provided for @foodPer100g.
  ///
  /// In es, this message translates to:
  /// **'Por 100 g'**
  String get foodPer100g;

  /// No description provided for @foodPer100ml.
  ///
  /// In es, this message translates to:
  /// **'Por 100 ml'**
  String get foodPer100ml;

  /// No description provided for @foodMicrosTitle.
  ///
  /// In es, this message translates to:
  /// **'Micronutrientes'**
  String get foodMicrosTitle;

  /// No description provided for @homeFoods.
  ///
  /// In es, this message translates to:
  /// **'Alimentos'**
  String get homeFoods;

  /// No description provided for @foodsTitle.
  ///
  /// In es, this message translates to:
  /// **'Alimentos'**
  String get foodsTitle;

  /// No description provided for @foodsScan.
  ///
  /// In es, this message translates to:
  /// **'Escanear código de barras'**
  String get foodsScan;

  /// No description provided for @foodsSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Busca un alimento'**
  String get foodsSearchHint;

  /// No description provided for @foodsSearchClear.
  ///
  /// In es, this message translates to:
  /// **'Borrar búsqueda'**
  String get foodsSearchClear;

  /// No description provided for @foodsMinChars.
  ///
  /// In es, this message translates to:
  /// **'Escribe al menos 2 letras'**
  String get foodsMinChars;

  /// No description provided for @foodsSearching.
  ///
  /// In es, this message translates to:
  /// **'Buscando…'**
  String get foodsSearching;

  /// No description provided for @foodsNoResults.
  ///
  /// In es, this message translates to:
  /// **'No hemos encontrado “{q}”.'**
  String foodsNoResults(String q);

  /// No description provided for @foodsCreateNamed.
  ///
  /// In es, this message translates to:
  /// **'Crear alimento “{q}”'**
  String foodsCreateNamed(String q);

  /// No description provided for @foodsSectionMine.
  ///
  /// In es, this message translates to:
  /// **'Mis alimentos'**
  String get foodsSectionMine;

  /// No description provided for @foodsSectionGeneric.
  ///
  /// In es, this message translates to:
  /// **'Alimentos'**
  String get foodsSectionGeneric;

  /// No description provided for @foodsSectionPackaged.
  ///
  /// In es, this message translates to:
  /// **'Productos envasados'**
  String get foodsSectionPackaged;

  /// No description provided for @foodsMineBadge.
  ///
  /// In es, this message translates to:
  /// **'Mío'**
  String get foodsMineBadge;

  /// No description provided for @foodsMyFoods.
  ///
  /// In es, this message translates to:
  /// **'Mis alimentos'**
  String get foodsMyFoods;

  /// No description provided for @foodsOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Inténtalo de nuevo.'**
  String get foodsOffline;

  /// No description provided for @foodsRowKcalG.
  ///
  /// In es, this message translates to:
  /// **'{kcal} kilocalorías por 100 gramos'**
  String foodsRowKcalG(String kcal);

  /// No description provided for @foodsRowKcalMl.
  ///
  /// In es, this message translates to:
  /// **'{kcal} kilocalorías por 100 mililitros'**
  String foodsRowKcalMl(String kcal);

  /// No description provided for @foodsRowMineSemantics.
  ///
  /// In es, this message translates to:
  /// **'tuyo'**
  String get foodsRowMineSemantics;

  /// No description provided for @foodDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Alimento'**
  String get foodDetailTitle;

  /// No description provided for @foodSourceGeneric.
  ///
  /// In es, this message translates to:
  /// **'Genérico · CIQUAL'**
  String get foodSourceGeneric;

  /// No description provided for @foodSourcePackaged.
  ///
  /// In es, this message translates to:
  /// **'Envasado · Open Food Facts'**
  String get foodSourcePackaged;

  /// No description provided for @foodSourceCustom.
  ///
  /// In es, this message translates to:
  /// **'Tuyo'**
  String get foodSourceCustom;

  /// No description provided for @foodBrand.
  ///
  /// In es, this message translates to:
  /// **'Marca: {brand}'**
  String foodBrand(String brand);

  /// No description provided for @foodBarcode.
  ///
  /// In es, this message translates to:
  /// **'Código: {code}'**
  String foodBarcode(String code);

  /// No description provided for @foodServing.
  ///
  /// In es, this message translates to:
  /// **'Ración del envase: {amount}'**
  String foodServing(String amount);

  /// No description provided for @foodMissingNotice.
  ///
  /// In es, this message translates to:
  /// **'Los nutrientes sin dato cuentan como 0 en los totales.'**
  String get foodMissingNotice;

  /// No description provided for @foodStaleNotice.
  ///
  /// In es, this message translates to:
  /// **'Datos de una copia de más de 30 días.'**
  String get foodStaleNotice;

  /// No description provided for @foodEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar alimento'**
  String get foodEdit;

  /// No description provided for @scanTitle.
  ///
  /// In es, this message translates to:
  /// **'Escanear'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In es, this message translates to:
  /// **'Apunta al código de barras del envase'**
  String get scanHint;

  /// No description provided for @scanManual.
  ///
  /// In es, this message translates to:
  /// **'Introducir el código a mano'**
  String get scanManual;

  /// No description provided for @scanTorch.
  ///
  /// In es, this message translates to:
  /// **'Linterna'**
  String get scanTorch;

  /// No description provided for @scanManualLabel.
  ///
  /// In es, this message translates to:
  /// **'Código de barras (8 a 14 cifras)'**
  String get scanManualLabel;

  /// No description provided for @scanManualInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa el código: no es válido'**
  String get scanManualInvalid;

  /// No description provided for @scanManualSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get scanManualSearch;

  /// No description provided for @scanLooking.
  ///
  /// In es, this message translates to:
  /// **'Buscando producto…'**
  String get scanLooking;

  /// No description provided for @scanNotFound.
  ///
  /// In es, this message translates to:
  /// **'No conocemos este producto.'**
  String get scanNotFound;

  /// No description provided for @scanIncomplete.
  ///
  /// In es, this message translates to:
  /// **'{name} no tiene información nutricional suficiente.'**
  String scanIncomplete(String name);

  /// No description provided for @scanIncompleteNoName.
  ///
  /// In es, this message translates to:
  /// **'Este producto no tiene información nutricional suficiente.'**
  String get scanIncompleteNoName;

  /// No description provided for @scanCreateWithCode.
  ///
  /// In es, this message translates to:
  /// **'Crear alimento con este código'**
  String get scanCreateWithCode;

  /// No description provided for @scanSourceDown.
  ///
  /// In es, this message translates to:
  /// **'No hemos podido consultar la base de productos.'**
  String get scanSourceDown;

  /// No description provided for @scanCreateFood.
  ///
  /// In es, this message translates to:
  /// **'Crear alimento'**
  String get scanCreateFood;

  /// No description provided for @scanPermissionBody.
  ///
  /// In es, this message translates to:
  /// **'Mykcal usa la cámara solo para leer códigos de barras. No guarda fotos.'**
  String get scanPermissionBody;

  /// No description provided for @scanPermissionAllow.
  ///
  /// In es, this message translates to:
  /// **'Permitir cámara'**
  String get scanPermissionAllow;

  /// No description provided for @scanPermissionSettings.
  ///
  /// In es, this message translates to:
  /// **'Puedes activarlo en Ajustes del sistema → Aplicaciones → Mykcal → Permisos.'**
  String get scanPermissionSettings;

  /// No description provided for @scanUnsupported.
  ///
  /// In es, this message translates to:
  /// **'No se puede usar la cámara en este dispositivo.'**
  String get scanUnsupported;

  /// No description provided for @formNewTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo alimento'**
  String get formNewTitle;

  /// No description provided for @fieldName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get fieldName;

  /// No description provided for @fieldBrand.
  ///
  /// In es, this message translates to:
  /// **'Marca'**
  String get fieldBrand;

  /// No description provided for @fieldBarcode.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get fieldBarcode;

  /// No description provided for @fieldUnit.
  ///
  /// In es, this message translates to:
  /// **'Unidad'**
  String get fieldUnit;

  /// No description provided for @unitGrams.
  ///
  /// In es, this message translates to:
  /// **'Gramos'**
  String get unitGrams;

  /// No description provided for @unitMl.
  ///
  /// In es, this message translates to:
  /// **'Mililitros'**
  String get unitMl;

  /// No description provided for @fieldBasis.
  ///
  /// In es, this message translates to:
  /// **'Valores'**
  String get fieldBasis;

  /// No description provided for @basisPer100g.
  ///
  /// In es, this message translates to:
  /// **'Por 100 g'**
  String get basisPer100g;

  /// No description provided for @basisPer100ml.
  ///
  /// In es, this message translates to:
  /// **'Por 100 ml'**
  String get basisPer100ml;

  /// No description provided for @basisPerServing.
  ///
  /// In es, this message translates to:
  /// **'Por ración'**
  String get basisPerServing;

  /// No description provided for @fieldServing.
  ///
  /// In es, this message translates to:
  /// **'Ración'**
  String get fieldServing;

  /// No description provided for @formMicrosExpand.
  ///
  /// In es, this message translates to:
  /// **'Fibra y micronutrientes (opcional)'**
  String get formMicrosExpand;

  /// No description provided for @formSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get formSave;

  /// No description provided for @errNegative.
  ///
  /// In es, this message translates to:
  /// **'No puede ser negativo'**
  String get errNegative;

  /// No description provided for @errNotNumber.
  ///
  /// In es, this message translates to:
  /// **'Escribe un número'**
  String get errNotNumber;

  /// No description provided for @errTooHigh.
  ///
  /// In es, this message translates to:
  /// **'Como máximo {max} {unit} por 100 {base}'**
  String errTooHigh(String max, String unit, String base);

  /// No description provided for @errMassSum.
  ///
  /// In es, this message translates to:
  /// **'Proteína, carbohidratos, grasa y fibra suman más de 100 {base} por 100 {base}'**
  String errMassSum(String base);

  /// No description provided for @errServingRequired.
  ///
  /// In es, this message translates to:
  /// **'Indica cuántos {unitWord} tiene la ración'**
  String errServingRequired(String unitWord);

  /// No description provided for @errBarcodeInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa el código: no es válido'**
  String get errBarcodeInvalid;

  /// No description provided for @errBarcodeTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes un alimento con este código'**
  String get errBarcodeTaken;

  /// No description provided for @errNameTooLong.
  ///
  /// In es, this message translates to:
  /// **'Como máximo 120 caracteres'**
  String get errNameTooLong;

  /// No description provided for @errBrandTooLong.
  ///
  /// In es, this message translates to:
  /// **'Como máximo 80 caracteres'**
  String get errBrandTooLong;

  /// No description provided for @kcalMismatchWarning.
  ///
  /// In es, this message translates to:
  /// **'Las kcal no cuadran con los macros (calculadas: {n} kcal)'**
  String kcalMismatchWarning(String n);

  /// No description provided for @equivalentPer100.
  ///
  /// In es, this message translates to:
  /// **'= {value} {unit} por 100 {base}'**
  String equivalentPer100(String value, String unit, String base);

  /// No description provided for @discardTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar los cambios?'**
  String get discardTitle;

  /// No description provided for @discardConfirm.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get discardConfirm;

  /// No description provided for @keepEditing.
  ///
  /// In es, this message translates to:
  /// **'Seguir editando'**
  String get keepEditing;

  /// No description provided for @myFoodsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no has creado alimentos.'**
  String get myFoodsEmpty;

  /// No description provided for @myFoodsDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get myFoodsDelete;

  /// No description provided for @myFoodsEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get myFoodsEdit;

  /// No description provided for @myFoodsMore.
  ///
  /// In es, this message translates to:
  /// **'Más opciones de {name}'**
  String myFoodsMore(String name);

  /// No description provided for @myFoodsDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar “{name}”? Las comidas ya registradas no cambian.'**
  String myFoodsDeleteConfirm(String name);

  /// No description provided for @foodCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear alimento'**
  String get foodCreate;

  /// No description provided for @errInvalidValue.
  ///
  /// In es, this message translates to:
  /// **'Valor no válido'**
  String get errInvalidValue;

  /// No description provided for @settingsSources.
  ///
  /// In es, this message translates to:
  /// **'Fuentes de datos'**
  String get settingsSources;

  /// No description provided for @sourcesGenericTitle.
  ///
  /// In es, this message translates to:
  /// **'Alimentos genéricos'**
  String get sourcesGenericTitle;

  /// No description provided for @sourcesGeneric.
  ///
  /// In es, this message translates to:
  /// **'Anses, Table de composition nutritionnelle des aliments Ciqual, edición {edition}. Licencia CC BY 4.0. Nombres traducidos y selección por Mykcal.'**
  String sourcesGeneric(String edition);

  /// No description provided for @sourcesPackagedTitle.
  ///
  /// In es, this message translates to:
  /// **'Productos envasados'**
  String get sourcesPackagedTitle;

  /// No description provided for @sourcesPackaged.
  ///
  /// In es, this message translates to:
  /// **'Open Food Facts, disponible bajo la Open Database License (ODbL).'**
  String get sourcesPackaged;

  /// No description provided for @mealBreakfast.
  ///
  /// In es, this message translates to:
  /// **'Desayuno'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In es, this message translates to:
  /// **'Comida'**
  String get mealLunch;

  /// No description provided for @mealAfternoonSnack.
  ///
  /// In es, this message translates to:
  /// **'Merienda'**
  String get mealAfternoonSnack;

  /// No description provided for @mealDinner.
  ///
  /// In es, this message translates to:
  /// **'Cena'**
  String get mealDinner;

  /// No description provided for @mealSnacks.
  ///
  /// In es, this message translates to:
  /// **'Picoteo'**
  String get mealSnacks;

  /// No description provided for @diaryToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get diaryToday;

  /// No description provided for @diaryEmptyMeal.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay nada'**
  String get diaryEmptyMeal;

  /// No description provided for @diaryAddToMeal.
  ///
  /// In es, this message translates to:
  /// **'Añadir a {meal}'**
  String diaryAddToMeal(String meal);

  /// No description provided for @diaryMealTotal.
  ///
  /// In es, this message translates to:
  /// **'{meal}: {kcal} kcal'**
  String diaryMealTotal(String meal, String kcal);

  /// No description provided for @diaryEntryServings.
  ///
  /// In es, this message translates to:
  /// **'{servings} {unit} · {quantity} {base}'**
  String diaryEntryServings(
    String servings,
    String unit,
    String quantity,
    String base,
  );

  /// No description provided for @diaryEntryQuantity.
  ///
  /// In es, this message translates to:
  /// **'{quantity} {base}'**
  String diaryEntryQuantity(String quantity, String base);

  /// No description provided for @diaryServingOne.
  ///
  /// In es, this message translates to:
  /// **'ración'**
  String get diaryServingOne;

  /// No description provided for @diaryServingMany.
  ///
  /// In es, this message translates to:
  /// **'raciones'**
  String get diaryServingMany;

  /// No description provided for @diaryEntryKcal.
  ///
  /// In es, this message translates to:
  /// **'{kcal} kcal'**
  String diaryEntryKcal(String kcal);

  /// No description provided for @summaryRemaining.
  ///
  /// In es, this message translates to:
  /// **'Quedan {value} {unit}'**
  String summaryRemaining(String value, String unit);

  /// No description provided for @summaryOver.
  ///
  /// In es, this message translates to:
  /// **'+{value} {unit} por encima'**
  String summaryOver(String value, String unit);

  /// No description provided for @summaryMax.
  ///
  /// In es, this message translates to:
  /// **'máx. {value} {unit}'**
  String summaryMax(String value, String unit);

  /// No description provided for @summaryOverLimit.
  ///
  /// In es, this message translates to:
  /// **'{value} {unit} por encima del límite'**
  String summaryOverLimit(String value, String unit);

  /// No description provided for @summarySemanticsRemaining.
  ///
  /// In es, this message translates to:
  /// **'{name}: {consumed} de {target} {unit}, quedan {remaining} {unit}'**
  String summarySemanticsRemaining(
    String name,
    String consumed,
    String target,
    String unit,
    String remaining,
  );

  /// No description provided for @summarySemanticsOver.
  ///
  /// In es, this message translates to:
  /// **'{name}: {consumed} de {target} {unit}, {over} {unit} por encima'**
  String summarySemanticsOver(
    String name,
    String consumed,
    String target,
    String unit,
    String over,
  );

  /// No description provided for @summarySemanticsOverLimit.
  ///
  /// In es, this message translates to:
  /// **'{name}: {consumed} {unit}, máximo {target} {unit}, {over} {unit} por encima del límite'**
  String summarySemanticsOverLimit(
    String name,
    String consumed,
    String target,
    String unit,
    String over,
  );

  /// No description provided for @summarySemanticsLimitRemaining.
  ///
  /// In es, this message translates to:
  /// **'{name}: {consumed} {unit}, máximo {target} {unit}, quedan {remaining} {unit}'**
  String summarySemanticsLimitRemaining(
    String name,
    String consumed,
    String target,
    String unit,
    String remaining,
  );

  /// No description provided for @summaryIncomplete.
  ///
  /// In es, this message translates to:
  /// **'incompleto'**
  String get summaryIncomplete;

  /// No description provided for @summaryIncompleteHelp.
  ///
  /// In es, this message translates to:
  /// **'Algún alimento de este día no tiene este dato; cuenta como 0.'**
  String get summaryIncompleteHelp;

  /// No description provided for @summaryDetail.
  ///
  /// In es, this message translates to:
  /// **'Ver detalle'**
  String get summaryDetail;

  /// No description provided for @summaryDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Fibra y micronutrientes'**
  String get summaryDetailTitle;

  /// No description provided for @summaryTarget.
  ///
  /// In es, this message translates to:
  /// **'Ver objetivo'**
  String get summaryTarget;

  /// No description provided for @summaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Resumen del día'**
  String get summaryTitle;

  /// No description provided for @entryQuantityLabel.
  ///
  /// In es, this message translates to:
  /// **'Cantidad'**
  String get entryQuantityLabel;

  /// No description provided for @entryUnitServings.
  ///
  /// In es, this message translates to:
  /// **'raciones'**
  String get entryUnitServings;

  /// No description provided for @entryServingEquals.
  ///
  /// In es, this message translates to:
  /// **'1 ración = {n} {unit}'**
  String entryServingEquals(String n, String unit);

  /// No description provided for @entryQuantityInvalid.
  ///
  /// In es, this message translates to:
  /// **'Indica una cantidad mayor que 0'**
  String get entryQuantityInvalid;

  /// No description provided for @entryQuantityMax.
  ///
  /// In es, this message translates to:
  /// **'Máximo 10.000'**
  String get entryQuantityMax;

  /// No description provided for @entryConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Seguro? Son {n} {unit}'**
  String entryConfirmTitle(String n, String unit);

  /// No description provided for @entryChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get entryChange;

  /// No description provided for @entryConfirmAdd.
  ///
  /// In es, this message translates to:
  /// **'Sí, añadir'**
  String get entryConfirmAdd;

  /// No description provided for @entryAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get entryAdd;

  /// No description provided for @entryOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Revisa la red y vuelve a intentarlo'**
  String get entryOffline;

  /// No description provided for @entryAdded.
  ///
  /// In es, this message translates to:
  /// **'Añadido a {meal}'**
  String entryAdded(String meal);

  /// No description provided for @entryPreview.
  ///
  /// In es, this message translates to:
  /// **'{kcal} kcal · P {p} · C {c} · G {f} g'**
  String entryPreview(String kcal, String p, String c, String f);

  /// No description provided for @entrySave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get entrySave;

  /// No description provided for @entryDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get entryDelete;

  /// No description provided for @entryMealLabel.
  ///
  /// In es, this message translates to:
  /// **'Comida'**
  String get entryMealLabel;

  /// No description provided for @entryDeleted.
  ///
  /// In es, this message translates to:
  /// **'{name} borrado'**
  String entryDeleted(String name);

  /// No description provided for @entryUndo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get entryUndo;

  /// No description provided for @entryUndoFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo deshacer'**
  String get entryUndoFailed;

  /// No description provided for @dayYesterday.
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get dayYesterday;

  /// No description provided for @dayPrevious.
  ///
  /// In es, this message translates to:
  /// **'Día anterior'**
  String get dayPrevious;

  /// No description provided for @dayNext.
  ///
  /// In es, this message translates to:
  /// **'Día siguiente'**
  String get dayNext;

  /// No description provided for @dayPick.
  ///
  /// In es, this message translates to:
  /// **'Elegir fecha'**
  String get dayPick;

  /// No description provided for @dayGoToday.
  ///
  /// In es, this message translates to:
  /// **'Ir a hoy'**
  String get dayGoToday;

  /// No description provided for @dayPastNotice.
  ///
  /// In es, this message translates to:
  /// **'Este día usó el objetivo que tenías entonces'**
  String get dayPastNotice;

  /// No description provided for @quickTabRecent.
  ///
  /// In es, this message translates to:
  /// **'Recientes'**
  String get quickTabRecent;

  /// No description provided for @quickTabFavorites.
  ///
  /// In es, this message translates to:
  /// **'Favoritos'**
  String get quickTabFavorites;

  /// No description provided for @quickEmptyRecent.
  ///
  /// In es, this message translates to:
  /// **'Aquí aparecerán los alimentos que registres, para añadirlos con un toque.'**
  String get quickEmptyRecent;

  /// No description provided for @quickEmptyFavorites.
  ///
  /// In es, this message translates to:
  /// **'Marca alimentos con ☆ para tenerlos a mano aquí.'**
  String get quickEmptyFavorites;

  /// No description provided for @quickRowDetail.
  ///
  /// In es, this message translates to:
  /// **'{amount} · {kcal} kcal'**
  String quickRowDetail(String amount, String kcal);

  /// No description provided for @quickAddLabel.
  ///
  /// In es, this message translates to:
  /// **'Añadir {name}, {amount}'**
  String quickAddLabel(String name, String amount);

  /// No description provided for @quickAmountServings.
  ///
  /// In es, this message translates to:
  /// **'{servings} {unit}, {quantity} {base}'**
  String quickAmountServings(
    String servings,
    String unit,
    String quantity,
    String base,
  );

  /// No description provided for @quickAdded.
  ///
  /// In es, this message translates to:
  /// **'{name} añadido a {meal}'**
  String quickAdded(String name, String meal);

  /// No description provided for @quickUndone.
  ///
  /// In es, this message translates to:
  /// **'Deshecho'**
  String get quickUndone;

  /// No description provided for @quickUndoFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo deshacer. Borra la entrada desde el diario.'**
  String get quickUndoFailed;

  /// No description provided for @favoriteMark.
  ///
  /// In es, this message translates to:
  /// **'Marcar {name} como favorito'**
  String favoriteMark(String name);

  /// No description provided for @favoriteUnmark.
  ///
  /// In es, this message translates to:
  /// **'Quitar {name} de favoritos'**
  String favoriteUnmark(String name);

  /// No description provided for @favoriteRemoved.
  ///
  /// In es, this message translates to:
  /// **'Quitado de favoritos'**
  String get favoriteRemoved;

  /// No description provided for @favoriteUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Este alimento ya no está disponible'**
  String get favoriteUnavailable;

  /// No description provided for @copyMenu.
  ///
  /// In es, this message translates to:
  /// **'Copiar de otro día'**
  String get copyMenu;

  /// No description provided for @copyMenuTooltip.
  ///
  /// In es, this message translates to:
  /// **'Más opciones de {meal}'**
  String copyMenuTooltip(String meal);

  /// No description provided for @copyTitle.
  ///
  /// In es, this message translates to:
  /// **'Copiar a {meal} · {day}'**
  String copyTitle(String meal, String day);

  /// No description provided for @copyAction.
  ///
  /// In es, this message translates to:
  /// **'Copiar'**
  String get copyAction;

  /// No description provided for @copyEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay comidas en los 14 días anteriores.'**
  String get copyEmpty;

  /// No description provided for @copyValuesChanged.
  ///
  /// In es, this message translates to:
  /// **'Algún alimento ha cambiado: se copiará con sus valores actuales.'**
  String get copyValuesChanged;

  /// No description provided for @copyMore.
  ///
  /// In es, this message translates to:
  /// **'+{count} más'**
  String copyMore(int count);

  /// No description provided for @copyOptionSemantics.
  ///
  /// In es, this message translates to:
  /// **'{meal} de {day}, {kcal} kcal, {count} alimentos: {items}'**
  String copyOptionSemantics(
    String meal,
    String day,
    String kcal,
    int count,
    String items,
  );

  /// No description provided for @copyDone.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 alimento copiado a {meal}} other{{count} alimentos copiados a {meal}}}'**
  String copyDone(int count, String meal);

  /// No description provided for @copyUndone.
  ///
  /// In es, this message translates to:
  /// **'Copia deshecha'**
  String get copyUndone;

  /// No description provided for @copySourceEmpty.
  ///
  /// In es, this message translates to:
  /// **'Esa comida ya no tiene alimentos.'**
  String get copySourceEmpty;

  /// No description provided for @copyOutOfRange.
  ///
  /// In es, this message translates to:
  /// **'Esa comida ya no se puede copiar.'**
  String get copyOutOfRange;

  /// No description provided for @aiKeyTitle.
  ///
  /// In es, this message translates to:
  /// **'Clave de IA'**
  String get aiKeyTitle;

  /// No description provided for @aiKeyRowConfigured.
  ///
  /// In es, this message translates to:
  /// **'Configurada · {date}'**
  String aiKeyRowConfigured(String date);

  /// No description provided for @aiKeyRowNone.
  ///
  /// In es, this message translates to:
  /// **'No configurada'**
  String get aiKeyRowNone;

  /// No description provided for @aiKeyIntro.
  ///
  /// In es, this message translates to:
  /// **'Para registrar un plato con una foto, Mykcal usa tu propia clave de Google Gemini. Es gratis y solo tuya.'**
  String get aiKeyIntro;

  /// No description provided for @aiKeyStep1.
  ///
  /// In es, this message translates to:
  /// **'Entra en aistudio.google.com'**
  String get aiKeyStep1;

  /// No description provided for @aiKeyStep2.
  ///
  /// In es, this message translates to:
  /// **'Accede con tu cuenta de Google'**
  String get aiKeyStep2;

  /// No description provided for @aiKeyStep3.
  ///
  /// In es, this message translates to:
  /// **'Pulsa «Obtener clave de API» y crea una'**
  String get aiKeyStep3;

  /// No description provided for @aiKeyStep4.
  ///
  /// In es, this message translates to:
  /// **'Copia la clave y pégala aquí'**
  String get aiKeyStep4;

  /// No description provided for @aiKeyStepLabel.
  ///
  /// In es, this message translates to:
  /// **'Paso {n}: {text}'**
  String aiKeyStepLabel(String n, String text);

  /// No description provided for @aiKeyFieldLabel.
  ///
  /// In es, this message translates to:
  /// **'Clave de API'**
  String get aiKeyFieldLabel;

  /// No description provided for @aiKeyFieldHint.
  ///
  /// In es, this message translates to:
  /// **'Pega tu clave aquí'**
  String get aiKeyFieldHint;

  /// No description provided for @aiKeySave.
  ///
  /// In es, this message translates to:
  /// **'Guardar clave'**
  String get aiKeySave;

  /// No description provided for @aiKeySaved.
  ///
  /// In es, this message translates to:
  /// **'Clave configurada'**
  String get aiKeySaved;

  /// No description provided for @aiKeyInvalid.
  ///
  /// In es, this message translates to:
  /// **'La clave no es válida. Comprueba que la has copiado bien y que tu proyecto de Google tiene la API de Gemini activa.'**
  String get aiKeyInvalid;

  /// No description provided for @aiKeyUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido comprobar la clave ahora. Inténtalo más tarde.'**
  String get aiKeyUnavailable;

  /// No description provided for @aiKeySkip.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get aiKeySkip;

  /// No description provided for @aiKeyConfiguredOn.
  ///
  /// In es, this message translates to:
  /// **'Clave configurada el {date}'**
  String aiKeyConfiguredOn(String date);

  /// No description provided for @aiKeyProvider.
  ///
  /// In es, this message translates to:
  /// **'Proveedor: Google Gemini'**
  String get aiKeyProvider;

  /// No description provided for @aiKeyChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar clave'**
  String get aiKeyChange;

  /// No description provided for @aiKeyRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar clave'**
  String get aiKeyRemove;

  /// No description provided for @aiKeyRemoveTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Quitar la clave de IA?'**
  String get aiKeyRemoveTitle;

  /// No description provided for @aiKeyRemoveBody.
  ///
  /// In es, this message translates to:
  /// **'No podrás registrar con foto hasta que añadas otra clave.'**
  String get aiKeyRemoveBody;

  /// No description provided for @aiKeyRemoved.
  ///
  /// In es, this message translates to:
  /// **'Clave quitada'**
  String get aiKeyRemoved;

  /// No description provided for @photoTooltip.
  ///
  /// In es, this message translates to:
  /// **'Registrar con foto en {meal}'**
  String photoTooltip(String meal);

  /// No description provided for @photoNeedsKeyTooltip.
  ///
  /// In es, this message translates to:
  /// **'Registrar con foto en {meal}: necesitas una clave de IA'**
  String photoNeedsKeyTooltip(String meal);

  /// No description provided for @photoCaptureTitle.
  ///
  /// In es, this message translates to:
  /// **'Foto del plato'**
  String get photoCaptureTitle;

  /// No description provided for @photoPermissionDenied.
  ///
  /// In es, this message translates to:
  /// **'La cámara es necesaria para analizar la foto de tu plato.'**
  String get photoPermissionDenied;

  /// No description provided for @photoTake.
  ///
  /// In es, this message translates to:
  /// **'Hacer foto'**
  String get photoTake;

  /// No description provided for @photoFromGallery.
  ///
  /// In es, this message translates to:
  /// **'Elegir de la galería'**
  String get photoFromGallery;

  /// No description provided for @photoDescriptionLabel.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get photoDescriptionLabel;

  /// No description provided for @photoDescriptionHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: arroz con pollo y ensalada'**
  String get photoDescriptionHint;

  /// No description provided for @photoTotalGramsLabel.
  ///
  /// In es, this message translates to:
  /// **'Gramos totales del plato'**
  String get photoTotalGramsLabel;

  /// No description provided for @photoTotalGramsHint.
  ///
  /// In es, this message translates to:
  /// **'Opcional'**
  String get photoTotalGramsHint;

  /// No description provided for @photoAnalyze.
  ///
  /// In es, this message translates to:
  /// **'Analizar'**
  String get photoAnalyze;

  /// No description provided for @chipAnalyzing.
  ///
  /// In es, this message translates to:
  /// **'Analizando…'**
  String get chipAnalyzing;

  /// No description provided for @chipReady.
  ///
  /// In es, this message translates to:
  /// **'Análisis listo ✓'**
  String get chipReady;

  /// No description provided for @chipFailed.
  ///
  /// In es, this message translates to:
  /// **'Análisis fallido ✕'**
  String get chipFailed;

  /// No description provided for @snackReady.
  ///
  /// In es, this message translates to:
  /// **'Foto analizada — toca para revisar'**
  String get snackReady;

  /// No description provided for @snackSeeProposal.
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get snackSeeProposal;

  /// No description provided for @snackSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get snackSettings;

  /// No description provided for @snackSeeDraft.
  ///
  /// In es, this message translates to:
  /// **'Ver borrador'**
  String get snackSeeDraft;

  /// No description provided for @failKeyInvalid.
  ///
  /// In es, this message translates to:
  /// **'Tu clave de IA no es válida. Revísala en ajustes.'**
  String get failKeyInvalid;

  /// No description provided for @failQuota.
  ///
  /// In es, this message translates to:
  /// **'Has alcanzado el límite de tu cuenta de Google.'**
  String get failQuota;

  /// No description provided for @failInvalidResponse.
  ///
  /// In es, this message translates to:
  /// **'El análisis no ha podido completarse. Puedes reintentar o continuar a mano.'**
  String get failInvalidResponse;

  /// No description provided for @failUnrecognized.
  ///
  /// In es, this message translates to:
  /// **'No se ha reconocido ningún alimento en la foto. Puedes continuar a mano.'**
  String get failUnrecognized;

  /// No description provided for @failTimeout.
  ///
  /// In es, this message translates to:
  /// **'El análisis ha tardado demasiado. Puedes reintentar.'**
  String get failTimeout;

  /// No description provided for @failProvider.
  ///
  /// In es, this message translates to:
  /// **'El proveedor de IA no responde. Inténtalo más tarde.'**
  String get failProvider;

  /// No description provided for @failKeyRequired.
  ///
  /// In es, this message translates to:
  /// **'Necesitas una clave de IA para analizar fotos.'**
  String get failKeyRequired;

  /// No description provided for @failNoConnection.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Se ha guardado como borrador.'**
  String get failNoConnection;

  /// No description provided for @failInterrupted.
  ///
  /// In es, this message translates to:
  /// **'El análisis se interrumpió. Puedes reintentar.'**
  String get failInterrupted;

  /// No description provided for @proposalTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa lo que ha visto la IA'**
  String get proposalTitle;

  /// No description provided for @proposalAiName.
  ///
  /// In es, this message translates to:
  /// **'{name} (IA)'**
  String proposalAiName(String name);

  /// No description provided for @proposalNoMatch.
  ///
  /// In es, this message translates to:
  /// **'Sin equivalente en tu base'**
  String get proposalNoMatch;

  /// No description provided for @proposalFlagged.
  ///
  /// In es, this message translates to:
  /// **'Revisa los gramos'**
  String get proposalFlagged;

  /// No description provided for @proposalChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get proposalChange;

  /// No description provided for @proposalSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get proposalSearch;

  /// No description provided for @proposalCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get proposalCreate;

  /// No description provided for @proposalRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get proposalRemove;

  /// No description provided for @proposalAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir alimento'**
  String get proposalAdd;

  /// No description provided for @proposalGramsKcal.
  ///
  /// In es, this message translates to:
  /// **'{grams} g · {kcal} kcal'**
  String proposalGramsKcal(String grams, String kcal);

  /// No description provided for @proposalGrams.
  ///
  /// In es, this message translates to:
  /// **'{grams} g'**
  String proposalGrams(String grams);

  /// No description provided for @proposalTotals.
  ///
  /// In es, this message translates to:
  /// **'Total: {kcal} kcal · P {p} g · H {c} g · G {f} g'**
  String proposalTotals(String kcal, String p, String c, String f);

  /// No description provided for @proposalSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar en {meal}'**
  String proposalSave(String meal);

  /// No description provided for @proposalSaved.
  ///
  /// In es, this message translates to:
  /// **'Platos guardados en {meal}'**
  String proposalSaved(String meal);

  /// No description provided for @proposalGramsTitle.
  ///
  /// In es, this message translates to:
  /// **'Gramos'**
  String get proposalGramsTitle;

  /// No description provided for @proposalGramsField.
  ///
  /// In es, this message translates to:
  /// **'Gramos'**
  String get proposalGramsField;

  /// No description provided for @proposalSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido guardar. Inténtalo de nuevo.'**
  String get proposalSaveError;

  /// No description provided for @proposalEmpty.
  ///
  /// In es, this message translates to:
  /// **'No queda ningún alimento en la propuesta.'**
  String get proposalEmpty;

  /// No description provided for @draftsTitle.
  ///
  /// In es, this message translates to:
  /// **'Borradores de fotos'**
  String get draftsTitle;

  /// No description provided for @draftsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No tienes borradores.'**
  String get draftsEmpty;

  /// No description provided for @draftsRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get draftsRetry;

  /// No description provided for @draftsManual.
  ///
  /// In es, this message translates to:
  /// **'Añadir a mano'**
  String get draftsManual;

  /// No description provided for @draftsDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get draftsDiscard;

  /// No description provided for @draftsDiscardTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar el borrador?'**
  String get draftsDiscardTitle;

  /// No description provided for @draftsDiscardBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrará la foto de este borrador.'**
  String get draftsDiscardBody;

  /// No description provided for @draftsReview.
  ///
  /// In es, this message translates to:
  /// **'Revisar'**
  String get draftsReview;

  /// No description provided for @draftsReady.
  ///
  /// In es, this message translates to:
  /// **'Análisis listo'**
  String get draftsReady;

  /// No description provided for @draftsRowTitle.
  ///
  /// In es, this message translates to:
  /// **'{meal} · {date}'**
  String draftsRowTitle(String meal, String date);

  /// No description provided for @draftsBadge.
  ///
  /// In es, this message translates to:
  /// **'Borradores de fotos: {count}'**
  String draftsBadge(String count);
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
