import 'package:wari_can/models/common.dart';
import 'package:wari_can/models/expense.dart';
import 'package:wari_can/models/invite_link.dart';
import 'package:wari_can/models/menber.dart';

/// イベントデータを表すモデル。
class Event extends TimestampedEntity {
  /// イベントID（UUID）
  final String id;

  /// イベント名
  String name;

  /// 作成者
  final String ownerUid;

  /// 共有メンバーのUID一覧
  final List<String> sharedWith;

  /// 開始日（任意）
  DateTime? startDate;

  /// 終了日（任意）
  DateTime? endDate;

  /// 参加メンバー一覧
  List<Member> members;

  /// 支出明細一覧
  List<Expense> details;

  Event({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.sharedWith,
    this.startDate,
    this.endDate,
    this.members = const [],
    this.details = const [],
    required super.createAt,
    required super.updateAt,
  });

  /// JSON形式に変換
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerUid': ownerUid,
    'sharedWith': sharedWith,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'members': members.map((m) => m.toJson()).toList(),
    'details': details.map((e) => e.toJson()).toList(),
    ...toTimestampJson(),
  };

  /// JSONからEventを生成
  static Event fromJson(Map<String, dynamic> json) => Event(
    id: json['id'],
    name: json['name'],
    ownerUid: json['ownerUid'] ?? '',
    sharedWith: (json['sharedWith'] as List<dynamic>?)?.cast<String>() ?? [],
    startDate: json['startDate'] != null
        ? DateTime.tryParse(json['startDate'])
        : null,
    endDate: json['endDate'] != null
        ? DateTime.tryParse(json['endDate'])
        : null,
    members:
        (json['members'] as List<dynamic>?)
            ?.map((m) => Member.fromJson(m))
            .toList() ??
        [],
    details:
        (json['details'] as List<dynamic>?)
            ?.map((e) => Expense.fromJson(e))
            .toList() ??
        [],
    createAt: DateTime.tryParse(json['createAt'] ?? '') ?? DateTime.now(),
    updateAt: DateTime.tryParse(json['updateAt'] ?? '') ?? DateTime.now(),
  );
}

/// Eventのイミュータブルなコピーを作成するための拡張。
extension EventCopy on Event {
  Event copyWith({
    String? id,
    String? name,
    String? ownerUid,
    List<String>? sharedWith,
    DateTime? startDate,
    DateTime? endDate,
    List<Member>? members,
    List<Expense>? details,
    DateTime? createAt,
    DateTime? updateAt,
    InviteLink? inviteLink,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerUid: ownerUid ?? this.ownerUid,
      sharedWith: sharedWith ?? this.sharedWith,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      members: members ?? this.members,
      details: details ?? this.details,
      createAt: createAt ?? this.createAt,
      updateAt: updateAt ?? this.updateAt,
    );
  }
}
