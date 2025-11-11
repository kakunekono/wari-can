import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event.dart';
import '../utils/event_json_utils.dart';

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

  Future<void> _saveEvent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('event_${_event.id}', jsonEncode(_event.toJson()));
    setState(() {});
  }

  void _sortDetails() {
    _event.details.sort((a, b) {
      // ① 支払者
      final payerCompare = a.payer.compareTo(b.payer);
      if (payerCompare != 0) return payerCompare;

      // ② 支払日（null はあとに）
      final aDate = a.payDate;
      final bDate = b.payDate;
      if (aDate == null && bDate != null) return 1; // a が null → 後ろへ
      if (aDate != null && bDate == null) return -1; // b が null → b を後ろへ
      if (aDate != null && bDate != null) {
        final dateCompare = aDate.compareTo(bDate);
        if (dateCompare != 0) return dateCompare;
      }

      // ③ 項目名
      return a.item.compareTo(b.item);
    });
  }

  // ----------------------
  // id → name 変換
  // ----------------------
  String _memberName(String id) =>
      _event.members.firstWhere((m) => m.id == id).name;

  // ----------------------
  // 共有用テキスト生成
  // ----------------------
  String _buildShareText() {
    // 処理前にソート
    _sortDetails();

    final totals = _calcTotals();
    final paidTotals = _calcPaidTotals();
    final settlements = _calcSettlement();

    final buffer = StringBuffer();
    buffer.writeln("📅 イベント名: ${_event.name}");
    buffer.writeln("");
    buffer.writeln("👥 参加者:");
    for (final m in _event.members) {
      buffer.writeln("・${m.name}");
    }
    buffer.writeln("");
    buffer.writeln("💰 支出明細:");

    final sortedDetails = List<Expense>.from(_event.details);

    String? prevPayer;
    for (final e in sortedDetails) {
      final payerName = _memberName(e.payer);
      if (payerName != prevPayer) {
        if (prevPayer != null) buffer.writeln("");
        buffer.writeln("💳 $payerName");

        // 支払日を最初の明細だけ出力
        final payDateText = (e.payDate != null && e.payDate!.isNotEmpty)
            ? e.payDate
            : "XXXX/XX/XX";
        buffer.writeln("支払日: $payDateText");

        prevPayer = payerName;
      }

      // 参加者全員の場合は表示しない
      final allMemberIds = _event.members.map((m) => m.id).toSet();
      final participantIds = e.participants.toSet();
      final showParticipants = participantIds.length < allMemberIds.length;

      buffer.writeln(
        "・${e.item}（${e.amount}円）${showParticipants ? "：参加者: ${e.participants.map(_memberName).join(', ')}" : ""}",
      );
    }

    buffer.writeln("");
    buffer.writeln("💵 メンバーごとの支払合計（単純集計）:");
    for (final e in paidTotals.entries) {
      buffer.writeln("・${_memberName(e.key)}: ${e.value}円");
    }
    buffer.writeln("");
    buffer.writeln("💴 メンバーごとの支払合計（精算後残高）:");
    for (final e in totals.entries) {
      final sign = e.value >= 0 ? '+' : '';
      buffer.writeln("・${_memberName(e.key)}: $sign${e.value}円");
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

    setState(
      () => _event.members.add(Member(id: const Uuid().v4(), name: name)),
    );
    await _saveEvent();
    _memberController.clear();
  }

  Future<void> _deleteMember(String memberId) async {
    final used = _event.details.any(
      (d) => d.payer == memberId || d.participants.contains(memberId),
    );
    if (used) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('このメンバーは支払に使用されています')));
      return;
    }

    setState(() => _event.members.removeWhere((m) => m.id == memberId));
    await _saveEvent();
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

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      setState(() {
        member.name = newName;
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

    final newExpense = Expense(
      id: editExpense?.id ?? const Uuid().v4(),
      item: result['item'] ?? "支出${_event.details.length + 1}",
      payer: result['payerId'] ?? "",
      amount: result['total'] ?? 0,
      participants: participants,
      shares: shares,
      mode: result['mode'] ?? "manual",
      payDate: result['payDate'],
    );

    setState(() {
      if (editIndex != null) {
        _event.details[editIndex] = newExpense;
      } else {
        _event.details.add(newExpense);
      }
      _sortDetails();
    });
    await _saveEvent();
  }

  Future<void> _deleteExpense(int index) async {
    final expense = _event.details[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("確認"),
        content: Text("${expense.item} を削除しますか？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("キャンセル"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("削除"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _event.details.removeAt(index);
        _sortDetails();
      });
      await _saveEvent();
    }
  }

  // ----------------------
  // 各メンバーの支払合計（足し引きなし）
  // ----------------------
  Map<String, int> _calcPaidTotals() {
    final totals = <String, int>{};
    for (final e in _event.details) {
      totals[e.payer] = (totals[e.payer] ?? 0) + e.amount;
    }

    // 参加者全員を含める（支払ゼロの人も0円として出す）
    for (final m in _event.members) {
      totals[m.id] = totals[m.id] ?? 0;
    }
    return totals;
  }

  // ----------------------
  // 精算・集計
  // ----------------------
  Map<String, int> _calcTotals() {
    final totals = <String, int>{};
    final owes = <String, int>{};

    for (final e in _event.details) {
      totals[e.payer] = (totals[e.payer] ?? 0) + e.amount;

      if (e.mode == "manual" && e.shares.isNotEmpty) {
        e.shares.forEach((memberId, share) {
          owes[memberId] = (owes[memberId] ?? 0) + share;
        });
      } else {
        if (e.participants.isEmpty) continue;
        final per = e.amount ~/ e.participants.length;
        for (final pid in e.participants) {
          owes[pid] = (owes[pid] ?? 0) + per;
        }
      }
    }

    final balances = <String, int>{};
    for (final m in _event.members) {
      balances[m.id] = (totals[m.id] ?? 0) - (owes[m.id] ?? 0);
    }
    return balances;
  }

  // ----------------------
  // 精算結果
  // ----------------------
  List<String> _calcSettlement() {
    final balances = _calcTotals();
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
          result.add(
            "${_memberName(payer['id'] as String)} → ${_memberName(receiver['id'] as String)} に $pay円",
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
    final settlements = _calcSettlement();
    final balances = _calcTotals();
    final paidTotals = _calcPaidTotals();

    // 支払者順にソート
    final sortedDetails = List<Expense>.from(_event.details);

    return Scaffold(
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
          IconButton(
            icon: const Icon(Icons.code),
            onPressed: () => EventJsonUtils.exportEventJson(context, _event),
          ), // ← 追加
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
                      "💳 ${_memberName(e.payer)}",
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
                    title: Text(e.item),
                    subtitle: Text(
                      [
                        "支払者: ${_memberName(e.payer)}",
                        if (e.payDate != null && e.payDate!.isNotEmpty)
                          "支払日: ${e.payDate}", // 支払日がある場合のみ表示
                        "金額: ${e.amount}円",
                        if (showParticipants)
                          "参加者: ${e.participants.map(_memberName).join(', ')}",
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
                "${_memberName(e.key)}: ${e.value}円",
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
              final color = e.value >= 0 ? Colors.green : Colors.red;
              final sign = e.value >= 0 ? '+' : '';
              return Text(
                "${_memberName(e.key)}: $sign${e.value}円",
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
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
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
    _payDateController.text = edit?.payDate.toString() ?? "";
    _mode = edit?.mode ?? "manual";

    for (final m in widget.members) {
      _controllers[m.id] = TextEditingController(
        text:
            edit?.shares[m.id]?.toString() ??
            (edit?.participants.contains(m.id) ?? false
                ? ((edit?.amount ?? 0) ~/ edit!.participants.length).toString()
                : "0"),
      );
    }

    _payerId =
        edit?.payer ??
        (widget.members.isNotEmpty ? widget.members.first.id : null);

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

  @override
  Widget build(BuildContext context) {
    final diff = subtotal - total;
    return AlertDialog(
      title: Text(widget.editExpense != null ? "明細を編集" : "明細を追加"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 合計差異チェックの警告
            if (diff != 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  "⚠ 合計と個別合計が一致していません (差: $diff 円)",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

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
              ],
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
            Text(
              "合計: $subtotal円 / 総額: $total円",
              style: TextStyle(
                color: subtotal == total ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("キャンセル"),
        ),
        FilledButton(
          onPressed: subtotal != total
              ? null // 合計が一致していなければ登録不可
              : () {
                  final shares = <String, int>{};
                  for (final m in widget.members) {
                    shares[m.id] = int.tryParse(_controllers[m.id]!.text) ?? 0;
                  }
                  Navigator.pop(context, {
                    'item': _itemController.text.trim(),
                    'payerId': _payerId,
                    'total': total,
                    'shares': shares,
                    'mode': _mode,
                    'payDate': _payDateController.text.isNotEmpty
                        ? _payDateController.text
                        : null,
                  });
                },
          child: const Text("登録"),
        ),
      ],
    );
  }
}
