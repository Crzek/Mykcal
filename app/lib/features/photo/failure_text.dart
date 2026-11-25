import '../../l10n/app_localizations.dart';

/// Texto de la causa de un borrador (research R11); `interrupted` si no hay código conocido.
String failureText(AppLocalizations l10n, String? code) => switch (code) {
  'key_invalid' => l10n.failKeyInvalid,
  'quota_exceeded' => l10n.failQuota,
  'invalid_response' => l10n.failInvalidResponse,
  'unrecognized' => l10n.failUnrecognized,
  'timeout' => l10n.failTimeout,
  'provider_unavailable' => l10n.failProvider,
  'key_required' => l10n.failKeyRequired,
  'no_connection' => l10n.failNoConnection,
  _ => l10n.failInterrupted,
};
