import 'package:cloud_firestore/cloud_firestore.dart';

/// イベントへの招待リンク（共有用トークン）を表すモデル。
///
/// 特定のイベントに他ユーザーを招待する際に生成され、
/// 受信したユーザーはこのトークンを介してイベントへのアクセス権を取得します。
class InviteLink {
  /// 招待リンクを識別するための固有トークン（UUIDなど）。
  /// 招待URLのパラメータ（例: /join?token=xxxx）として利用されます。
  final String token;

  /// 招待されたユーザーに付与する権限スコープ。
  /// 例: "editor"（編集可能）, "viewer"（閲覧のみ）など。
  final String role;

  /// リンクが生成された日時。
  /// 有効期限（例：生成から24時間以内など）を判定する際に使用します。
  final DateTime createdAt;

  /// リンクの有効状態フラグ。
  /// 管理者がリンクを無効化（削除せずに一時停止）した場合などに false となります。
  bool active;

  InviteLink({
    required this.token,
    required this.role,
    required this.createdAt,
    this.active = true,
  });

  /// Firestoreのドキュメント（Map）から InviteLink オブジェクトを生成します。
  ///
  /// Firestore特有の [Timestamp] 型を Dart の [DateTime] 型に変換する処理を含みます。
  factory InviteLink.fromJson(Map<String, dynamic> json) {
    return InviteLink(
      token: json['token'] as String,
      role: json['role'] as String,
      // Firestoreから取得した Timestamp を DateTime に変換
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      active: json['active'] as bool? ?? true,
    );
  }

  /// InviteLink オブジェクトを Firestore 保存用の Map 形式に変換します。
  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'role': role,
      // Dart の DateTime を Firestore の Timestamp 形式に変換して保存
      'createdAt': Timestamp.fromDate(createdAt),
      'active': active,
    };
  }
}
