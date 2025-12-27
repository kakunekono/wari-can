import 'package:wari_can/models/common.dart';

/// 支出の分割方法を定義する列挙型。
enum SplitMode {
  /// 手動：各メンバーの負担額を個別に指定するモード。
  manual,

  /// 均等：合計金額を参加人数で等しく割るモード。
  equal,
}

/// 支出明細（経費項目）を表すデータモデル。
///
/// [TimestampedEntity] を継承し、明細の作成・更新日時を保持します。
/// どのメンバーが支払い、どのメンバーがその費用を負担するかという情報を管理します。
class Expense extends TimestampedEntity {
  /// 明細を一意に識別するID（UUID）
  final String id;

  /// 支出の内容（例：「晩ごはん代」「レンタカー代」）
  String item;

  /// 実際に代金を支払ったメンバーのID
  String payer;

  /// 支出の総額（円）
  int amount;

  /// この支出の対象となる（恩恵を受ける）メンバーのID一覧
  List<String> participants;

  /// メンバーごとの負担額を保持するマップ。
  /// キー: メンバーID, 値: その人の負担金額
  Map<String, int> shares;

  /// 分割の計算方式。デフォルトは [SplitMode.manual]
  SplitMode mode;

  /// 支払日（任意）。UI表示用の文字列形式。
  String? payDate;

  Expense({
    required this.id,
    required this.item,
    required this.payer,
    required this.amount,
    required this.participants,
    required this.shares,
    this.mode = SplitMode.manual,
    this.payDate,
    required super.createAt,
    required super.updateAt,
  });

  /// ExpenseオブジェクトをMap（JSON）形式に変換します。
  /// Firestoreの `details` 配列やローカルストレージへの保存に使用します。
  Map<String, dynamic> toJson() => {
    'id': id,
    'item': item,
    'payer': payer,
    'amount': amount,
    'participants': participants,
    // 負担額データがある場合のみ出力し、空の場合はnullとして扱う
    'shares': shares.isNotEmpty ? shares : null,
    'mode': mode.name,
    'payDate': payDate,
    ...toTimestampJson(),
  };

  /// JSONデータからExpenseオブジェクトを復元します。
  static Expense fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'],
    item: json['item'],
    payer: json['payer'],
    amount: json['amount'],
    // 動的リストをString型リストとして安全にキャスト
    participants: List<String>.from(json['participants'] ?? []),
    // shares Map を Map<String, int> として復元
    shares: json['shares'] != null ? Map<String, int>.from(json['shares']) : {},
    // 文字列から Enum (SplitMode) への変換処理
    mode: SplitMode.values.firstWhere(
      (e) =>
          e.name == json['mode'] ||
          // 完全修飾名（SplitMode.equalなど）で保存されている場合にも対応
          json['mode']?.endsWith('.${e.name}') == true,
      orElse: () => SplitMode.manual,
    ),
    payDate: json['payDate'],
    // 基盤クラスのタイムスタンプをパース
    createAt: DateTime.tryParse(json['createAt'] ?? '') ?? DateTime.now(),
    updateAt: DateTime.tryParse(json['updateAt'] ?? '') ?? DateTime.now(),
  );
}

/// Expenseクラスの不変性を保ちつつ、一部の値を変更したコピーを作成するための拡張。
extension ExpenseCopy on Expense {
  /// 現在の明細データをもとに、指定したフィールドのみを更新した新しいインスタンスを返します。
  ///
  /// 支払い金額を変更した際の再計算後や、項目の編集時に使用します。
  Expense copyWith({
    String? id,
    String? item,
    String? payer,
    int? amount,
    List<String>? participants,
    Map<String, int>? shares,
    SplitMode? mode,
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
