import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event.dart';

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
  }

  // ----------------------
  // 共有用テキスト生成
  // ----------------------
  String _buildShareText() {
    final totals = _calcTotals(); // 精算後残高
    final paidTotals = _calcPaidTotals(); // 足し引きなし支払金額
    final settlements = _calcSettlement();

    final buffer = StringBuffer();
    buffer.writeln("📅 イベント名: ${_event.name}");
    buffer.writeln("");
    buffer.writeln("👥 参加者:");
    for (final m in _event.members) {
      buffer.writeln("・$m");
    }
    buffer.writeln("");
    buffer.writeln("💰 支出明細:");
    for (final e in _event.details) {
      buffer.writeln(
        "・${e.item}（${e.amount}円）支払い者: ${e.payer} / 参加者: ${e.participants.join(', ')}",
      );
    }
    buffer.writeln("");
    buffer.writeln("💳 メンバーごとの支払合計（単純集計）:");
    for (final e in paidTotals.entries) {
      buffer.writeln("・${e.key}: ${e.value}円");
    }
    buffer.writeln("");
    buffer.writeln("💴 メンバーごとの支払合計（精算後残高）:");
    for (final e in totals.entries) {
      final sign = e.value >= 0 ? '+' : '';
      buffer.writeln("・${e.key}: $sign${e.value}円");
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

    if (_event.members.contains(name)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「$name」はすでに登録されています')));
      return;
    }

    setState(() => _event.members.add(name));
    await _saveEvent();
    _memberController.clear();
  }

  Future<void> _deleteMember(String name) async {
    final used = _event.details.any(
      (d) => d.payer == name || d.participants.contains(name),
    );
    if (used) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('このメンバーは支払いに使用されています')));
      return;
    }

    setState(() => _event.members.remove(name));
    await _saveEvent();
  }

  Future<void> _editMemberName(String oldName) async {
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
        final i = _event.members.indexOf(oldName);
        if (i != -1) _event.members[i] = newName;
        for (final e in _event.details) {
          if (e.payer == oldName) e.payer = newName;
          final j = e.participants.indexOf(oldName);
          if (j != -1) e.participants[j] = newName;
        }
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

    final shares = result['shares'] as Map<String, dynamic>;
    final participants = shares.entries
        .where((e) => (e.value as int) > 0)
        .map((e) => e.key)
        .toList();
    if (participants.isEmpty) return;

    final newExpense = Expense(
      id: editExpense?.id ?? const Uuid().v4(),
      item: result['item'] ?? "支出${_event.details.length + 1}",
      payer: result['payer'] ?? "",
      amount: result['total'] ?? 0,
      participants: participants,
    );

    setState(() {
      if (editIndex != null) {
        _event.details[editIndex] = newExpense;
      } else {
        _event.details.add(newExpense);
      }
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
      setState(() => _event.details.removeAt(index));
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
      totals[m] = totals[m] ?? 0;
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
      final per = e.amount ~/ e.participants.length;
      for (final p in e.participants) {
        owes[p] = (owes[p] ?? 0) + per;
      }
    }

    final balances = <String, int>{};
    for (final m in _event.members) {
      balances[m] = (totals[m] ?? 0) - (owes[m] ?? 0);
    }
    return balances;
  }

  List<String> _calcSettlement() {
    final balances = _calcTotals();
    final payers = balances.entries
        .where((e) => e.value < 0)
        .map((e) => {'name': e.key, 'amount': -e.value})
        .toList();
    final receivers = balances.entries
        .where((e) => e.value > 0)
        .map((e) => {'name': e.key, 'amount': e.value})
        .toList();

    final result = <String>[];
    for (final payer in payers) {
      var amount = payer['amount'] as int;
      for (final receiver in receivers) {
        var recvAmount = receiver['amount'] as int;
        if (recvAmount <= 0) continue;
        final pay = amount < recvAmount ? amount : recvAmount;
        if (pay > 0) {
          result.add("${payer['name']} → ${receiver['name']} に ${pay}円");
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_event.name),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareSummary),
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
                  title: Text(m),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        onPressed: () => _editMemberName(m),
                        icon: const Icon(Icons.edit, color: Colors.orange),
                      ),
                      IconButton(
                        onPressed: () => _deleteMember(m),
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
            ..._event.details.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return Card(
                child: ListTile(
                  title: Text(e.item),
                  subtitle: Text(
                    "支払い者: ${e.payer}\n金額: ${e.amount}円\n参加者: ${e.participants.join(', ')}",
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
              );
            }),
            const Divider(),

            // ----------------------
            // 各メンバー支払合計（足し引きなし）
            // ----------------------
            const Text(
              '各メンバーの支払合計金額',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...paidTotals.entries.map((e) {
              return Text(
                "${e.key}: ${e.value}円",
                style: const TextStyle(fontSize: 16),
              );
            }),
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
                "${e.key}: $sign${e.value}円",
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
  final List<String> members;
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
  final Map<String, TextEditingController> _controllers = {};
  String? _payer;
  String _mode = "manual";

  @override
  void initState() {
    super.initState();
    _itemController.text = widget.editExpense?.item ?? "";
    _totalController.text = widget.editExpense?.amount.toString() ?? "0";

    final edit = widget.editExpense;
    final participants = edit?.participants ?? [];
    final amount = edit?.amount ?? 0;
    final per = participants.isNotEmpty ? (amount ~/ participants.length) : 0;

    for (final m in widget.members) {
      _controllers[m] = TextEditingController(
        text: participants.contains(m) ? per.toString() : "0",
      );
    }

    _payer =
        widget.editExpense?.payer ??
        (widget.members.isNotEmpty ? widget.members.first : null);
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
        _controllers[m]!.text = (i < remainder ? per + 1 : per).toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.editExpense != null ? "明細を編集" : "明細を追加"),
      content: SingleChildScrollView(
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
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "支払い金額"),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _payer,
              decoration: const InputDecoration(labelText: "支払い者"),
              items: widget.members
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _payer = v),
            ),
            const Divider(),
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
              return Row(
                children: [
                  Expanded(child: Text(m)),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _controllers[m],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(suffixText: "円"),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
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
          onPressed: () {
            if (subtotal != total) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("合計が一致していません")));
              return;
            }
            final result = {
              "item": _itemController.text.trim(),
              "payer": _payer,
              "total": total,
              "shares": {
                for (final m in widget.members)
                  m: int.tryParse(_controllers[m]!.text) ?? 0,
              },
            };
            Navigator.pop(context, result);
          },
          child: const Text("登録"),
        ),
      ],
    );
  }
}
