/// Respuesta de `GET /v1/me` y `POST /v1/registration` (contracts/openapi.yaml `Me`).
class Me {
  const Me({
    required this.id,
    required this.displayName,
    required this.isAdmin,
    required this.active,
  });

  factory Me.fromJson(Map<String, dynamic> json) => Me(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        isAdmin: json['is_admin'] as bool,
        active: json['status'] == 'active',
      );

  final String id;
  final String displayName;
  final bool isAdmin;
  final bool active;
}

/// `InvitationStatus` del contrato.
class InvitationStatus {
  const InvitationStatus({
    required this.code,
    required this.activeAccounts,
    required this.maxAccounts,
    required this.freeSeats,
  });

  factory InvitationStatus.fromJson(Map<String, dynamic> json) => InvitationStatus(
        code: json['code'] as String?,
        activeAccounts: json['active_accounts'] as int,
        maxAccounts: json['max_accounts'] as int,
        freeSeats: json['free_seats'] as int,
      );

  /// Sin guion; la pantalla lo muestra como `ABCD-EFGH`.
  final String? code;
  final int activeAccounts;
  final int maxAccounts;
  final int freeSeats;

  String? get displayCode {
    final c = code;
    if (c == null || c.length != 8) return c;
    return '${c.substring(0, 4)}-${c.substring(4)}';
  }
}
