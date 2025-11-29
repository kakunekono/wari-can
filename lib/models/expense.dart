import 'package:wari_can/models/common.dart';

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
