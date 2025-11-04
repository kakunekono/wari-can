import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../models/expense_item.dart';
import '../widgets/expense_input_form.dart';
import '../widgets/expense_list.dart';
import '../widgets/settlement_summary.dart';

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
  Map<String, double> paymentTotals = {};
  Map<String, List<String>> personalDetails = {};
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

  Future<void> _saveAndReturn() async {
    await _saveData();
    Navigator.pop(context, {'name': eventName, 'start': startDate, 'end': endDate});
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
    final participants = selectedParticipants.entries.where((e) => e.value).map((e) => e.key).toList();
    if (participants.isEmpty) return;

    final detail = ExpenseItem(item: item, payer: selectedPayer!, amount: amount, participants: participants);

    setState(() {
      if (editingIndex != null) {
        details[editingIndex!] = detail;
        editingIndex = null;
      } else {
        details.add(detail);
      }
      itemController.clear();
      amountController.clear();
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
    final balances = {for (var m in members) m: 0.0};
    final totals = {for (var m in members) m: 0.0};
    personalDetails = {for (var m in members) m: []};

    for (final d in details) {
      final payer = d.payer;
      final amount = d.amount.toDouble();
      final participants = d.participants;
      final share = amount / participants.length;

      totals[payer] = (totals[payer] ?? 0) + amount;
      balances[payer] = (balances[payer] ?? 0) + amount;

      for (final p in participants) {
        balances[p] = (balances[p] ?? 0) - share;
        personalDetails[p]!.add('${d.item} ${share.toInt()}円 (支払者: ${d.payer})');
      }
    }

    paymentTotals = totals;

    final creditors = balances.entries.where((e) => e.value > 0).toList();
    final debtors = balances.entries.where((e) => e.value < 0).toList();

    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => a.value.compareTo(b.value));

    final results = <String>[];
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

  void _shareSettlement() {
    final buffer = StringBuffer();
    buffer.writeln('【イベント名】$eventName');
    buffer.writeln('開始: ${startDate ?? '-'}  終了: ${endDate ?? '-'}\n');

    buffer.writeln('--- 明細一覧（支払者別） ---');
    for (final member in members) {
      final paidDetails = details.where((d) => d.payer == member).toList();
      if (paidDetails.isEmpty) continue;

      paidDetails.sort((a, b) {
        final itemCompare = a.item.compareTo(b.item);
        if (itemCompare != 0) return itemCompare;
        final aP = a.participants.isNotEmpty ? a.participants.first : '';
        final bP = b.participants.isNotEmpty ? b.participants.first : '';
        return aP.compareTo(bP);
      });

      buffer.writeln('\n$member の支払明細:');
      for (final d in paidDetails) {
        buffer.writeln('  ${d.item} (${d.amount}円)  参加者: ${d.participants.join(', ')}');
      }
    }

    buffer.writeln('\n--- 各自の支払合計 ---');
    paymentTotals.forEach((key, value) => buffer.writeln('$key: ${value.toInt()}円'));

    buffer.writeln('\n--- 精算結果 ---');
    settlementResults.forEach((s) => buffer.writeln(s));

    Share.share(buffer.toString(), subject: '割り勘精算結果');
  }

  @override
  Widget build(BuildContext context) {
    final startController = TextEditingController(text: startDate);
    final endController = TextEditingController(text: endDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(eventName),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _saveAndReturn),
      ),
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
              Expanded(child: TextField(controller: memberController, decoration: const InputDecoration(labelText: '名前'))),
              IconButton(onPressed: _addMember, icon: const Icon(Icons.person_add)),
            ],
          ),
          Wrap(spacing: 8, children: members.map((m) => Chip(label: Text(m))).toList()),
          const Divider(),
          ExpenseInputForm(
            itemController: itemController,
            amountController: amountController,
            selectedPayer: selectedPayer,
            selectedParticipants: selectedParticipants,
            members: members,
            onSelectPayer: (m) => setState(() => selectedPayer = m),
            onSelectParticipant: (m, val) => setState(() => selectedParticipants[m] = val),
            onAddOrUpdate: _addOrUpdateDetail,
            isEditing: editingIndex != null,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _shareSettlement,
            icon: const Icon(Icons.share),
            label: const Text('精算結果を共有'),
          ),
          const Divider(),
          const Text('明細一覧（支払者別）', style: TextStyle(fontWeight: FontWeight.bold)),
          ExpenseList(members: members, details: details, onEdit: _editDetail, onDelete: _deleteDetail),
          const Divider(),
          SettlementSummary(paymentTotals: paymentTotals, settlementResults: settlementResults),
        ]),
      ),
    );
  }
}
