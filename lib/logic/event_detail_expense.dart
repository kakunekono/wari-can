import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:wari_can/models/event.dart';
import 'package:wari_can/models/expense.dart';
import 'package:wari_can/models/settlement_report.dart';
import 'package:wari_can/pages/event_detail_expense_input.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
import 'package:wari_can/utils/utils.dart';
import 'event_detail_logic.dart';

/// 支出明細の追加・編集・削除、および入力ダイアログの表示を行うロジック群。
///
/// 編集はローカルで完結し、保存時にのみ Firebase へ同期されます。

/// 支出明細を追加または編集します。
Future<void> addExpense(
  BuildContext context,
  Event event, {
  Expense? editExpense,
  int? editIndex,
  required void Function(Event updated) onUpdate,
}) async {
  // メンバーがいない状態での支出登録を防止
  if (event.members.isEmpty) {
    showAppSnackBar(
      context,
      message: 'メンバーを先に登録してください',
      type: SnackBarType.error,
    );
    return;
  }

  // 入力ダイアログを表示（ボトムシート形式）
  final result = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true, // キーボード表示時にコンテンツが隠れないよう調整
    backgroundColor: Colors.transparent, // ダイアログ側の角丸デザインを透過させて活かす
    builder: (_) =>
        ExpenseInputDialog(members: event.members, editExpense: editExpense),
  );
  if (result == null) return;

  // 負担額が設定されているメンバーのみを参加者として抽出
  final shares = Map<String, int>.from(result['shares']);
  final participants = shares.entries
      .where((e) => e.value > 0)
      .map((e) => e.key)
      .toList();
  if (participants.isEmpty) return;

  final payerId = result['payerId'] ?? '';
  if (payerId.isEmpty) return;

  final now = DateTime.now();

  // 新しい支出オブジェクトの生成（編集時は既存IDと作成日時を維持）
  final newExpense = Expense(
    id: editExpense?.id ?? const Uuid().v4(),
    item: result['item'] ?? "支出${event.details.length + 1}",
    payer: payerId,
    amount: result['total'] ?? 0,
    participants: participants,
    shares: shares,
    mode: result['mode'] ?? SplitMode.manual,
    payDate: result['payDate'],
    createAt: editExpense?.createAt ?? now,
    updateAt: now,
  );

  final updatedDetails = [...event.details];
  if (editIndex != null) {
    // 編集：指定インデックスの要素を差し替え
    updatedDetails[editIndex] = newExpense;
  } else {
    // 新規：末尾に追加
    updatedDetails.add(newExpense);
  }

  // 常に定義された順序（支払者名・日付順など）でソートして整合性を保つ
  final sortedDetails = sortDetails(updatedDetails, event.members);
  final updated = event.copyWith(details: sortedDetails, updateAt: now);
  onUpdate(updated);
}

/// 支出明細を削除します。
Future<void> deleteExpense(
  BuildContext context,
  Event event,
  int index, {
  required void Function(Event updated) onUpdate,
}) async {
  final expense = event.details[index];

  // 誤操作防止の削除確認
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("確認"),
      content: Text("「${expense.item}」を削除しますか？"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("キャンセル"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text("削除"),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  // リストから対象を削除してソート
  final updatedDetails = List<Expense>.from(event.details)..removeAt(index);
  final sortedDetails = sortDetails(updatedDetails, event.members);
  final now = DateTime.now();
  final updated = event.copyWith(details: sortedDetails, updateAt: now);
  onUpdate(updated);

  showAppSnackBar(
    context,
    message: '「${expense.item}」を削除しました',
    type: SnackBarType.info,
  );
}

/// 支出明細一覧セクションのUIを構築します。
///
/// 内部で [SettlementReport] を計算することで、
/// 「均等割りにおける端数調整後の正確な負担額」を各カードに表示できるようにしています。
Widget buildExpenseSection(
  BuildContext context,
  Event event, {
  required void Function(Event updated) onUpdate,
  required bool isLockedByMe,
}) {
  // 🚩 表示用に最新の精算レポート（負担内訳を含む）を算出
  final report = SettlementReport.calculate(event);

  // メンバーの並び順に従ってグループ化表示
  final memberOrder = event.members.map((m) => m.id).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ...memberOrder.expand((memberId) {
        final memberName = Utils.memberName(memberId, event.members);

        // この支払者に関連する明細の「計算済み内訳」を抽出
        final memberBreakdowns = report.breakdowns
            .where((b) => b.expense.payer == memberId)
            .toList();

        // 該当する支出がないメンバーのセクションは表示しない
        if (memberBreakdowns.isEmpty) return <Widget>[];

        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              "💳 $memberName",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          ),
          ...memberBreakdowns.map((breakdown) {
            final e = breakdown.expense;
            // 元のリストにおけるインデックスを特定（操作時に必要）
            final actualIndex = event.details.indexOf(e);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.item,
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 分割モード（手動/均等）をアイコンで視覚化
                    Icon(
                      breakdown.isManual ? Icons.tune : Icons.balance,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.payDate != null && e.payDate!.isNotEmpty)
                        Text("支払日: ${e.payDate}"),
                      Text("合計金額: ${Utils.formatAmount(e.amount)}"),
                      const SizedBox(height: 4),

                      // 🚩 負担内訳の表示エリア
                      // 「手動入力」または「一部のメンバーのみ参加」の場合は詳細リストを表示
                      if (breakdown.isManual || breakdown.isPartial) ...[
                        const Text(
                          "負担内訳:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        ...breakdown.memberShares.map(
                          (share) => Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              "・${share.memberName}: ${Utils.formatAmount(share.amount)}",
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ] else ...[
                        // 全員均等の場合は「1人あたり」の単価を表示
                        const Text(
                          "負担金額:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Builder(
                            builder: (context) {
                              // 平均額の算出（UI上は小数第2位まで表示して正確性を伝える）
                              final average = e.participants.isNotEmpty
                                  ? e.amount / e.participants.length
                                  : 0.0;
                              final formattedAvg = average.toStringAsFixed(2);

                              return Text(
                                "・1人あたり ${Utils.formatStrAmount(formattedAvg)}",
                                style: const TextStyle(fontSize: 13),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 自分が編集権限（ロック）を持っている場合のみ操作ボタンを表示
                trailing: isLockedByMe
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => addExpense(
                              context,
                              event,
                              editExpense: e,
                              editIndex: actualIndex,
                              onUpdate: onUpdate,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deleteExpense(
                              context,
                              event,
                              actualIndex,
                              onUpdate: onUpdate,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            );
          }),
        ];
      }),
    ],
  );
}
