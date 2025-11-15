import 'dart:convert';
import 'package:wari_can/utils/firestore_helper.dart';

import '../models/event.dart';
import '../utils/event_json_utils.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wari_can/utils/utils.dart';

class EventDetailPage extends StatefulWidget {
  final Event event;
  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late Event _event;
  final TextEditingController _memberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _saveEvent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('event_${_event.id}', jsonEncode(_event.toJson()));
    setState(() {});
  }

  Future<bool> _onWillPopConfirmSave() async {
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
      await _saveEvent(); // ローカル保存
      await saveEventToFirestore(_event); // Firestore保存
      return true; // 戻る許可
    } else {
      return false; // 戻らない
    }
  }

  List<Expense> sortDetails(List<Expense> details, List<Member> members) {
    final sorted = [...details]; // イミュータブルにコピー

    sorted.sort((a, b) {
      // ① 支払者名で比較（null安全）
      final aName = Utils.memberName(a.payer, members);
      final bName = Utils.memberName(b.payer, members);
      final payerCompare = aName.compareTo(bName);
      if (payerCompare != 0) return payerCompare;

      // ② 支払日（nullは後ろへ）
      final aDate = a.payDate;
      final bDate = b.payDate;
      if (aDate == null && bDate != null) return 1;
      if (aDate != null && bDate == null) return -1;
      if (aDate != null && bDate != null) {
        final dateCompare = aDate.compareTo(bDate);
        if (dateCompare != 0) return dateCompare;
      }

      // ③ 項目名
      return a.item.compareTo(b.item);
    });

    return sorted;
  }

  // ----------------------
  // 共有用テキスト生成
  // ----------------------
  String _buildShareText() {
    // 処理前にソート
    final sortedDetails = sortDetails(_event.details, _event.members);

    setState(() {
      _event = _event.copyWith(details: sortedDetails);
    });

    final totals = _calcTotals(sortedDetails, _event.members);
    final paidTotals = _calcPaidTotals(sortedDetails, _event.members);
    final settlements = _calcSettlement(sortedDetails, _event.members);

    // メンバーごとの負担合計を計算
    final memberShareTotals = <String, int>{};
    for (final e in _event.details) {
      if (e.mode == "manual" && e.shares.isNotEmpty) {
        e.shares.forEach((memberId, amount) {
          memberShareTotals[memberId] =
              (memberShareTotals[memberId] ?? 0) + amount;
        });
      } else if (e.participants.isNotEmpty) {
        final per = e.amount ~/ e.participants.length;
        final remainder = e.amount - (per * e.participants.length);
        int i = 0;
        for (final pid in e.participants) {
          int share = per;
          if (i == 0) share += remainder; // 端数は支払者負担
          memberShareTotals[pid] = (memberShareTotals[pid] ?? 0) + share;
          i++;
        }
      }
    }

    final buffer = StringBuffer();
    buffer.writeln("📅 イベント名: ${_event.name}");
    buffer.writeln("");
    buffer.writeln("👥 参加者:");
    for (final m in _event.members) {
      buffer.writeln("・${m.name}");
    }
    buffer.writeln("");
    buffer.writeln("💰 支出明細:");

    String? prevPayer;
    String? prevPayDate;

    for (final e in sortedDetails) {
      final payerName = Utils.memberName(e.payer, _event.members);
      final payDateText = (e.payDate != null && e.payDate!.isNotEmpty)
          ? e.payDate
          : "XXXX/XX/XX";

      // 新しい支払者なら見出しを出力（名前＋支払日）
      if (payerName != prevPayer) {
        if (prevPayer != null) buffer.writeln("");
        buffer.writeln("💳 $payerName");
        buffer.writeln("支払日: $payDateText");
        prevPayer = payerName;
        prevPayDate = payDateText;
      }
      // 同じ支払者で日付が変わったときは支払日のみ出力
      else if (payDateText != prevPayDate) {
        if (payDateText != null) buffer.writeln("");
        buffer.writeln("支払日: $payDateText");
        prevPayDate = payDateText;
      }

      // 参加者が全員なら省略
      final allMembers = _event.members.map((m) => m.id).toSet();
      final participants = e.participants.toSet();
      final showParticipants = participants.length < allMembers.length;

      // 明細本体
      buffer.writeln("・${e.item}（${Utils.formatAmount(e.amount)}円）");

      // 負担額を出力（shares がある場合のみ）
      if (e.shares.isNotEmpty) {
        if (showParticipants) {
          buffer.writeln("  負担額:");
          e.shares.forEach((memberId, amount) {
            if (amount > 0) {
              buffer.writeln(
                "    ${Utils.memberName(memberId, _event.members)} -> ${Utils.formatAmount(amount)}円",
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

    buffer.writeln("");
    buffer.writeln("💵 メンバーごとの支払合計（単純集計）:");
    for (final e in paidTotals.entries) {
      buffer.writeln(
        "・${Utils.memberName(e.key, _event.members)}: ${Utils.formatAmount(e.value)}円",
      );
    }

    buffer.writeln("");
    buffer.writeln("💳 メンバーごとの負担合計:");
    for (final e in memberShareTotals.entries) {
      buffer.writeln(
        "・${Utils.memberName(e.key, _event.members)}: ${Utils.formatAmount(e.value)}円",
      );
    }

    buffer.writeln("");
    buffer.writeln("💴 メンバーごとの支払合計（精算後残高）:");
    for (final e in totals.entries) {
      final sign = e.value >= 0 ? '+' : '';
      buffer.writeln(
        "・${Utils.memberName(e.key, _event.members)}: $sign${Utils.formatAmount(e.value)}円",
      );
    }

    buffer.writeln("");
    buffer.writeln("📊 精算結果:");
    for (final s in settlements) {
      buffer.writeln("・$s");
    }
    return buffer.toString();
  }

  Future<void> _shareSummary() async {
    final text = _buildShareText();
    await Share.share(text);
  }

  // ----------------------
  // メンバー操作
  // ----------------------
  Future<void> _addMember() async {
    final name = _memberController.text.trim();
    if (name.isEmpty) return;

    if (_event.members.any((m) => m.name == name)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「$name」はすでに登録されています')));
      return;
    }

    final now = DateTime.now();
    final newMember = Member(
      id: Uuid().v4(),
      name: name,
      createAt: now,
      updateAt: now,
    );

    setState(() {
      _event = _event.copyWith(
        members: [..._event.members, newMember],
        updateAt: now,
      );
    });

    await _saveEvent();
    _memberController.clear();
  }

  Future<void> _deleteMember(String memberId) async {
    final member = _event.members.firstWhere((m) => m.id == memberId);

    // 🔸 削除確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("メンバー削除の確認"),
        content: Text("「${member.name}」を削除しますか？この操作は元に戻せません。"),
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

    // 🔸 支出に使用されているかチェック
    final used = _event.details.any(
      (d) => d.payer == memberId || d.participants.contains(memberId),
    );

    if (used) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('このメンバーは支払に使用されています')));
      return;
    }

    // 🔸 イミュータブルに削除＆updateAt更新
    final now = DateTime.now();
    final updatedMembers = _event.members
        .where((m) => m.id != memberId)
        .toList();

    setState(() {
      _event = _event.copyWith(members: updatedMembers, updateAt: now);
    });

    await _saveEvent();

    // 🔸 削除完了通知
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("「${member.name}」を削除しました")));
  }

  Future<void> _editMemberName(String memberId) async {
    final member = _event.members.firstWhere((m) => m.id == memberId);
    final oldName = member.name;
    final controller = TextEditingController(text: oldName);

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("メンバー名を編集"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("OK"),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && newName != oldName) {
      final now = DateTime.now();

      final updatedMembers = _event.members.map((m) {
        if (m.id == memberId) {
          return m.copyWith(name: newName.trim(), updateAt: now);
        }
        return m;
      }).toList();

      setState(() {
        _event = _event.copyWith(members: updatedMembers, updateAt: now);
      });

      await _saveEvent();
    }
  }

  // ----------------------
  // 明細操作
  // ----------------------
  Future<void> _addExpense({Expense? editExpense, int? editIndex}) async {
    if (_event.members.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メンバーを先に登録してください')));
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          ExpenseInputDialog(members: _event.members, editExpense: editExpense),
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
      item: result['item'] ?? _generateDefaultItemName(),
      payer: payerId,
      amount: result['total'] ?? 0,
      participants: participants,
      shares: shares,
      mode: result['mode'] ?? "manual",
      payDate: result['payDate'],
      createAt: editExpense?.createAt ?? now,
      updateAt: now,
    );

    final updatedDetails = [..._event.details];
    if (editIndex != null) {
      updatedDetails[editIndex] = newExpense;
    } else {
      updatedDetails.add(newExpense);
    }

    final sortedDetails = sortDetails(updatedDetails, _event.members);

    setState(() {
      _event = _event.copyWith(details: sortedDetails, updateAt: now);
    });

    await _saveEvent();
  }

  String _generateDefaultItemName() {
    return "支出${_event.details.length + 1}";
  }

  Future<void> _deleteExpense(int index) async {
    final expense = _event.details[index];

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

    final updatedDetails = List<Expense>.from(_event.details)..removeAt(index);
    final sortedDetails = sortDetails(updatedDetails, _event.members);
    final now = DateTime.now();

    setState(() {
      _event = _event.copyWith(details: sortedDetails, updateAt: now);
    });

    await _saveEvent();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("「${expense.item}」を削除しました")));
  }

  // ----------------------
  // 各メンバーの支払合計（足し引きなし）
  // ----------------------
  Map<String, int> _calcPaidTotals(
    List<Expense> details,
    List<Member> members,
  ) {
    final totals = <String, int>{};

    for (final e in details) {
      totals[e.payer] = (totals[e.payer] ?? 0) + e.amount;
    }

    // 支払が0円のメンバーも含める
    for (final m in members) {
      totals[m.id] = totals[m.id] ?? 0;
    }

    return totals;
  }

  // ----------------------
  // 精算・集計
  // ----------------------
  Map<String, int> _calcTotals(List<Expense> details, List<Member> members) {
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

  Map<String, int> _memberShareTotals(List<Expense> details) {
    final totals = <String, int>{};
    for (final e in details) {
      e.shares.forEach((memberId, amount) {
        totals[memberId] = (totals[memberId] ?? 0) + amount;
      });
    }
    return totals;
  }

  // ----------------------
  // 精算結果
  // ----------------------
  List<String> _calcSettlement(List<Expense> details, List<Member> members) {
    final balances = _calcTotals(details, members);

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
          result.add(
            "$payerName → $receiverName に ${Utils.formatAmount(pay)}円",
          );
          amount -= pay;
          receiver['amount'] = recvAmount - pay;
          if (amount <= 0) break;
        }
      }
    }

    if (result.isEmpty) result.add("精算なし");
    return result;
  }

  // ----------------------
  // UI
  // ----------------------
  @override
  Widget build(BuildContext context) {
    final sortedDetails = List<Expense>.from(_event.details);

    final settlements = _calcSettlement(sortedDetails, _event.members);
    final balances = _calcTotals(sortedDetails, _event.members);
    final paidTotals = _calcPaidTotals(sortedDetails, _event.members);
    final memberShareTotals = _memberShareTotals(sortedDetails);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // すでに戻っている場合は何もしない

        final confirmed = await _onWillPopConfirmSave();
        if (confirmed) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_event.name),
          actions: [
            IconButton(icon: const Icon(Icons.share), onPressed: _shareSummary),
            IconButton(
              icon: const Icon(Icons.code),
              onPressed: () {
                EventJsonUtils.exportEventJson(context, _event);
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _addExpense(),
          child: const Icon(Icons.add),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('イベントID: ${_event.id}'),
              const SizedBox(height: 8),
              Text('メンバー数: ${_event.members.length}人'),
              Text('支出件数: ${_event.details.length}件'),
              const Divider(height: 32),

              // ----------------------
              // メンバー一覧
              // ----------------------
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _memberController,
                      decoration: const InputDecoration(
                        labelText: 'メンバー名を入力',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addMember,
                    icon: const Icon(Icons.person_add, color: Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'メンバー一覧',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ..._event.members.map(
                (m) => Card(
                  child: ListTile(
                    title: Text(m.name),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          onPressed: () => _editMemberName(m.id),
                          icon: const Icon(Icons.edit, color: Colors.orange),
                        ),
                        IconButton(
                          onPressed: () => _deleteMember(m.id),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(),

              // ----------------------
              // 明細一覧
              // ----------------------
              const Text(
                '支出明細',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...sortedDetails.asMap().entries.expand((entry) {
                final i = entry.key;
                final e = entry.value;
                final prevPayer = i > 0 ? sortedDetails[i - 1].payer : null;
                final widgets = <Widget>[];

                if (e.payer != prevPayer) {
                  widgets.add(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "💳 ${Utils.memberName(e.payer, _event.members)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  );
                }

                // 参加者全員の場合は表示しない
                final allMemberIds = _event.members.map((m) => m.id).toSet();
                final participantIds = e.participants.toSet();
                final showParticipants =
                    participantIds.length < allMemberIds.length;

                widgets.add(
                  Card(
                    child: ListTile(
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.item,
                            style: const TextStyle(
                              decoration:
                                  TextDecoration.underline, // ← ここでアンダーライン
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
                          "支払者: ${Utils.memberName(e.payer, _event.members)}",
                          if (e.payDate != null && e.payDate!.isNotEmpty)
                            "支払日: ${e.payDate}",
                          "支払金額: ${Utils.formatAmount(e.amount)}円",
                          "負担金額:",
                          if (showParticipants) ...[
                            for (final m in e.shares.entries) ...[
                              if (m.value > 0)
                                "  ${Utils.memberName(m.key, _event.members)} -> ${Utils.formatAmount(m.value)}円",
                            ],
                          ] else ...[
                            " ${Utils.formatAmount(e.amount / participantIds.length)}円",
                          ],
                        ].join('\n'),
                      ),

                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () =>
                                _addExpense(editExpense: e, editIndex: i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteExpense(i),
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                return widgets;
              }),

              const Divider(),
              const Text(
                '各メンバーの支払合計金額',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...paidTotals.entries.map(
                (e) => Text(
                  "${Utils.memberName(e.key, _event.members)}: ${Utils.formatAmount(e.value)}円",
                  style: const TextStyle(fontSize: 16),
                ),
              ),

              const Divider(),
              const Text(
                '各メンバーの負担合計金額',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...memberShareTotals.entries.map(
                (e) => Text(
                  "${Utils.memberName(e.key, _event.members)}: ${Utils.formatAmount(e.value)}円",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const Divider(),

              // ----------------------
              // 各メンバー支払合計
              // ----------------------
              const Text(
                'メンバーごとの支払合計精算金額',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...balances.entries.map((e) {
                final color = e.value > 0
                    ? Colors.green
                    : (e.value < 0
                          ? Colors.red
                          : Theme.of(context).textTheme.bodyMedium?.color);
                final sign = e.value >= 0 ? '+' : '';
                return Text(
                  "${Utils.memberName(e.key, _event.members)}: $sign${Utils.formatAmount(e.value)}円",
                  style: TextStyle(color: color),
                );
              }),
              const Divider(),

              // ----------------------
              // 精算結果
              // ----------------------
              const Text(
                '精算結果',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...settlements.map((s) => Text(s)),

              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("戻る"),
                  onPressed: () async {
                    final allowPop = await _onWillPopConfirmSave();
                    if (allowPop) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------
// 明細入力ダイアログ
// ----------------------
class ExpenseInputDialog extends StatefulWidget {
  final List<Member> members;
  final Expense? editExpense;
  const ExpenseInputDialog({
    super.key,
    required this.members,
    this.editExpense,
  });

  @override
  State<ExpenseInputDialog> createState() => _ExpenseInputDialogState();
}

class _ExpenseInputDialogState extends State<ExpenseInputDialog> {
  final _itemController = TextEditingController();
  final _totalController = TextEditingController(text: "0");
  final _payDateController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};
  String? _payerId;
  String _mode = "manual";

  @override
  void initState() {
    super.initState();

    final edit = widget.editExpense;
    _itemController.text = edit?.item ?? "";
    _totalController.text = edit?.amount.toString() ?? "0";
    _payDateController.text = edit?.payDate ?? "";
    _mode = edit?.mode ?? "manual";
    _payerId = edit?.payer;

    final amount = edit?.amount ?? 0;
    final participants = edit?.participants ?? const [];
    final participantCount = participants.length;

    for (final m in widget.members) {
      final share = edit?.shares[m.id];
      final isParticipant = participants.contains(m.id);
      final value =
          share ??
          (isParticipant && participantCount > 0
              ? amount ~/ participantCount
              : 0);
      _controllers[m.id] = TextEditingController(text: value.toString());
    }

    if (_mode == "equal") {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyEqualSplit());
    }
  }

  int get total => int.tryParse(_totalController.text) ?? 0;
  int get subtotal => _controllers.values
      .map((c) => int.tryParse(c.text) ?? 0)
      .fold(0, (a, b) => a + b);

  void _applyEqualSplit() {
    if (widget.members.isEmpty) return;
    final per = (total / widget.members.length).floor();
    final remainder = total - per * widget.members.length;
    setState(() {
      for (int i = 0; i < widget.members.length; i++) {
        final m = widget.members[i];
        _controllers[m.id]!.text = (i < remainder ? per + 1 : per).toString();
      }
    });
  }

  void _updateTotalFromManualInput() {
    if (_mode != "manual") return; // 手動入力モードのみ
    int sum = 0;
    for (final m in widget.members) {
      final value = int.tryParse(_controllers[m.id]!.text) ?? 0;
      sum += value;
    }
    // 総額欄に反映
    _totalController.text = sum.toString();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final diff = subtotal - total;
    return AlertDialog(
      title: Text(widget.editExpense != null ? "明細を編集" : "明細を追加"),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: double.maxFinite, // 横幅最大
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _itemController,
                decoration: const InputDecoration(
                  labelText: "支出名",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _totalController,
                decoration: const InputDecoration(
                  labelText: "合計金額",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _payerId,
                decoration: const InputDecoration(labelText: "支払者"),
                items: widget.members
                    .map(
                      (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _payerId = v),
              ),
              const Divider(),
              // 🟢 支払日入力欄を追加
              TextField(
                controller: _payDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "支払日",
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(now.year - 5),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (picked != null) {
                    setState(() {
                      _payDateController.text =
                          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              ...widget.members.map((m) {
                final c = _controllers[m.id]!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TextField(
                    controller: c,
                    decoration: InputDecoration(
                      labelText: m.name,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}), // リアルタイム更新
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, // 幅をいっぱいに
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text("均等割"),
                  selected: _mode == "equal",
                  onSelected: (_) {
                    setState(() {
                      _mode = "equal";
                      _applyEqualSplit();
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text("手動入力"),
                  selected: _mode == "manual",
                  onSelected: (_) => setState(() => _mode = "manual"),
                ),
                TextButton(
                  onPressed: _updateTotalFromManualInput,
                  child: const Text("合計金額更新"),
                ),
              ],
            ),
            // 1行目：合計表示
            Text(
              "合計: ${Utils.formatAmount(subtotal)}円 / 総額: ${Utils.formatAmount(total)}円 / 過不足: ${Utils.formatAmount(diff)}円",
              style: TextStyle(
                color: diff == 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8), // ボタンとの間隔
            // 2行目：ボタン横並び
            Row(
              mainAxisAlignment: MainAxisAlignment.end, // 右揃え
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("キャンセル"),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: subtotal != total
                      ? null
                      : () {
                          if (_payerId == null || _payerId!.isEmpty) {
                            // 🟥 支払者未選択時はエラー表示
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('支払者を選択してください。')),
                            );
                            return;
                          }

                          // 支出名未入力チェック
                          if (_itemController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('支出名を入力してください')),
                            );
                            return;
                          }

                          // 合計金額未入力または 0 のチェック
                          final total =
                              int.tryParse(_totalController.text) ?? 0;
                          if (total <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('合計金額を1円以上で入力してください'),
                              ),
                            );
                            return;
                          }

                          final shares = <String, int>{};
                          for (final m in widget.members) {
                            shares[m.id] =
                                int.tryParse(_controllers[m.id]!.text) ?? 0;
                          }
                          final result = {
                            'item': _itemController.text.trim(),
                            'payerId': _payerId,
                            'total': total,
                            'shares': shares,
                            'mode': _mode,
                            'payDate': _payDateController.text.isNotEmpty
                                ? _payDateController.text
                                : null,
                          };
                          Navigator.pop(context, result);
                        },
                  child: const Text("登録"),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
