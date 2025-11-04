import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/expense_item.dart';

class EventDetailPage extends StatefulWidget {
  final String eventName;
  const EventDetailPage({super.key, required this.eventName});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  List<String> members = [];
  List<ExpenseItem> expenses = [];

  final memberController = TextEditingController();
  final itemController = TextEditingController();
  final payerController = TextEditingController();
  final amountController = TextEditingController();
  final participantsController = TextEditingController();

  Map<String, int> balances = {}; // 各メンバーの差額

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // -----------------------------
  // データ読み込み／保存
  // -----------------------------
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // メンバー
    members = prefs.getStringList('${widget.eventName}_members') ?? [];

    // 明細
    final raw = prefs.getStringList('${widget.eventName}_expenses') ?? [];
    expenses = raw.map((e) => ExpenseItem.fromJson(jsonDecode(e))).toList();

    _recalculateBalances();
    setState(() {});
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('${widget.eventName}_members', members);
    final encoded = expenses.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('${widget.eventName}_expenses', encoded);
  }

  // -----------------------------
  // メンバー・明細操作
  // -----------------------------
  void _addMember() {
    if (memberController.text.isEmpty) return;
    setState(() {
      members.add(memberController.text.trim());
      memberController.clear();
    });
    _saveData();
  }

  void _addExpense() {
    if (itemController.text.isEmpty ||
        payerController.text.isEmpty ||
        amountController.text.isEmpty) return;

    final expense = ExpenseItem(
      item: itemController.text,
      payer: payerController.text,
      amount: int.tryParse(amountController.text) ?? 0,
      participants: participantsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );

    setState(() {
      expenses.add(expense);
      itemController.clear();
      payerController.clear();
      amountController.clear();
      participantsController.clear();
    });

    _saveData();
    _recalculateBalances();
  }

  void _editExpense(int index) {
    final e = expenses[index];
    itemController.text = e.item;
    payerController.text = e.payer;
    amountController.text = e.amount.toString();
    participantsController.text = e.participants.join(', ');
    setState(() => expenses.removeAt(index));
    _saveData();
    _recalculateBalances();
  }

  void _deleteExpense(int index) {
    setState(() => expenses.removeAt(index));
    _saveData();
    _recalculateBalances();
  }

  // -----------------------------
  // 精算計算
  // -----------------------------
  void _recalculateBalances() {
    final Map<String, int> paid = {};
    final Map<String, int> owed = {};

    for (final e in expenses) {
      final each = e.participants.isEmpty
          ? 0
          : (e.amount / e.participants.length).round();

      // 支払者は全額を出した
      paid[e.payer] = (paid[e.payer] ?? 0) + e.amount;

      // 参加者はそれぞれ負担
      for (final p in e.participants) {
        owed[p] = (owed[p] ?? 0) + each;
      }
    }

    // 差額計算
    balances = {};
    for (final m in members) {
      final totalPaid = paid[m] ?? 0;
      final totalOwed = owed[m] ?? 0;
      balances[m] = totalPaid - totalOwed;
    }
    setState(() {});
  }

  List<String> _calculateSettlements() {
    final creditors = <String, int>{};
    final debtors = <String, int>{};

    balances.forEach((name, balance) {
      if (balance > 0) {
        creditors[name] = balance;
      } else if (balance < 0) {
        debtors[name] = -balance;
      }
    });

    final results = <String>[];

    final creditorList = creditors.entries.toList();
    final debtorList = debtors.entries.toList();

    int ci = 0, di = 0;
    while (ci < creditorList.length && di < debtorList.length) {
      final c = creditorList[ci];
      final d = debtorList[di];
      final amount = c.value < d.value ? c.value : d.value;
      results.add('${d.key} → ${c.key} に ${amount}円支払う');

      creditorList[ci] = MapEntry(c.key, c.value - amount);
      debtorList[di] = MapEntry(d.key, d.value - amount);

      if (creditorList[ci].value == 0) ci++;
      if (debtorList[di].value == 0) di++;
    }

    return results;
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final settlements = _calculateSettlements();

    return Scaffold(
      appBar: AppBar(title: Text(widget.eventName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- メンバー入力 ---
            const Text('メンバー追加', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: memberController,
                    decoration: const InputDecoration(labelText: '名前'),
                  ),
                ),
                IconButton(onPressed: _addMember, icon: const Icon(Icons.person_add))
              ],
            ),
            Wrap(
              spacing: 8,
              children: members.map((m) => Chip(label: Text(m))).toList(),
            ),
            const Divider(),

            // --- 明細入力 ---
            const Text('明細入力', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: itemController, decoration: const InputDecoration(labelText: '項目名')),
            TextField(controller: payerController, decoration: const InputDecoration(labelText: '支払者')),
            TextField(controller: amountController, decoration: const InputDecoration(labelText: '金額'), keyboardType: TextInputType.number),
            TextField(controller: participantsController, decoration: const InputDecoration(labelText: '参加者(カンマ区切り)')),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _addExpense,
              icon: const Icon(Icons.add),
              label: const Text('明細を追加'),
            ),
            const Divider(),

            // --- 明細一覧 ---
            const Text('明細一覧', style: TextStyle(fontWeight: FontWeight.bold)),
            ...expenses.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('${e.item} (${e.amount}円)'),
                  subtitle: Text('支払者: ${e.payer}\n参加者: ${e.participants.join(', ')}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _editExpense(i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteExpense(i),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            const Divider(),

            // --- 精算結果 ---
            const Text('精算結果', style: TextStyle(fontWeight: FontWeight.bold)),
            if (settlements.isEmpty)
              const Text('未計算または全員の収支が均等です。')
            else
              ...settlements.map(
                (s) => Card(
                  color: Colors.green.withOpacity(0.1),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(s),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
