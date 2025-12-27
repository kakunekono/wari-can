import 'package:wari_can/models/event.dart';
import 'package:wari_can/models/expense.dart';
import 'package:wari_can/models/menber.dart';
import 'package:wari_can/utils/utils.dart';

/// 支出ごとの詳細な負担内訳（誰がいくら負担したか）を保持するデータモデル
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

/// 各メンバーの具体的な負担額
class MemberShare {
  final String memberId;
  final String memberName;
  final int amount;
  MemberShare(this.memberId, this.memberName, this.amount);
}

/// イベント全体の計算済みレポート（最終的な精算結果を保持する）
class SettlementReport {
  /// 支出ごとの詳細な内訳リスト
  final List<ExpenseBreakdown> breakdowns;

  /// メンバーごとの支払合計（実際に財布から出した金額）
  final Map<String, int> paidTotals;

  /// メンバーごとの負担合計（自分が食べる・使うなどして消費した金額）
  final Map<String, int> shareTotals;

  /// 精算差額（支払合計 - 負担合計）。これがプラスなら受取、マイナスなら支払い。
  final Map<String, int> balances;

  /// 送金指示メッセージ（UIや共有テキストでそのまま使える文字列リスト）
  final List<String> settlementMessages;

  SettlementReport({
    required this.breakdowns,
    required this.paidTotals,
    required this.shareTotals,
    required this.balances,
    required this.settlementMessages,
  });

  /// イベントのデータから精算レポートを計算し、生成します。
  factory SettlementReport.calculate(Event event) {
    // 1. 支出明細を整理（名前順・日付順などでソート）
    final sortedExpenses = _sortDetails(event.details, event.members);

    final paidTotals = <String, int>{};
    final shareTotals = <String, int>{};
    final breakdowns = <ExpenseBreakdown>[];

    // 2. 各支出をループして、誰がいくら払い、誰がいくら負担したかを計算
    for (final e in sortedExpenses) {
      // 支払者の「支払合計」に加算
      paidTotals[e.payer] = (paidTotals[e.payer] ?? 0) + e.amount;

      final currentShares = <MemberShare>[];
      final isManual = e.mode == SplitMode.manual;
      final allMemberIds = event.members.map((m) => m.id).toSet();
      final participants = e.participants.toSet();

      if (isManual) {
        // 【手動モード】入力された負担額（shares）をそのまま集計
        for (final m in event.members) {
          final amt = e.shares[m.id] ?? 0;
          if (amt > 0) {
            currentShares.add(MemberShare(m.id, m.name, amt));
            shareTotals[m.id] = (shareTotals[m.id] ?? 0) + amt;
          }
        }
      } else {
        // 【均等モード】人数で割り、端数は支払者が負担するロジック
        if (e.participants.isNotEmpty) {
          final per = e.amount ~/ e.participants.length; // 1人あたりの単価（切り捨て）
          final remainder = e.amount % e.participants.length; // 余りの端数

          for (final pid in e.participants) {
            final m = event.members.firstWhere((mem) => mem.id == pid);
            // 支払者本人の負担分に端数を合算して調整
            final amt = per + (pid == e.payer ? remainder : 0);

            currentShares.add(MemberShare(m.id, m.name, amt));
            shareTotals[pid] = (shareTotals[pid] ?? 0) + amt;
          }
        }
      }

      // 支出ごとの詳細データを保存
      breakdowns.add(
        ExpenseBreakdown(
          expense: e,
          memberShares: currentShares,
          isManual: isManual,
          isPartial: participants.length < allMemberIds.length,
        ),
      );
    }

    // 3. 最終的な精算差額の算出
    //    「払ったお金」-「負担すべきお金」を計算
    final balances = <String, int>{};
    for (final m in event.members) {
      paidTotals[m.id] ??= 0;
      shareTotals[m.id] ??= 0;
      balances[m.id] = paidTotals[m.id]! - shareTotals[m.id]!;
    }

    // 4. 精算差額を元に、具体的な送金指示（誰が誰に）を計算
    final messages = _calcSettlementMessages(balances, event.members);

    return SettlementReport(
      breakdowns: breakdowns,
      paidTotals: paidTotals,
      shareTotals: shareTotals,
      balances: balances,
      settlementMessages: messages,
    );
  }

  /// 支出明細を「支払者名」→「日付」→「項目名」の優先順位で並び替えます。
  static List<Expense> _sortDetails(
    List<Expense> details,
    List<Member> members,
  ) {
    final sorted = [...details];
    sorted.sort((a, b) {
      // 第一優先：支払者の名前順
      final aName = Utils.memberName(a.payer, members);
      final bName = Utils.memberName(b.payer, members);
      final payerCompare = aName.compareTo(bName);
      if (payerCompare != 0) return payerCompare;

      // 第二優先：支払い日順
      final aDate = a.payDate ?? "";
      final bDate = b.payDate ?? "";
      final dateCompare = aDate.compareTo(bDate);
      if (dateCompare != 0) return dateCompare;

      // 第三優先：項目名の名前順
      return a.item.compareTo(b.item);
    });
    return sorted;
  }

  /// 精算差額から、効率的な送金ルート（最小移動）を計算し、ツリー形式の文字列を生成します。
  static List<String> _calcSettlementMessages(
    Map<String, int> balances,
    List<Member> members,
  ) {
    // 1. お金を払うべき人（差額マイナス）と、受け取るべき人（差額プラス）を抽出
    final payers = balances.entries
        .where((e) => e.value < 0)
        .map((e) => {'id': e.key, 'amount': -e.value})
        .toList();
    final receivers = balances.entries
        .where((e) => e.value > 0)
        .map((e) => {'id': e.key, 'amount': e.value})
        .toList();

    Map<String, List<String>> payerMap = {};

    // 2. マッチング計算：払う人が、受取人の枠を順番に埋めていく
    for (var payer in payers) {
      var amount = payer['amount'] as int;
      if (amount <= 0) continue;

      // 親要素の作成：名前（計 〇〇円）
      final pName =
          "${Utils.memberName(payer['id'] as String, members)}(計 ${Utils.formatAmount(amount)})";

      for (var receiver in receivers) {
        var recvAmount = receiver['amount'] as int;
        if (recvAmount <= 0) continue;

        // 今回移動させる金額（支払いたい額と受け取りたい額の小さい方）
        final pay = amount < recvAmount ? amount : recvAmount;

        if (pay > 0) {
          final rName = Utils.memberName(receiver['id'] as String, members);

          // 一時マップに保存
          payerMap.putIfAbsent(pName, () => []);
          payerMap[pName]!.add("$rName に ${Utils.formatAmount(pay)}");

          // 計算後の残高を更新
          amount -= pay;
          receiver['amount'] = recvAmount - pay;

          // この人の支払いが完了したら内側ループを抜ける
          if (amount <= 0) break;
        }
      }
    }

    // 3. 表示整形：一時マップから記号（├, └）を付けた文字列リストを作成
    final result = <String>[];
    payerMap.forEach((pName, details) {
      final formattedDetails = details.asMap().entries.map((entry) {
        int idx = entry.key;
        String detailText = entry.value;

        // 最後の要素だけ「└」、それ以外は「├」
        final symbol = (idx == details.length - 1) ? " └ " : " ├ ";
        return "$symbol$detailText";
      }).toList();

      result.add("$pName\n${formattedDetails.join('\n')}");
    });

    return result.isEmpty ? ["精算なし"] : result;
  }
}
