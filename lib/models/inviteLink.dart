import 'package:cloud_firestore/cloud_firestore.dart';

/// 招待リンクを表すモデル。
class InviteLink {
  /// 招待リンクのトークン（UUIDなど）
  final String token;

  /// 権限スコープ（例: "editor", "viewer"）
  final String role;

  /// 作成日時
  final DateTime createdAt;

  /// 有効フラグ（falseなら無効化済み）
  bool active;

  InviteLink({
    required this.token,
    required this.role,
    required this.createdAt,
    this.active = true,
  });

  factory InviteLink.fromJson(Map<String, dynamic> json) {
    return InviteLink(
      token: json['token'] as String,
      role: json['role'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'active': active,
    };
  }
}
