// ----------------------
// データ構造
// ----------------------
class Event {
  final String id;
  String name; // ← 編集可能に変更
  DateTime? startDate;
  DateTime? endDate;
  List<String> members; // ← 編集可能に変更
  List<Expense> details; // ← 編集可能に変更

  Event({
    required this.id,
    required this.name,
    this.startDate,
    this.endDate,
    List<String>? members,
    List<Expense>? details,
  }) : members = members ?? [],
       details = details ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'members': members,
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
    members: List<String>.from(json['members'] ?? []),
    details:
        (json['details'] as List<dynamic>?)
            ?.map((e) => Expense.fromJson(e))
            .toList() ??
        [],
  );
}

class Expense {
  String item;
  String payer;
  int amount;
  List<String> participants;

  Expense({
    required this.item,
    required this.payer,
    required this.amount,
    required this.participants,
  });

  Map<String, dynamic> toJson() => {
    'item': item,
    'payer': payer,
    'amount': amount,
    'participants': participants,
  };

  static Expense fromJson(Map<String, dynamic> json) => Expense(
    item: json['item'],
    payer: json['payer'],
    amount: json['amount'],
    participants: List<String>.from(json['participants'] ?? []),
  );
}
