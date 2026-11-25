import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'draft_model.dart';

/// Borradores en el almacenamiento local del móvil (research R12). Máximo 20: al pasarse se
/// descarta el más antiguo. No guarda la clave de IA ni la respuesta cruda del proveedor.
class DraftsStore {
  static const key = 'photo_drafts';
  static const maxDrafts = 20;

  Future<List<PhotoDraft>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return const [];
    try {
      final drafts = [
        for (final e in jsonDecode(raw) as List<dynamic>)
          PhotoDraft.fromJson(e as Map<String, dynamic>),
      ];
      drafts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return drafts;
    } on Object {
      return const []; // un borrador ilegible no debe romper el diario
    }
  }

  /// Guarda o sustituye (por `id`). Devuelve los borradores descartados por el tope.
  Future<List<PhotoDraft>> save(PhotoDraft draft) async {
    final drafts = [
      for (final d in await list())
        if (d.id != draft.id) d,
      draft,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final dropped = drafts.length > maxDrafts
        ? drafts.sublist(0, drafts.length - maxDrafts)
        : <PhotoDraft>[];
    await _write(drafts.sublist(dropped.length));
    return dropped;
  }

  Future<void> remove(String id) async => _write([
    for (final d in await list())
      if (d.id != id) d,
  ]);

  Future<void> _write(List<PhotoDraft> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode([for (final d in drafts) d.toJson()]),
    );
  }
}
