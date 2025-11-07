import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';

// ----------------------
// イベント詳細ページ
// ----------------------
class EventDetailPage extends StatefulWidget {
  final Event event;
  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late Event _event;

  final TextEditingController _memberController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String? _selectedPayer;
  final Set<String> _selectedParticipants = {};

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  /// イベントデータを保存
  Future<void> _saveEvent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('event_${_event.id}', jsonEncode(_event.toJson()));
    setState(() {}); // ← 再描画（集計更新のため）
  }

  /// メンバー追加
  Future<void> _addMember() async {
    final name = _memberController.text.trim();
    if (name.isEmpty) return;

    if (_event.members.contains(name)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「$name」はすでに登録されています')));
      return;
    }

    setState(() {
      _event.members.add(name);
    });
    await _saveEvent();
    _memberController.clear();
  }

  /// メンバー削除
  Future<void> _deleteMember(String name) async {
    setState(() {
      _event.members.remove(name);
      _event.details.removeWhere(
        (e) => e.payer == name || e.participants.contains(name),
      );
    });
    await _saveEvent();
  }

  /// メンバー名編集
  Future<void> _editMemberName(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メンバー名を編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新しい名前',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      if (_event.members.contains(newName)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('「$newName」はすでに存在します')));
        return;
      }

      setState(() {
        final index = _event.members.indexOf(oldName);
        if (index != -1) {
          _event.members[index] = newName;
        }
        // 明細にも反映
        for (var e in _event.details) {
          if (e.payer == oldName) e.payer = newName;
          e.participants = e.participants
              .map((p) => p == oldName ? newName : p)
              .toList();
        }
      });
      await _saveEvent();
    }
  }

  /// 支出追加
  Future<void> _addExpense() async {
    final item = _itemController.text.trim();
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (item.isEmpty || _selectedPayer == null || amount <= 0) return;

    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('少なくとも1人の参加者を選択してください')));
      return;
    }

    setState(() {
      _event.details.add(
        Expense(
          item: item,
          payer: _selectedPayer!,
          amount: amount,
          participants: _selectedParticipants.toList(),
        ),
      );
    });

    _itemController.clear();
    _amountController.clear();
    _selectedParticipants.clear();
    _selectedPayer = null;

    await _saveEvent();
  }

  /// 支出削除
  Future<void> _deleteExpense(int index) async {
    setState(() {
      _event.details.removeAt(index);
    });
    await _saveEvent();
  }

  /// メンバーごとの支出合計
  Map<String, int> _calcTotals() {
    final totals = <String, int>{for (var m in _event.members) m: 0};
    for (var e in _event.details) {
      totals[e.payer] = (totals[e.payer] ?? 0) + e.amount;
    }
    return totals;
  }

  /// 精算計算
  List<String> _calcSettlement() {
    final totals = _calcTotals();
    if (_event.members.isEmpty) return [];

    final totalAmount = totals.values.fold<int>(0, (a, b) => a + b);
    final avg = totalAmount / _event.members.length;

    final creditors = <String, double>{};
    final debtors = <String, double>{};
    for (var e in totals.entries) {
      final diff = e.value - avg;
      if (diff > 0) creditors[e.key] = diff;
      if (diff < 0) debtors[e.key] = -diff;
    }

    final results = <String>[];
    final cList = creditors.entries.toList();
    final dList = debtors.entries.toList();

    for (var c in cList) {
      double cValue = c.value;
      for (var d in dList) {
        if (cValue <= 0) break;
        if (d.value <= 0) continue;

        final pay = cValue < d.value ? cValue : d.value;
        results.add('${d.key} → ${c.key} に ${pay.round()}円支払い');
        cValue -= pay;
        dList[dList.indexOf(d)] = MapEntry(d.key, d.value - pay);
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calcTotals();
    final settlements = _calcSettlement();

    return Scaffold(
      appBar: AppBar(title: Text(_event.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === 基本情報 ===
            Text('イベントID: ${_event.id}'),
            Text('メンバー数: ${_event.members.length}人'),
            Text('支出件数: ${_event.details.length}件'),
            const Divider(height: 32),

            // === メンバー追加 ===
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
                  icon: const Icon(Icons.person_add, color: Colors.blue),
                  tooltip: 'メンバーを追加',
                  onPressed: _addMember,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // === メンバー一覧 ===
            const Text(
              '👥 メンバー一覧',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _event.members.isEmpty
                ? const Text('メンバーはまだ登録されていません')
                : Column(
                    children: _event.members.map((m) {
                      return Card(
                        child: ListTile(
                          title: Text(m),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.orange,
                                ),
                                tooltip: '編集',
                                onPressed: () => _editMemberName(m),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: '削除',
                                onPressed: () => _deleteMember(m),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

            const Divider(height: 32),

            // === 支出追加フォーム ===
            const Text(
              '💸 支出を追加',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _itemController,
              decoration: const InputDecoration(
                labelText: '項目名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedPayer,
              decoration: const InputDecoration(
                labelText: '支払者',
                border: OutlineInputBorder(),
              ),
              items: _event.members
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedPayer = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '金額',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _event.members.map((m) {
                final selected = _selectedParticipants.contains(m);
                return FilterChip(
                  label: Text(m),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      v
                          ? _selectedParticipants.add(m)
                          : _selectedParticipants.remove(m);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _addExpense,
              icon: const Icon(Icons.add),
              label: const Text('支出を追加'),
            ),

            const Divider(height: 32),

            // === 支出一覧 ===
            const Text(
              '📋 支出明細',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            _event.details.isEmpty
                ? const Text('支出はまだ登録されていません')
                : Column(
                    children: List.generate(_event.details.length, (i) {
                      final e = _event.details[i];
                      return Card(
                        child: ListTile(
                          title: Text('${e.item} (${e.amount}円)'),
                          subtitle: Text(
                            '支払者: ${e.payer}\n参加者: ${e.participants.join(", ")}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: '削除',
                            onPressed: () => _deleteExpense(i),
                          ),
                        ),
                      );
                    }),
                  ),

            const Divider(height: 32),

            // === 支出合計 ===
            const Text(
              '💰 メンバーごとの支出合計',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...totals.entries.map((e) => Text('${e.key}: ${e.value}円')),

            const Divider(height: 32),

            // === 精算結果 ===
            const Text(
              '⚖️ 精算結果',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            settlements.isEmpty
                ? const Text('精算は不要です')
                : Column(children: settlements.map((s) => Text(s)).toList()),

            const SizedBox(height: 24),
            const Divider(),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('戻る'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
