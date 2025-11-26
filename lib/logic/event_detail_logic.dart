import 'package:flutter/material.dart';
import 'package:wari_can/models/event.dart';
import 'package:wari_can/utils/firestore_helper.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
import 'package:wari_can/utils/utils.dart';

/// 支出明細を支払者名・支払日・項目名の順でソートします。
List<Expense> sortDetails(List<Expense> details, List<Member> members) {
  final sorted = [...details];
  sorted.sort((a, b) {
    final aName = Utils.memberName(a.payer, members);
    final bName = Utils.memberName(b.payer, members);
    final payerCompare = aName.compareTo(bName);
    if (payerCompare != 0) return payerCompare;

    final aDate = a.payDate;
    final bDate = b.payDate;
    if (aDate == null && bDate != null) return 1;
    if (aDate != null && bDate == null) return -1;
    if (aDate != null && bDate != null) {
      final dateCompare = aDate.compareTo(bDate);
      if (dateCompare != 0) return dateCompare;
    }

    return a.item.compareTo(b.item);
  });
  return sorted;
}

/// 各メンバーの支払合計（単純集計）を計算します。
///
/// 支払者ごとの合計金額を集計し、未使用メンバーには 0 を設定します。
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

/// 各メンバーの精算後残高を計算します（支払額 - 負担額）。
///
/// 手動モードでは shares を使用し、均等モードでは参加者数で割り算します。
Map<String, int> calcTotals(List<Expense> details, List<Member> members) {
  final totals = <String, int>{};
  final owes = <String, int>{};

  for (final e in details) {
    totals[e.payer] = (totals[e.payer] ?? 0) + e.amount;

    if (e.mode == "manual" && e.shares.isNotEmpty) {
      e.shares.forEach((memberId, share) {
        owes[memberId] = (owes[memberId] ?? 0) + share;
      });
    } else {
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

/// 各メンバーの負担合計（sharesベース）を計算します。
///
/// 手動モードで入力された shares を集計します。
Map<String, int> memberShareTotalsFunc(List<Expense> details) {
  final totals = <String, int>{};
  for (final e in details) {
    e.shares.forEach((memberId, amount) {
      totals[memberId] = (totals[memberId] ?? 0) + amount;
    });
  }
  return totals;
}

/// 精算結果を計算し、送金指示のリストを返します。
///
/// 残高がマイナスの人からプラスの人へ送金する形式で整形します。
List<String> calcSettlement(List<Expense> details, List<Member> members) {
  final balances = calcTotals(details, members);

  final payers = balances.entries
      .where((e) => e.value < 0)
      .map((e) => {'id': e.key, 'amount': -e.value})
      .toList();

  final receivers = balances.entries
      .where((e) => e.value > 0)
      .map((e) => {'id': e.key, 'amount': e.value})
      .toList();

  final result = <String>[];
  for (final payer in payers) {
    var amount = payer['amount'] as int;
    for (final receiver in receivers) {
      var recvAmount = receiver['amount'] as int;
      if (recvAmount <= 0) continue;
      final pay = amount < recvAmount ? amount : recvAmount;
      if (pay > 0) {
        final payerName = Utils.memberName(payer['id'] as String, members);
        final receiverName = Utils.memberName(
          receiver['id'] as String,
          members,
        );
        result.add("$payerName → $receiverName に ${Utils.formatAmount(pay)}円");
        amount -= pay;
        receiver['amount'] = recvAmount - pay;
        if (amount <= 0) break;
      }
    }
  }

  if (result.isEmpty) result.add("精算なし");
  return result;
}

/// イベントの内容をテキスト形式で整形し、共有用文字列として返します。
///
/// メンバー一覧、支出明細、支払合計、負担合計、精算結果を含みます。
String buildShareText(Event event) {
  final sortedDetails = sortDetails(event.details, event.members);
  final totals = calcTotals(sortedDetails, event.members);
  final paidTotals = calcPaidTotals(sortedDetails, event.members);
  final settlements = calcSettlement(sortedDetails, event.members);
  final memberShareTotals = memberShareTotalsFunc(sortedDetails);

  final buffer = StringBuffer();
  buffer.writeln("📅 イベント名: ${event.name}\n");
  buffer.writeln("👥 参加者:");
  for (final m in event.members) {
    buffer.writeln("・${m.name}");
  }
  buffer.writeln("\n💰 支出明細:");

  String? prevPayer;
  String? prevPayDate;

  for (final e in sortedDetails) {
    final payerName = Utils.memberName(e.payer, event.members);
    final payDateText = (e.payDate != null && e.payDate!.isNotEmpty)
        ? e.payDate
        : "XXXX/XX/XX";

    if (payerName != prevPayer) {
      if (prevPayer != null) buffer.writeln("");
      buffer.writeln("💳 $payerName");
      buffer.writeln("支払日: $payDateText");
      prevPayer = payerName;
      prevPayDate = payDateText;
    } else if (payDateText != prevPayDate) {
      buffer.writeln("\n支払日: $payDateText");
      prevPayDate = payDateText;
    }

    final allMembers = event.members.map((m) => m.id).toSet();
    final participants = e.participants.toSet();
    final showParticipants = participants.length < allMembers.length;

    buffer.writeln("・${e.item}（${Utils.formatAmount(e.amount)}円）");

    if (e.shares.isNotEmpty) {
      if (showParticipants) {
        buffer.writeln("  負担額:");
        e.shares.forEach((memberId, amount) {
          if (amount > 0) {
            buffer.writeln(
              "    ${Utils.memberName(memberId, event.members)} -> ${Utils.formatAmount(amount)}円",
            );
          }
        });
      } else {
        buffer.writeln(
          "  負担額:${Utils.formatAmount(e.amount / allMembers.length)}円",
        );
      }
    }
  }

  buffer.writeln("\n💵 メンバーごとの支払合計（単純集計）:");
  for (final e in paidTotals.entries) {
    buffer.writeln(
      "・${Utils.memberName(e.key, event.members)}: ${Utils.formatAmount(e.value)}円",
    );
  }

  buffer.writeln("\n💳 メンバーごとの負担合計:");
  for (final e in memberShareTotals.entries) {
    buffer.writeln(
      "・${Utils.memberName(e.key, event.members)}: ${Utils.formatAmount(e.value)}円",
    );
  }

  buffer.writeln("\n💴 メンバーごとの支払合計（精算後残高）:");
  for (final e in totals.entries) {
    final sign = e.value >= 0 ? '+' : '';
    buffer.writeln(
      "・${Utils.memberName(e.key, event.members)}: $sign${Utils.formatAmount(e.value)}円",
    );
  }

  buffer.writeln("\n📊 精算結果:");
  for (final s in settlements) {
    buffer.writeln("・$s");
  }

  return buffer.toString();
}

/// 戻る前に保存確認ダイアログを表示し、保存処理を行います。
///
/// [context] はダイアログ表示と保存に使用されます。
/// [event] は保存対象のイベントデータです。
///
/// ユーザーが「保存して戻る」を選択した場合は true を返し、
/// 「キャンセル」を選択した場合は false を返します。
Future<bool> onWillPopConfirmSave(BuildContext context, Event event) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("保存確認"),
      content: const Text("編集内容を保存して戻りますか？"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("キャンセル"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("保存して戻る"),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await saveEventFlexible(context, event);
      showAppSnackBar(context, message: '保存しました', type: SnackBarType.info);
    } catch (e) {
      showAppSnackBar(
        context,
        message: "保存に失敗しました: $e",
        type: SnackBarType.error,
      );
      // ✅ 画面にとどまる → Navigator.pop は呼ばない
      return false;
    }
    return true;
  } else {
    return false;
  }
}
