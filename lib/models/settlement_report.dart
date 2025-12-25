import 'package:wari_can/models/event.dart';
import 'package:wari_can/models/expense.dart';
import 'package:wari_can/models/menber.dart';
import 'package:wari_can/utils/utils.dart';

/// 支出ごとの詳細な負担内訳を保持するクラス
class ExpenseBreakdown {
  final Expense expense;
  final List<MemberShare> memberShares;
  final bool isManual;
  final bool isPartial; // 全員参加ではない（特定の人のみ）場合

  ExpenseBreakdown({
    required this.expense,
    required this.memberShares,
    required this.isManual,
    required this.isPartial,
  });
}

/// メンバーごとの負担額
class MemberShare {
  final String memberId;
  final String memberName;
  final int amount;
  MemberShare(this.memberId, this.memberName, this.amount);
}

/// イベント全体の計算済みレポート
class SettlementReport {
  final List<ExpenseBreakdown> breakdowns;
  final Map<String, int> paidTotals;      // 支払合計
  final Map<String, int> shareTotals;     // 負担合計
  final Map<String, int> balances;        // 精算差額（支払-負担）
  final List<String> settlementMessages;  // 送金指示テキスト

  SettlementReport({
    required this.breakdowns,
    required this.paidTotals,
    required this.shareTotals,
    required this.balances,
    required this.settlementMessages,
  });

  factory SettlementReport.calculate(Event event) {
    // 1. ソート済みの明細を取得
    final sortedExpenses = _sortDetails(event.details, event.members);
    
    final paidTotals = <String, int>{};
    final shareTotals = <String, int>{};
    final breakdowns = <ExpenseBreakdown>[];

    // 2. 各支出の計算と集計
    for (final e in sortedExpenses) {
      // 支払合計の加算
      paidTotals[e.payer] = (paidTotals[e.payer] ?? 0) + e.amount;

      final currentShares = <MemberShare>[];
      final isManual = e.mode == SplitMode.manual;
      final allMemberIds = event.members.map((m) => m.id).toSet();
      final participants = e.participants.toSet();

      if (isManual) {
        // 手動モード: sharesマップをそのまま使用
        for (final m in event.members) {
          final amt = e.shares[m.id] ?? 0;
          if (amt > 0) {
            currentShares.add(MemberShare(m.id, m.name, amt));
            shareTotals[m.id] = (shareTotals[m.id] ?? 0) + amt;
          }
        }
      } else {
        // 均等モード: 端数は支払者が負担
        if (e.participants.isNotEmpty) {
          final per = e.amount ~/ e.participants.length;
          final remainder = e.amount % e.participants.length;
          for (final pid in e.participants) {
            final m = event.members.firstWhere((mem) => mem.id == pid);
            final amt = per + (pid == e.payer ? remainder : 0);
            currentShares.add(MemberShare(m.id, m.name, amt));
            shareTotals[pid] = (shareTotals[pid] ?? 0) + amt;
          }
        }
      }

      breakdowns.add(ExpenseBreakdown(
        expense: e,
        memberShares: currentShares,
        isManual: isManual,
        isPartial: participants.length < allMemberIds.length,
      ));
    }

    // 3. 差額計算
    final balances = <String, int>{};
    for (final m in event.members) {
      paidTotals[m.id] ??= 0;
      shareTotals[m.id] ??= 0;
      balances[m.id] = paidTotals[m.id]! - shareTotals[m.id]!;
    }

    // 4. 送金指示の計算
    final messages = _calcSettlementMessages(balances, event.members);

    return SettlementReport(
      breakdowns: breakdowns,
      paidTotals: paidTotals,
      shareTotals: shareTotals,
      balances: balances,
      settlementMessages: messages,
    );
  }

  static List<Expense> _sortDetails(List<Expense> details, List<Member> members) {
    final sorted = [...details];
    sorted.sort((a, b) {
      final aName = Utils.memberName(a.payer, members);
      final bName = Utils.memberName(b.payer, members);
      final payerCompare = aName.compareTo(bName);
      if (payerCompare != 0) return payerCompare;

      final aDate = a.payDate ?? "";
      final bDate = b.payDate ?? "";
      final dateCompare = aDate.compareTo(bDate);
      if (dateCompare != 0) return dateCompare;

      return a.item.compareTo(b.item);
    });
    return sorted;
  }

  static List<String> _calcSettlementMessages(Map<String, int> balances, List<Member> members) {
    final payers = balances.entries
        .where((e) => e.value < 0)
        .map((e) => {'id': e.key, 'amount': -e.value})
        .toList();
    final receivers = balances.entries
        .where((e) => e.value > 0)
        .map((e) => {'id': e.key, 'amount': e.value})
        .toList();

    final result = <String>[];
    for (var payer in payers) {
      var amount = payer['amount'] as int;
      for (var receiver in receivers) {
        var recvAmount = receiver['amount'] as int;
        if (recvAmount <= 0) continue;
        final pay = amount < recvAmount ? amount : recvAmount;
        if (pay > 0) {
          final pName = Utils.memberName(payer['id'] as String, members);
          final rName = Utils.memberName(receiver['id'] as String, members);
          result.add("$pName → $rName に ${Utils.formatAmount(pay)}円");
          amount -= pay;
          receiver['amount'] = recvAmount - pay;
          if (amount <= 0) break;
        }
      }
    }
    return result.isEmpty ? ["精算なし"] : result;
  }
}