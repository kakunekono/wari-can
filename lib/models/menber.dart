import 'package:wari_can/models/common.dart';

/// メンバー情報を表すモデル。
class Member extends TimestampedEntity {
  /// メンバーID（UUID）
  final String id;

  /// メンバー名
  String name;

  Member({
    required this.id,
    required this.name,
    required super.createAt,
    required super.updateAt,
  });

  /// JSON形式に変換
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    ...toTimestampJson(),
  };

  /// JSONからMemberを生成
  static Member fromJson(Map<String, dynamic> json) => Member(
    id: json['id'],
    name: json['name'],
    createAt: DateTime.tryParse(json['createAt'] ?? '') ?? DateTime.now(),
    updateAt: DateTime.tryParse(json['updateAt'] ?? '') ?? DateTime.now(),
  );
}

/// Memberのイミュータブルなコピーを作成するための拡張。
extension MemberCopy on Member {
  Member copyWith({
    String? id,
    String? name,
    DateTime? createAt,
    DateTime? updateAt,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      createAt: createAt ?? this.createAt,
      updateAt: updateAt ?? this.updateAt,
    );
  }
}
