// ----------------------
// データ構造
// ----------------------
class Event {
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
  }) : members = members ?? [],
       details = details ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'members': members.map((m) => m.toJson()).toList(),
    'details': details.map((e) => e.toJson()).toList(),
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
  );
}

class Member {
  final String id;
  String name;

  Member({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  static Member fromJson(Map<String, dynamic> json) =>
      Member(id: json['id'], name: json['name']);
}

class Expense {
  final String id;
  String item;
  String payer;
  int amount;
  List<String> participants;
  Map<String, int> shares; // 各メンバー負担額
  String mode; // "equal" | "manual"
  DateTime? payDate;

  Expense({
    required this.id,
    required this.item,
    required this.payer,
    required this.amount,
    required this.participants,
    required this.shares,
    this.mode = "manual",
    this.payDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'item': item,
    'payer': payer,
    'amount': amount,
    'participants': participants,
    // 以下を追加
    'shares': shares.isNotEmpty ? shares : null,
    'mode': mode != "manual" ? mode : null,
    'payDate': payDate,
  };

  static Expense fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'],
    item: json['item'],
    payer: json['payer'],
    amount: json['amount'],
    participants: List<String>.from(json['participants'] ?? []),
    shares: json['shares'] != null
        ? Map<String, int>.from(json['shares'])
        : {}, // ← 既存データに shares がなければ空の Map に
    mode: json['mode'] ?? "manual", // ← 既存データに mode がなければ "manual"
    payDate: json['payDate'],
  );
}
