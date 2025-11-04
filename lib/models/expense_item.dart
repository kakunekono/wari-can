class ExpenseItem {
  final String item;
  final String payer;
  final int amount;
  final List<String> participants;

  ExpenseItem({
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

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      item: json['item'] ?? '',
      payer: json['payer'] ?? '',
      amount: json['amount'] ?? 0,
      participants: List<String>.from(json['participants'] ?? []),
    );
  }
}
