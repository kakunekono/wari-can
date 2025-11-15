// ----------------------
// データ構造
// ----------------------
abstract class TimestampedEntity {
  final DateTime createAt;
  final DateTime updateAt;

  const TimestampedEntity({required this.createAt, required this.updateAt});

  Map<String, dynamic> toTimestampJson() => {
    'createAt': createAt.toIso8601String(),
    'updateAt': updateAt.toIso8601String(),
  };

  /// 新規作成用のタイムスタンプを生成
  static Map<String, DateTime> newTimestamps() {
    final now = DateTime.now();
    return {'createAt': now, 'updateAt': now};
  }

  /// 更新用のタイムスタンプを生成
  static Map<String, DateTime> updatedTimestamp({
    required DateTime originalCreateAt,
  }) {
    return {'createAt': originalCreateAt, 'updateAt': DateTime.now()};
  }
}

// abstract class TimestampedEntity {
//   final DateTime createAt;
//   final DateTime updateAt;

//   TimestampedEntity({DateTime? createAt, DateTime? updateAt})
//     : createAt = createAt ?? DateTime.now(),
//       updateAt = updateAt ?? DateTime.now();

//   Map<String, dynamic> toTimestampJson() => {
//     'createAt': createAt.toIso8601String(),
//     'updateAt': updateAt.toIso8601String(),
//   };

//   /// 新規作成用のタイムスタンプを生成
//   static Map<String, DateTime> newTimestamps() {
//     final now = DateTime.now();
//     return {'createAt': now, 'updateAt': now};
//   }

//   /// 更新用のタイムスタンプを生成
//   static Map<String, DateTime> updatedTimestamp({
//     required DateTime originalCreateAt,
//   }) {
//     return {'createAt': originalCreateAt, 'updateAt': DateTime.now()};
//   }
// }

class Event extends TimestampedEntity {
  final String id;
  String name;
  DateTime? startDate;
  DateTime? endDate;
  List<Member> members; // ← 文字列ではなく Member 型に
  List<Expense> details;

  Event({
    required this.id,
    required this.name,
    this.startDate,
    this.endDate,
    List<Member>? members,
    List<Expense>? details,
    required super.createAt,
    required super.updateAt,
  }) : members = members ?? [],
       details = details ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'members': members.map((m) => m.toJson()).toList(),
    'details': details.map((e) => e.toJson()).toList(),
    ...toTimestampJson(),
  };

  static Event fromJson(Map<String, dynamic> json) => Event(
    id: json['id'],
    name: json['name'],
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

extension EventCopy on Event {
  Event copyWith({
    String? id,
    String? name,
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
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      members: members ?? this.members,
      details: details ?? this.details,
      createAt: createAt ?? this.createAt,
      updateAt: updateAt ?? this.updateAt,
    );
  }
}

class Member extends TimestampedEntity {
  final String id;
  String name;

  Member({
    required this.id,
    required this.name,
    required super.createAt,
    required super.updateAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    ...toTimestampJson(),
  };

  static Member fromJson(Map<String, dynamic> json) => Member(
    id: json['id'],
    name: json['name'],
    createAt: DateTime.tryParse(json['createAt'] ?? '') ?? DateTime.now(),
    updateAt: DateTime.tryParse(json['updateAt'] ?? '') ?? DateTime.now(),
  );
}

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

class Expense extends TimestampedEntity {
  final String id;
  String item;
  String payer;
  int amount;
  List<String> participants;
  Map<String, int> shares;
  String mode;
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
