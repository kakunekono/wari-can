import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/expense_item.dart';

class EventDetailPage extends StatefulWidget {
  final Map<String, dynamic> eventData;
  const EventDetailPage({super.key, required this.eventData});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late String eventName;
  String? startDate;
  String? endDate;

  List<String> members = [];
  List<ExpenseItem> details = [];

  final memberController = TextEditingController();
  final itemController = TextEditingController();
  final amountController = TextEditingController();

  String? selectedPayer;
  final Map<String, bool> selectedParticipants = {};
  List<String> settlementResults = [];
  int? editingIndex;

  @override
  void initState() {
    super.initState();
    eventName = widget.eventData['name'] ?? '';
    startDate = widget.eventData['start'];
    endDate = widget.eventData['end'];
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(eventName);
    if (data != null) {
      final decoded = jsonDecode(data);
      setState(() {
        members = List<String>.from(decoded['members']);
        details = (decoded['details'] as List).map((e) => ExpenseItem.fromJson(e)).toList();
        for (var m in members) selectedParticipants[m] = false;
        _updateSettlement();
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'members': members,
      'details': details.map((e) => e.toJson()).toList(),
      'start': startDate,
      'end': endDate,
    });
    await prefs.setString(eventName, data);
  }

  void _addMember() {
    if (memberController.text.isEmpty) return;
    setState(() {
      members.add(memberController.text);
      selectedParticipants[memberController.text] = false;
      memberController.clear();
      _saveData();
    });
  }

  void _addOrUpdateDetail() {
    final item = itemController.text.trim();
    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    if (item.isEmpty || selectedPayer == null || amount <= 0) return;

    final participants = selectedParticipants.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (participants.isEmpty) return;

    final detail = ExpenseItem(
      item: item,
      payer: selectedPayer!,
      amount: amount,
      participants: participants,
    );

    setState(() {
      if (editingIndex != null) {
        details[editingIndex!] = detail;
        editingIndex = null;
      } else {
        details.add(detail);
      }
      itemController.clear();
      amountController.clear();
      selectedPayer = null;
      selectedParticipants.updateAll((key, value) => false);
      _updateSettlement();
      _saveData();
    });
  }

  void _editDetail(int index) {
    final d = details[index];
    itemController.text = d.item;
    amountController.text = d.amount.toString();
    selectedPayer = d.payer;
    selectedParticipants.updateAll((key, value) => d.participants.contains(key));
    setState(() {
      editingIndex = index;
    });
  }

  void _deleteDetail(int index) {
    setState(() {
      details.removeAt(index);
      _updateSettlement();
      _saveData();
    });
  }

  void _updateSettlement() {
    final Map<String, double> balances = {for (var m in members) m: 0.0};

    for (final d in details) {
      final payer = d.payer;
      final amount = d.amount.toDouble();
      final participants = d.participants;
      final share = amount / participants.length;

      balances[payer] = (balances[payer] ?? 0) + amount;
      for (final p in participants) {
        balances[p] = (balances[p] ?? 0) - share;
      }
    }

    final creditors = balances.entries.where((e) => e.value > 0).toList();
    final debtors = balances.entries.where((e) => e.value < 0).toList();

    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => a.value.compareTo(b.value));

    final List<String> results = [];
    int ci = 0, di = 0;

    while (ci < creditors.length && di < debtors.length) {
      final c = creditors[ci];
      final d = debtors[di];
      final amount = [c.value, -d.value].reduce((a, b) => a < b ? a : b);

      results.add("${d.key} → ${c.key} に ${amount.toInt()}円");

      creditors[ci] = MapEntry(c.key, c.value - amount);
      debtors[di] = MapEntry(d.key, d.value + amount);

      if (creditors[ci].value.abs() < 1) ci++;
      if (debtors[di].value.abs() < 1) di++;
    }

    setState(() => settlementResults = results);
  }

  Future<void> _pickDate(TextEditingController controller, Function(String) onSelect) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final formatted = picked.toIso8601String().substring(0, 10);
      onSelect(formatted);
      _saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final startController = TextEditingController(text: startDate);
    final endController = TextEditingController(text: endDate);

    return Scaffold(
      appBar: AppBar(title: Text(eventName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('イベント情報', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: startController,
                  decoration: const InputDecoration(labelText: '開始日 (任意)'),
                  readOnly: true,
                  onTap: () => _pickDate(startController, (val) => setState(() => startDate = val)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: endController,
                  decoration: const InputDecoration(labelText: '終了日 (任意)'),
                  readOnly: true,
                  onTap: () => _pickDate(endController, (val) => setState(() => endDate = val)),
                ),
              ),
            ],
          ),
          const Divider(),

          const Text('メンバー追加', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: TextField(controller: memberController, decoration: const InputDecoration(labelText: '名前')),
              ),
              IconButton(onPressed: _addMember, icon: const Icon(Icons.person_add)),
            ],
          ),
          Wrap(spacing: 8, children: members.map((m) => Chip(label: Text(m))).toList()),
          const Divider(),

          const Text('明細入力', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: itemController, decoration: const InputDecoration(labelText: '項目名')),
          TextField(controller: amountController, decoration: const InputDecoration(labelText: '金額'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          const Text('支払者を選択'),
          Wrap(
            spacing: 8,
            children: members
                .map((m) => ChoiceChip(
                      label: Text(m),
                      selected: selectedPayer == m,
                      onSelected: (_) => setState(() => selectedPayer = m),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          const Text('参加者を選択'),
          Wrap(
            spacing: 8,
            children: members
                .map((m) => FilterChip(
                      label: Text(m),
                      selected: selectedParticipants[m] ?? false,
                      onSelected: (v) => setState(() => selectedParticipants[m] = v),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _addOrUpdateDetail,
            icon: const Icon(Icons.add),
            label: Text(editingIndex != null ? '明細を更新' : '明細を追加'),
          ),
          const Divider(),

          const Text('明細一覧', style: TextStyle(fontWeight: FontWeight.bold)),
          ...details.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text('${d.item} (${d.amount}円)'),
                subtitle: Text('支払: ${d.payer} / 参加: ${d.participants.join(', ')}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _editDetail(i)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteDetail(i)),
                  ],
                ),
              ),
            );
          }),
          const Divider(),

          const Text('💰 精算結果', style: TextStyle(fontWeight: FontWeight.bold)),
          if (settlementResults.isEmpty)
            const Text('まだ明細がありません。')
          else
            ...settlementResults.map((r) => ListTile(title: Text(r))),
        ]),
      ),
    );
  }
}
