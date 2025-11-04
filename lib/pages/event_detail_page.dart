import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_item.dart';

class EventDetailPage extends StatefulWidget {
  final String eventName;
  const EventDetailPage({super.key, required this.eventName});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  List<String> members = [];
  List<ExpenseItem> details = [];

  final memberController = TextEditingController();
  final itemController = TextEditingController();
  final payerController = TextEditingController();
  final amountController = TextEditingController();
  final participantsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(widget.eventName);
    if (data != null) {
      final decoded = jsonDecode(data);
      setState(() {
        members = List<String>.from(decoded['members']);
        details = (decoded['details'] as List)
            .map((d) => ExpenseItem.fromJson(d))
            .toList();
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'members': members,
      'details': details.map((e) => e.toJson()).toList(),
    });
    await prefs.setString(widget.eventName, data);
  }

  void _addMember() {
    if (memberController.text.isEmpty) return;
    setState(() => members.add(memberController.text));
    memberController.clear();
    _saveData();
  }

  void _addDetail() {
    if (itemController.text.isEmpty ||
        payerController.text.isEmpty ||
        amountController.text.isEmpty) return;

    final detail = ExpenseItem(
      item: itemController.text,
      payer: payerController.text,
      amount: int.tryParse(amountController.text) ?? 0,
      participants:
          participantsController.text.split(',').map((s) => s.trim()).toList(),
    );

    setState(() => details.add(detail));

    itemController.clear();
    payerController.clear();
    amountController.clear();
    participantsController.clear();

    _saveData();
  }

  void _editDetail(int index) {
    final d = details[index];
    itemController.text = d.item;
    payerController.text = d.payer;
    amountController.text = d.amount.toString();
    participantsController.text = d.participants.join(', ');
    setState(() => details.removeAt(index));
    _saveData();
  }

  void _deleteDetail(int index) {
    setState(() => details.removeAt(index));
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.eventName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('👥 メンバー追加', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('🧾 明細入力', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: itemController, decoration: const InputDecoration(labelText: '項目名')),
            TextField(controller: payerController, decoration: const InputDecoration(labelText: '支払者')),
            TextField(controller: amountController, decoration: const InputDecoration(labelText: '金額'), keyboardType: TextInputType.number),
            TextField(controller: participantsController, decoration: const InputDecoration(labelText: '参加者(カンマ区切り)')),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _addDetail,
              icon: const Icon(Icons.add),
              label: const Text('明細を追加'),
            ),
            const Divider(),
            const Text('📋 明細一覧', style: TextStyle(fontWeight: FontWeight.bold)),
            ...details.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('${d.item}  (${d.amount}円)'),
                  subtitle: Text('支払者: ${d.payer}\n参加者: ${d.participants.join(', ')}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _editDetail(i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteDetail(i),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
