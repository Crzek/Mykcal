import 'package:flutter_riverpod/flutter_riverpod.dart';

const _downloadPath = '/descargar/mykcal.apk';

/// Enlace de descarga del APK del entorno: la base de la API más la ruta pública que ya sirve el
/// backend (research R2). Sin barra doble y siempre `https://`.
String downloadLinkFrom(String apiBaseUrl) {
  if (!apiBaseUrl.startsWith('https://')) {
    throw StateError('API_BASE_URL debe empezar por https://');
  }
  final base = apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;
  return '$base$_downloadPath';
}

final downloadLinkProvider = Provider<String>(
  (ref) => downloadLinkFrom(const String.fromEnvironment('API_BASE_URL')),
);
