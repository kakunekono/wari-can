import 'package:flutter/material.dart';
import 'package:wari_can/models/event.dart';
import 'package:wari_can/models/expense.dart';
import 'package:wari_can/models/menber.dart';
import 'package:wari_can/models/settlement_report.dart';
import 'package:wari_can/utils/exception_utils.dart';
import 'package:wari_can/utils/firestore_helper.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
import 'package:wari_can/utils/utils.dart';

/// 支出明細を【支払者名】→【支払日】→【項目名】の順でソートします。
List<Expense> sortDetails(List<Expense> details, List<Member> members) {
  final sorted = [...details];
  sorted.sort((a, b) {
    // 1. 支払者名で比較
    final aName = Utils.memberName(a.payer, members);
    final bName = Utils.memberName(b.payer, members);
    final payerCompare = aName.compareTo(bName);
    if (payerCompare != 0) return payerCompare;

    // 2. 支払日で比較（未入力は後ろへ）
    final aDate = a.payDate;
    final bDate = b.payDate;
    if (aDate == null && bDate != null) return 1;
    if (aDate != null && bDate == null) return -1;
    if (aDate != null && bDate != null) {
      final dateCompare = aDate.compareTo(bDate);
      if (dateCompare != 0) return dateCompare;
    }

    // 3. 項目名で比較
    return a.item.compareTo(b.item);
  });
  return sorted;
}

/// 支払合計（単純集計）を計算します。
Map<String, int> calcPaidTotals(List<Expense> details, List<Member> members) {
  final totals = <String, int>{};
  for (final e in details) {
    totals[e.payer] = (totals[e.payer] ?? 0) + e.amount;
  }
  for (final m in members) {
    totals[m.id] = totals[m.id] ?? 0;
  }
  return totals;
}

/// 精算後残高を計算します（支払額 - 負担額）。
/// ※ SettlementReport.calculate 内で同様の計算を行っていますが、単体計算用として維持。
Map<String, int> calcTotals(List<Expense> details, List<Member> members) {
  final totals = <String, int>{};
  final owes = <String, int>{};

  for (final e in details) {
    totals[e.payer] = (totals[e.payer] ?? 0) + e.amount;

    if (e.mode == SplitMode.manual && e.shares.isNotEmpty) {
      // 手動モード
      e.shares.forEach((memberId, share) {
        owes[memberId] = (owes[memberId] ?? 0) + share;
      });
    } else {
      // 均等モード（端数は支払者が負担）
      if (e.participants.isEmpty) continue;
      final per = e.amount ~/ e.participants.length;
      final remainder = e.amount % e.participants.length;
      for (final pid in e.participants) {
        owes[pid] = (owes[pid] ?? 0) + per + (pid == e.payer ? remainder : 0);
      }
    }
  }

  final balances = <String, int>{};
  for (final m in members) {
    balances[m.id] = (totals[m.id] ?? 0) - (owes[m.id] ?? 0);
  }
  return balances;
}

/// 負担合計（sharesベース）を計算します。
Map<String, int> memberShareTotalsFunc(List<Expense> details) {
  final totals = <String, int>{};
  for (final e in details) {
    e.shares.forEach((memberId, amount) {
      totals[memberId] = (totals[memberId] ?? 0) + amount;
    });
  }
  return totals;
}

/// イベントの内容をテキスト形式（LINEやメール共有用）で整形します。
String buildShareText(Event event) {
  final report = SettlementReport.calculate(event);
  final buffer = StringBuffer();
  const splitter = "――――――――――――――――――";

  buffer.writeln("📅 イベント名: ${event.name}\n");
  buffer.writeln("👥 メンバー一覧");
  for (final m in event.members) {
    buffer.writeln("・${m.name}");
  }

  buffer.writeln("\n$splitter");
  buffer.writeln("💰 支出明細");

  for (final m in event.members) {
    final memberBreakdowns = report.breakdowns
        .where((b) => b.expense.payer == m.id)
        .toList();
    if (memberBreakdowns.isEmpty) continue;

    buffer.writeln("\n💳 ${m.name}");
    for (final b in memberBreakdowns) {
      final e = b.expense;
      buffer.writeln("・${e.item}（${Utils.formatAmount(e.amount)}）");

      if (b.isManual || b.isPartial) {
        buffer.writeln("  負担内訳:");
        for (final s in b.memberShares) {
          buffer.writeln(
            "    ・${s.memberName}: ${Utils.formatAmount(s.amount)}",
          );
        }
      } else {
        buffer.writeln("  負担金額:");
        // 💡 修正ポイント: 除算結果を double として計算
        final average = e.participants.isNotEmpty
            ? e.amount / e.participants.length
            : 0.0;

        // カンマ区切りをしつつ、必要に応じて小数点を表示（例: 1,100.05円）
        buffer.writeln("    ・ 1人あたり ${Utils.formatAmount(average)}");
      }
    }
  }

  buffer.writeln("\n$splitter");
  buffer.writeln("💳 支払合計金額");
  for (final m in event.members) {
    final val = report.paidTotals[m.id] ?? 0;
    buffer.writeln("・${m.name}: ${Utils.formatAmount(val)}");
  }

  buffer.writeln("\n$splitter");
  buffer.writeln("💸 負担合計金額");
  for (final m in event.members) {
    final val = report.shareTotals[m.id] ?? 0;
    buffer.writeln("・${m.name}: ${Utils.formatAmount(val)}");
  }

  buffer.writeln("\n$splitter");
  buffer.writeln("📊 精算差額");
  for (final m in event.members) {
    final val = report.balances[m.id] ?? 0;
    // プラスの場合は明示的に「+」を付与
    buffer.writeln(
      "・${m.name}: ${val >= 0 ? '+' : ''}${Utils.formatAmount(val)}",
    );
  }

  buffer.writeln("\n$splitter");
  buffer.writeln("📈 精算結果");
  // 精算結果ツリー（├, └）を結合して追加
  for (final msg in report.settlementMessages) {
    buffer.writeln("・$msg");
  }

  return buffer.toString();
}

/// 戻る前に保存確認ダイアログを表示し、保存処理を実行します。
Future<bool> onWillPopConfirmSave(
  bool onlySave,
  BuildContext context,
  Event event,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("保存確認"),
      content: onlySave
          ? const Text("編集内容を保存しますか？")
          : const Text("編集内容を保存して戻りますか？"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("キャンセル"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: onlySave ? const Text("保存") : const Text("保存して戻る"),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      // 外部ヘルパーを使用してFirebase等へ保存
      await saveEventFlexible(context, event);
      showAppSnackBar(context, message: '保存しました', type: SnackBarType.info);
    } on Exception catch (e) {
      showAppSnackBar(
        context,
        message: "保存に失敗しました: ${ExceptionUtils.format(e)}",
        type: SnackBarType.error,
      );
      // 保存失敗時は画面を閉じないように false を返す
      return false;
    }
    return true;
  } else {
    // ユーザーがキャンセルを選択した場合
    return false;
  }
}
