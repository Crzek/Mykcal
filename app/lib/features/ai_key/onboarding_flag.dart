import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'onboarding_ai_key_seen';

/// Si ya se mostró el paso opcional de la clave de IA (research R13a). Es solo del móvil.
Future<bool> aiKeyStepSeen() async =>
    (await SharedPreferences.getInstance()).getBool(_key) ?? false;

Future<void> markAiKeyStepSeen() async =>
    (await SharedPreferences.getInstance()).setBool(_key, true);

/// Lectura y marca de la bandera como proveedores, para sustituirlas en las pruebas.
final aiKeyStepSeenReaderProvider = Provider<Future<bool> Function()>(
  (ref) => aiKeyStepSeen,
);
final aiKeyStepMarkerProvider = Provider<Future<void> Function()>(
  (ref) => markAiKeyStepSeen,
);
