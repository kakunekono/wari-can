import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:wari_can/models/event.dart';
import 'package:wari_can/models/expense.dart';
import 'package:wari_can/pages/event_detail_expense_input.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
import 'package:wari_can/utils/utils.dart';
import 'event_detail_logic.dart';

/// 支出明細の追加・編集・削除、および入力ダイアログの表示を行うロジック群。
///
/// 編集はローカルで完結し、保存時にのみ Firebase へ同期されます。

/// 支出明細を追加または編集します。
///
/// - [editExpense] が指定されていれば編集モードとして動作します。
/// - [editIndex] が指定されていれば既存明細を置き換えます。
/// - 入力ダイアログで取得した情報を元に明細を構築し、イベントに追加または更新します。
Future<void> addExpense(
  BuildContext context,
  Event event, {
  Expense? editExpense,
  int? editIndex,
  required void Function(Event updated) onUpdate,
}) async {
  if (event.members.isEmpty) {
    showAppSnackBar(
      context,
      message: 'メンバーを先に登録してください',
      type: SnackBarType.error,
    );
    return;
  }

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) =>
        ExpenseInputDialog(members: event.members, editExpense: editExpense),
  );
  if (result == null) return;

  final shares = Map<String, int>.from(result['shares']);
  final participants = shares.entries
      .where((e) => e.value > 0)
      .map((e) => e.key)
      .toList();
  if (participants.isEmpty) return;

  final payerId = result['payerId'] ?? '';
  if (payerId.isEmpty) return;

  final now = DateTime.now();
  final newExpense = Expense(
    id: editExpense?.id ?? const Uuid().v4(),
    item: result['item'] ?? "支出${event.details.length + 1}",
    payer: payerId,
    amount: result['total'] ?? 0,
    participants: participants,
    shares: shares,
    mode: result['mode'] ?? "manual",
    payDate: result['payDate'],
    createAt: editExpense?.createAt ?? now,
    updateAt: now,
  );

  final updatedDetails = [...event.details];
  if (editIndex != null) {
    updatedDetails[editIndex] = newExpense;
  } else {
    updatedDetails.add(newExpense);
  }

  final sortedDetails = sortDetails(updatedDetails, event.members);
  final updated = event.copyWith(details: sortedDetails, updateAt: now);
  onUpdate(updated);
}

/// 支出明細を削除します。
///
/// - 削除確認ダイアログを表示し、承認された場合のみ削除します。
/// - 削除後はローカル保存と Firebase 同期を行います。
Future<void> deleteExpense(
  BuildContext context,
  Event event,
  int index, {
  required void Function(Event updated) onUpdate,
}) async {
  final expense = event.details[index];

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
/// - 支払者ごとにグループ化された明細を表示します。
/// - 各明細には編集・削除ボタンが付属します。
/// - 他人がロック中の場合は編集・削除ボタンを非表示にします。
Widget buildExpenseSection(
  BuildContext context,
  Event event, {
  required void Function(Event updated) onUpdate,
  required bool isLockedByMe, // ✅ ロック判定を外から渡す
}) {
  final memberOrder = event.members.map((m) => m.id).toList();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      /// 支払者ごとに明細をグループ化して表示
      ...memberOrder.expand((memberId) {
        final memberName = Utils.memberName(memberId, event.members);
        // このメンバーの明細を抽出
        final memberDetails =
            event.details.where((d) => d.payer == memberId).toList()..sort((
              a,
              b,
            ) {
              // 同じメンバー内では日付→項目名でソート
              final dateCompare = (a.payDate ?? '').compareTo(b.payDate ?? '');
              if (dateCompare != 0) return dateCompare;
              return a.item.compareTo(b.item);
            });

        if (memberDetails.isEmpty) return <Widget>[];

        final widgets = <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "💳 $memberName",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          ),
        ];

        for (var i = 0; i < memberDetails.length; i++) {
          final e = memberDetails[i];

          // modeが'equal'なら全員参加なので、個別リストは表示しない
          // modeが'manual'なら選択されたメンバーを表示する
          //final showParticipants = e.mode != "equal";

          // もしくは、より明示的に書く場合
          final showParticipants = (e.mode == "manual");

          widgets.add(
            Card(
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
                    Icon(
                      e.mode == "manual" ? Icons.tune : Icons.balance,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ],
                ),
                subtitle: Text(
                  [
                    "支払者: $memberName",
                    if (e.payDate != null && e.payDate!.isNotEmpty)
                      "支払日: ${e.payDate}",
                    "支払金額: ${Utils.formatAmount(e.amount)}円",
                    "負担金額:",
                    if (showParticipants) ...[
                      for (final m in event.members)
                        if ((e.shares[m.id] ?? 0) > 0)
                          "  ${m.name} -> ${Utils.formatAmount(e.shares[m.id]!)}円",
                    ] else
                      " ${Utils.formatAmount(e.amount / memberDetails.length)}円",
                  ].join('\n'),
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (isLockedByMe) ...[
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => addExpense(
                          context,
                          event,
                          editExpense: e,
                          editIndex: event.details.indexOf(e),
                          onUpdate: onUpdate,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteExpense(
                          context,
                          event,
                          event.details.indexOf(e),
                          onUpdate: onUpdate,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return widgets;
      }),
    ],
  );
}
