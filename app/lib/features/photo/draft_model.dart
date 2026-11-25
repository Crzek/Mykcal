import '../../core/api/models.dart';

/// Borrador de una foto (006 `data-model.md`): vive solo en el móvil.
///
/// Sin `failureCode` es una propuesta de la IA ya lista (con `proposalJson`) que aún no se ha
/// guardado en el diario; con `failureCode`, un análisis que no terminó.
class PhotoDraft {
  const PhotoDraft({
    required this.id,
    required this.meal,
    required this.entryDate,
    required this.photoPath,
    required this.createdAt,
    this.description,
    this.totalGrams,
    this.failureCode,
    this.failureReason,
    this.proposalJson,
  });

  factory PhotoDraft.fromJson(Map<String, dynamic> json) => PhotoDraft(
    id: json['id'] as String,
    meal: Meal.parse(json['meal']),
    entryDate: DateTime.parse(json['entry_date'] as String),
    photoPath: json['photo_path'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    description: json['description'] as String?,
    totalGrams: json['total_grams'] as int?,
    failureCode: json['failure_code'] as String?,
    failureReason: json['failure_reason'] as String?,
    proposalJson: json['proposal_json'] as Map<String, dynamic>?,
  );

  final String id;
  final Meal meal;

  /// Día del diario (fecha local, sin hora).
  final DateTime entryDate;
  final String photoPath;
  final DateTime createdAt;
  final String? description;
  final int? totalGrams;

  /// `key_invalid`, `quota_exceeded`, `invalid_response`, `unrecognized`, `timeout`,
  /// `provider_unavailable`, `key_required`, `no_connection` o `interrupted`.
  final String? failureCode;
  final String? failureReason;
  final Map<String, dynamic>? proposalJson;

  bool get hasProposal => failureCode == null && proposalJson != null;

  PhotoAnalysisResult? get proposal =>
      proposalJson == null ? null : PhotoAnalysisResult.fromJson(proposalJson!);

  PhotoDraft withProposal(PhotoAnalysisResult result) => PhotoDraft(
    id: id,
    meal: meal,
    entryDate: entryDate,
    photoPath: photoPath,
    createdAt: createdAt,
    description: description,
    totalGrams: totalGrams,
    proposalJson: result.toJson(),
  );

  PhotoDraft withFailure(String code, [String? reason]) => PhotoDraft(
    id: id,
    meal: meal,
    entryDate: entryDate,
    photoPath: photoPath,
    createdAt: createdAt,
    description: description,
    totalGrams: totalGrams,
    failureCode: code,
    failureReason: reason,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'meal': meal.wire,
    'entry_date': entryDate.toIso8601String(),
    'photo_path': photoPath,
    'created_at': createdAt.toIso8601String(),
    'description': description,
    'total_grams': totalGrams,
    'failure_code': failureCode,
    'failure_reason': failureReason,
    'proposal_json': proposalJson,
  };
}
