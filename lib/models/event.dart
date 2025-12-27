import 'package:wari_can/models/common.dart';
import 'package:wari_can/models/expense.dart';
import 'package:wari_can/models/invite_link.dart';
import 'package:wari_can/models/menber.dart';

/// アプリの中心となるイベントデータを表すモデル。
///
/// [TimestampedEntity] を継承し、作成・更新日時を自動管理します。
/// 1つのイベントの中に、複数の参加者（Members）と、複数の支出（Expenses）が含まれます。
class Event extends TimestampedEntity {
  /// イベントを一意に識別するID（UUID）
  final String id;

  /// イベントのタイトル（例：「東京旅行」「飲み会」）
  String name;

  /// Firestore上の所有者UID。このUIDを持つユーザーのみが削除や名前変更などの特権を持ちます。
  final String ownerUid;

  /// 共有されたユーザーのUID一覧。ここにUIDが含まれるユーザーはイベントを閲覧・編集できます。
  final List<String> sharedWith;

  /// イベントの開催開始日（任意）
  DateTime? startDate;

  /// イベントの終了予定日（任意）
  DateTime? endDate;

  /// このイベントに参加しているメンバーのリスト。
  /// 精算の計算対象となる人物データが含まれます。
  List<Member> members;

  /// イベント内で発生したすべての支出明細（経費）のリスト。
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

  /// EventオブジェクトをMap（JSON）形式に変換します。
  /// Firestoreへの保存や、ローカルのSharedPreferencesへの書き出しに使用します。
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerUid': ownerUid,
    'sharedWith': sharedWith,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'members': members.map((m) => m.toJson()).toList(), // 子要素も再帰的にJSON化
    'details': details.map((e) => e.toJson()).toList(), // 子要素も再帰的にJSON化
    ...toTimestampJson(), // TimestampedEntity のメソッドを呼び出し
  };

  /// JSON形式のMapからEventオブジェクトを生成（復元）します。
  /// クラウドやローカルからのデータ読み込み時に使用します。
  static Event fromJson(Map<String, dynamic> json) => Event(
    id: json['id'],
    name: json['name'],
    // 互換性のため、nullの場合は空文字や空リストをデフォルト値として設定
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
    // タイムスタンプが取得できない場合は現在時刻をセット
    createAt: DateTime.tryParse(json['createAt'] ?? '') ?? DateTime.now(),
    updateAt: DateTime.tryParse(json['updateAt'] ?? '') ?? DateTime.now(),
  );
}

/// Eventクラスにイミュータブルな更新機能（copyWith）を追加する拡張。
extension EventCopy on Event {
  /// 現在のEventの状態を引き継ぎつつ、一部のプロパティのみを書き換えた新しいインスタンスを生成します。
  ///
  /// Flutterの状態管理（State Management）において、再描画を促すために
  /// インスタンスを新しく生成する際によく利用されます。
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
    InviteLink? inviteLink, // 引数としては受け取るが、現在はインスタンスに反映しない
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
