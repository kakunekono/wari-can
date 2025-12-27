import 'package:wari_can/models/common.dart';

/// イベントに参加する「人」を表すデータモデル。
///
/// [TimestampedEntity] を継承し、メンバーの追加日時や名前の変更日時を保持します。
/// この ID は、支出明細（Expense）の payer（支払者）や participants（参加者）として参照されます。
class Member extends TimestampedEntity {
  /// メンバーを一意に識別するID（UUID）。
  /// 支出データなどと紐付けるための不変な識別子です。
  final String id;

  /// メンバーの表示名（例：「たろう」「花子」）。
  /// UI上で誰の支出かを表示するために使用されます。
  String name;

  Member({
    required this.id,
    required this.name,
    required super.createAt,
    required super.updateAt,
  });

  /// MemberオブジェクトをMap（JSON）形式に変換します。
  /// イベントデータの一部としてFirestoreやローカルストレージに保存されます。
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    ...toTimestampJson(), // 基盤クラスのタイムスタンプを含める
  };

  /// JSONデータからMemberオブジェクトを復元します。
  ///
  /// 保存データにタイムスタンプがない場合は、整合性を保つため現在時刻をデフォルト値として使用します。
  static Member fromJson(Map<String, dynamic> json) => Member(
    id: json['id'],
    name: json['name'],
    createAt: DateTime.tryParse(json['createAt'] ?? '') ?? DateTime.now(),
    updateAt: DateTime.tryParse(json['updateAt'] ?? '') ?? DateTime.now(),
  );
}

/// Memberクラスにイミュータブルなコピー機能を提供する拡張。
extension MemberCopy on Member {
  /// 現在のメンバー情報を引き継ぎつつ、一部の値を変更した新しいインスタンスを生成します。
  ///
  /// 主にメンバー名の編集時や、データの複製（コピー作成）時に利用されます。
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
