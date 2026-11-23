import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Puerto de la hoja de compartir del sistema, sustituible en las pruebas (research R1).
abstract class SharePort {
  Future<void> share(String text);
}

class SharePlusPort implements SharePort {
  @override
  Future<void> share(String text) async {
    // Si el usuario cancela el selector no se lanza nada.
    await SharePlus.instance.share(ShareParams(text: text));
  }
}

final sharePortProvider = Provider<SharePort>((ref) => SharePlusPort());
