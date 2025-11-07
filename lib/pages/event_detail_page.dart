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
  List<String> _selectedParticipants = [];

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  /// イベントデータを保存
  Future<void> _saveEvent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('event_${_event.id}', jsonEncode(_event.toJson()));
    setState(() {}); // 更新反映
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
    _memberController.clear();
    await _saveEvent();
  }

  /// メンバー削除
  Future<void> _deleteMember(String name) async {
    setState(() {
      _event.members.remove(name);
      _event.details.removeWhere(
        (d) => d.payer == name || d.participants.contains(name),
      ); // 関連明細も削除
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
        if (index != -1) _event.members[index] = newName;
        // 明細内のpayerやparticipantsも更新
        for (final d in _event.details) {
          if (d.payer == oldName) d.payer = newName;
          for (int i = 0; i < d.participants.length; i++) {
            if (d.participants[i] == oldName) d.participants[i] = newName;
          }
        }
      });
      await _saveEvent();
    }
  }

  /// 支出明細追加
  Future<void> _addExpense() async {
    final item = _itemController.text.trim();
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (item.isEmpty ||
        _selectedPayer == null ||
        _selectedParticipants.isEmpty ||
        amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('全ての項目を正しく入力してください')));
      return;
    }

    final expense = Expense(
      item: item,
      payer: _selectedPayer!,
      amount: amount,
      participants: List<String>.from(_selectedParticipants),
    );

    setState(() {
      _event.details.add(expense);
      _itemController.clear();
      _amountController.clear();
      _selectedPayer = null;
      _selectedParticipants = [];
    });

    await _saveEvent();
  }

  /// 支出明細削除
  Future<void> _deleteExpense(int index) async {
    setState(() {
      _event.details.removeAt(index);
    });
    await _saveEvent();
  }

  /// メンバーごとの精算計算
  Map<String, Map<String, int>> calcSettlement() {
    final totals = <String, int>{};
    final owes = <String, int>{};

    for (final m in _event.members) {
      totals[m] = 0;
      owes[m] = 0;
    }

    for (final e in _event.details) {
      totals[e.payer] = (totals[e.payer] ?? 0) + e.amount;
      final perPerson = (e.amount / e.participants.length).round();
      for (final p in e.participants) {
        owes[p] = (owes[p] ?? 0) + perPerson;
      }
    }

    final balances = <String, int>{};
    for (final m in _event.members) {
      balances[m] = (totals[m] ?? 0) - (owes[m] ?? 0);
    }

    // receivers, payers をコピーして Map 上で操作
    final receiverBalances = <String, int>{};
    balances.forEach((k, v) {
      if (v > 0) receiverBalances[k] = v;
    });
    final payers = balances.entries.where((e) => e.value < 0).toList();

    final settlement = <String, Map<String, int>>{};

    for (final p in payers) {
      var remaining = -p.value;
      for (final rKey in receiverBalances.keys) {
        if (receiverBalances[rKey]! <= 0) continue;
        final payAmount = remaining <= receiverBalances[rKey]!
            ? remaining
            : receiverBalances[rKey]!;
        settlement[p.key] ??= {};
        settlement[p.key]![rKey] = payAmount;
        receiverBalances[rKey] = receiverBalances[rKey]! - payAmount;
        remaining -= payAmount;
        if (remaining <= 0) break;
      }
    }

    return settlement;
  }

  @override
  Widget build(BuildContext context) {
    final settlement = calcSettlement();

    return Scaffold(
      appBar: AppBar(title: Text(_event.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基本情報
            Text('イベントID: ${_event.id}'),
            const SizedBox(height: 8),
            Text('メンバー数: ${_event.members.length}人'),
            const SizedBox(height: 8),
            Text('支出件数: ${_event.details.length}件'),
            const Divider(height: 32),

            // メンバー追加欄
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

            // メンバー一覧
            const Text(
              'メンバー一覧',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _event.members.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('メンバーはまだ登録されていません'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _event.members.length,
                    itemBuilder: (context, index) {
                      final member = _event.members[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(member),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.orange,
                                ),
                                tooltip: '編集',
                                onPressed: () => _editMemberName(member),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: '削除',
                                onPressed: () => _deleteMember(member),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),
            const Divider(),

            // 支出明細追加
            const Text(
              '支出明細追加',
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
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '金額',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedPayer,
              hint: const Text('支払者を選択'),
              isExpanded: true,
              items: _event.members
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedPayer = v),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _event.members
                  .map(
                    (m) => FilterChip(
                      label: Text(m),
                      selected: _selectedParticipants.contains(m),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedParticipants.add(m);
                          } else {
                            _selectedParticipants.remove(m);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('支出明細を追加'),
              onPressed: _addExpense,
            ),
            const SizedBox(height: 16),

            // 支出明細一覧
            const Text(
              '支出明細一覧',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _event.details.isEmpty
                ? const Text('まだ支出明細はありません')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _event.details.length,
                    itemBuilder: (context, index) {
                      final e = _event.details[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text('${e.item} (${e.amount}円)'),
                          subtitle: Text(
                            '支払者: ${e.payer}\n参加者: ${e.participants.join(', ')}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: '削除',
                            onPressed: () => _deleteExpense(index),
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),
            const Divider(),

            // 精算結果
            const Text(
              '精算結果',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            settlement.isEmpty
                ? const Text('精算不要')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: settlement.entries
                        .map(
                          (e) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: e.value.entries
                                .map(
                                  (r) =>
                                      Text('${e.key} → ${r.key}: ${r.value}円'),
                                )
                                .toList(),
                          ),
                        )
                        .toList(),
                  ),
            const SizedBox(height: 24),
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
