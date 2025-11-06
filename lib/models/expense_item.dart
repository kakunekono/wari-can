class ExpenseItem {
  String item;
  String payer;
  int amount;
  List<String> participants;

  ExpenseItem({
    required this.item,
    required this.payer,
    required this.amount,
    required this.participants,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
    item: json['item'],
    payer: json['payer'],
    amount: json['amount'],
    participants: List<String>.from(json['participants']),
  );

  Map<String, dynamic> toJson() => {
    'item': item,
    'payer': payer,
    'amount': amount,
    'participants': participants,
  };
}
