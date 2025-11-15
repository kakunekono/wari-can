/// タイムスタンプ付きエンティティの抽象クラス。
/// createAt（作成日時）と updateAt（更新日時）を共通で持つ。
abstract class TimestampedEntity {
  /// 作成日時
  final DateTime createAt;

  /// 更新日時
  final DateTime updateAt;

  const TimestampedEntity({required this.createAt, required this.updateAt});

  /// タイムスタンプをJSON形式に変換する。
  Map<String, dynamic> toTimestampJson() => {
    'createAt': createAt.toIso8601String(),
    'updateAt': updateAt.toIso8601String(),
  };

  /// 新規作成用のタイムスタンプを生成する。
  static Map<String, DateTime> newTimestamps() {
    final now = DateTime.now();
    return {'createAt': now, 'updateAt': now};
  }

  /// 更新時のタイムスタンプを生成する。
  static Map<String, DateTime> updatedTimestamp({
    required DateTime originalCreateAt,
  }) {
    return {'createAt': originalCreateAt, 'updateAt': DateTime.now()};
  }
}

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
    List<Member>? members,
    List<Expense>? details,
    required super.createAt,
    required super.updateAt,
  }) : members = members ?? [],
       details = details ?? [];

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

/// 支出明細を表すモデル。
class Expense extends TimestampedEntity {
  /// 明細ID（UUID）
  final String id;

  /// 支出項目名
  String item;

  /// 支払者のメンバーID
  String payer;

  /// 金額（円）
  int amount;

  /// 参加者のメンバーID一覧
  List<String> participants;

  /// 各メンバーの負担額（memberId → 金額）
  Map<String, int> shares;

  /// 分割モード（"manual" または "equal"）
  String mode;

  /// 支払日（任意、文字列）
  String? payDate;

  Expense({
    required this.id,
    required this.item,
    required this.payer,
    required this.amount,
    required this.participants,
    required this.shares,
    this.mode = "manual",
    this.payDate,
    required super.createAt,
    required super.updateAt,
  });

  /// JSON形式に変換
  Map<String, dynamic> toJson() => {
    'id': id,
    'item': item,
    'payer': payer,
    'amount': amount,
    'participants': participants,
    'shares': shares.isNotEmpty ? shares : null,
    'mode': mode != "manual" ? mode : null,
    'payDate': payDate,
    ...toTimestampJson(),
  };

  /// JSONからExpenseを生成
  static Expense fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'],
    item: json['item'],
    payer: json['payer'],
    amount: json['amount'],
    participants: List<String>.from(json['participants'] ?? []),
    shares: json['shares'] != null ? Map<String, int>.from(json['shares']) : {},
    mode: json['mode'] ?? "manual",
    payDate: json['payDate'],
    createAt: DateTime.tryParse(json['createAt'] ?? '') ?? DateTime.now(),
    updateAt: DateTime.tryParse(json['updateAt'] ?? '') ?? DateTime.now(),
  );
}

/// Expenseのイミュータブルなコピーを作成するための拡張。
extension ExpenseCopy on Expense {
  Expense copyWith({
    String? id,
    String? item,
    String? payer,
    int? amount,
    List<String>? participants,
    Map<String, int>? shares,
    String? mode,
    String? payDate,
    DateTime? createAt,
    DateTime? updateAt,
  }) {
    return Expense(
      id: id ?? this.id,
      item: item ?? this.item,
      payer: payer ?? this.payer,
      amount: amount ?? this.amount,
      participants: participants ?? this.participants,
      shares: shares ?? this.shares,
      mode: mode ?? this.mode,
      payDate: payDate ?? this.payDate,
      createAt: createAt ?? this.createAt,
      updateAt: updateAt ?? this.updateAt,
    );
  }
}
