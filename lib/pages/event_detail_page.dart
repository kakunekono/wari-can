// lib/pages/event_detail_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../models/expense_item.dart';

class EventDetailPage extends StatefulWidget {
  /// 期待する eventData の構造:
  /// {
  ///   'id': 'uuid',    // できれば必須
  ///   'name': 'イベント名',
  ///   'start': 'YYYY-MM-DD' or null,
  ///   'end': 'YYYY-MM-DD' or null,
  ///   'members': [...],
  /// }
  const EventDetailPage({super.key, required this.eventData});
  final Map<String, dynamic> eventData;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late String eventId;
  late String eventName;
  String? startDate;
  String? endDate;

  List<String> members = [];
  List<ExpenseItem> details = [];

  String? selectedPayer;
  Map<String, List<String>> personalDetails = {}; // 個人別明細
  Map<String, double> paymentTotals = {};
  List<String> settlementResults = [];

  @override
  void initState() {
    super.initState();
    // eventData に 'id' がある前提（main側で付与済み）
    // もしない場合は eventName をキーにフォールバック（互換性確保）
    eventId =
        widget.eventData['id']?.toString() ?? widget.eventData['name'] ?? '';
    eventName = widget.eventData['name'] ?? '';
    startDate = widget.eventData['start'];
    endDate = widget.eventData['end'];

    _loadEventMetaAndExpenses();
  }

  String _eventMetaKey() => 'event_$eventId';
  String _eventExpensesKey() => 'expenses_$eventId';

  Future<void> _loadEventMetaAndExpenses() async {
    final prefs = await SharedPreferences.getInstance();

    // イベントメタ (members, start, end, name) をロード（存在すれば上書き）
    final metaString = prefs.getString(_eventMetaKey());
    if (metaString != null) {
      try {
        final decoded = jsonDecode(metaString);
        setState(() {
          eventName = decoded['name'] ?? eventName;
          startDate = decoded['start'];
          endDate = decoded['end'];
          members = List<String>.from(decoded['members'] ?? []);
        });
      } catch (_) {
        // parse error は無視して既存の値を使う
      }
    } else {
      // フォールバック: widget.eventData に members があれば使う
      setState(() {
        members = List<String>.from(widget.eventData['members'] ?? []);
      });
    }

    // 明細 (expenses_<id>) をロード
    final expenseList = prefs.getStringList(_eventExpensesKey()) ?? [];
    setState(() {
      details = expenseList.map((e) {
        final decoded = jsonDecode(e) as Map<String, dynamic>;
        return ExpenseItem.fromJson(decoded);
      }).toList();
    });

    _updateSettlement();
  }

  Future<void> _saveEventMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final meta = jsonEncode({
      'id': eventId,
      'name': eventName,
      'start': startDate,
      'end': endDate,
      'members': members,
    });
    await prefs.setString(_eventMetaKey(), meta);
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final list = details.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_eventExpensesKey(), list);
  }

  Future<void> _saveAllAndReturn() async {
    await _saveEventMeta();
    await _saveExpenses();

    // 戻り値はイベント名と日付情報（必要なら id も返せます）
    Navigator.pop(context, {
      'id': eventId,
      'name': eventName,
      'start': startDate,
      'end': endDate,
    });
  }

  void _addMember(String name) {
    if (name.isEmpty) return;
    setState(() {
      members.add(name);
    });
    _saveEventMeta();
  }

  Future<void> _pickDate(
    TextEditingController controller,
    Function(String) onSelect,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final formatted = picked.toIso8601String().substring(0, 10);
      onSelect(formatted);
      _saveEventMeta();
    }
  }

  Future<void> _showDetailDialog({ExpenseItem? editingItem, int? index}) async {
    final itemController = TextEditingController(text: editingItem?.item ?? '');
    final amountController = TextEditingController(
      text: editingItem?.amount.toString() ?? '',
    );
    String? payer = editingItem?.payer;
    final Map<String, bool> participants = {
      for (var m in members) m: editingItem?.participants.contains(m) ?? false,
    };

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(editingItem != null ? '明細を編集' : '明細を追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: itemController,
                  decoration: const InputDecoration(labelText: '項目名'),
                ),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: '金額'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: payer,
                  decoration: const InputDecoration(labelText: '支払い者'),
                  items: members
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => payer = val),
                ),
                const SizedBox(height: 8),
                const Text('参加者'),
                Column(
                  children: members.map((m) {
                    return CheckboxListTile(
                      title: Text(m),
                      value: participants[m],
                      onChanged: (val) =>
                          setDialogState(() => participants[m] = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                final item = itemController.text.trim();
                final amount = int.tryParse(amountController.text.trim()) ?? 0;
                if (item.isEmpty || payer == null || amount <= 0) return;
                final selectedParticipants = participants.entries
                    .where((e) => e.value)
                    .map((e) => e.key)
                    .toList();
                if (selectedParticipants.isEmpty) return;

                final detail = ExpenseItem(
                  item: item,
                  payer: payer!,
                  amount: amount,
                  participants: selectedParticipants,
                );

                setState(() {
                  if (index != null) {
                    details[index] = detail;
                  } else {
                    details.add(detail);
                  }
                  _updateSettlement();
                });

                await _saveExpenses();
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteDetail(int index) async {
    setState(() {
      details.removeAt(index);
      _updateSettlement();
    });
    await _saveExpenses();
  }

  void _updateSettlement() {
    // balances: 各人がプラス（貸し）かマイナス（借り）
    final Map<String, double> balances = {for (var m in members) m: 0.0};
    final Map<String, double> totals = {for (var m in members) m: 0.0};
    personalDetails = {for (var m in members) m: []};

    for (final d in details) {
      final payer = d.payer;
      final amount = d.amount.toDouble();
      final participants = d.participants;
      if (participants.isEmpty) continue;
      final share = amount / participants.length;

      totals[payer] = (totals[payer] ?? 0) + amount;
      balances[payer] = (balances[payer] ?? 0) + amount;

      for (final p in participants) {
        balances[p] = (balances[p] ?? 0) - share;
        personalDetails[p]!.add(
          '${d.item} ${share.toInt()}円 (支払者: ${d.payer})',
        );
      }
    }

    paymentTotals = totals;

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
        final aParticipant = a.participants.isNotEmpty
            ? a.participants.first
            : '';
        final bParticipant = b.participants.isNotEmpty
            ? b.participants.first
            : '';
        return aParticipant.compareTo(bParticipant);
      });

      buffer.writeln('\n$member の支払明細:');
      for (final d in paidDetails) {
        final showParticipants = d.participants.length != members.length;
        buffer.writeln(
          '  ${d.item} (${d.amount}円)'
          '${showParticipants ? ' 参加者: ${d.participants.join(', ')}' : ''}',
        );
      }
    }

    buffer.writeln('\n--- 各自の支払合計 ---');
    paymentTotals.forEach((key, value) {
      buffer.writeln('$key: ${value.toInt()}円');
    });

    buffer.writeln('\n--- 精算結果 ---');
    settlementResults.forEach((s) => buffer.writeln(s));

    Share.share(buffer.toString(), subject: '割り勘精算結果');
  }

  @override
  Widget build(BuildContext context) {
    final startController = TextEditingController(text: startDate);
    final endController = TextEditingController(text: endDate);
    final memberController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text(eventName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _saveAllAndReturn,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('イベント情報', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startController,
                    decoration: const InputDecoration(labelText: '開始日 (任意)'),
                    readOnly: true,
                    onTap: () => _pickDate(
                      startController,
                      (val) => setState(() => startDate = val),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: endController,
                    decoration: const InputDecoration(labelText: '終了日 (任意)'),
                    readOnly: true,
                    onTap: () => _pickDate(
                      endController,
                      (val) => setState(() => endDate = val),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),

            const Text('メンバー追加', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: memberController,
                    decoration: const InputDecoration(labelText: '名前'),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _addMember(memberController.text.trim());
                    memberController.clear();
                  },
                  icon: const Icon(Icons.person_add),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: members.map((m) => Chip(label: Text(m))).toList(),
            ),
            const Divider(),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showDetailDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('明細を追加'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _shareSettlement,
                  icon: const Icon(Icons.share),
                  label: const Text('精算結果を共有'),
                ),
              ],
            ),
            const Divider(),

            const Text(
              '明細一覧（支払者別）',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...members.map((member) {
              final paidDetails = details
                  .where((d) => d.payer == member)
                  .toList();
              if (paidDetails.isEmpty) return const SizedBox.shrink();

              paidDetails.sort((a, b) {
                final itemCompare = a.item.compareTo(b.item);
                if (itemCompare != 0) return itemCompare;
                final aParticipant = a.participants.isNotEmpty
                    ? a.participants.first
                    : '';
                final bParticipant = b.participants.isNotEmpty
                    ? b.participants.first
                    : '';
                return aParticipant.compareTo(bParticipant);
              });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...paidDetails.map((d) {
                    final showParticipants =
                        d.participants.length != members.length;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        title: Text('${d.item} (${d.amount}円)'),
                        subtitle: showParticipants
                            ? Text('参加者: ${d.participants.join(', ')}')
                            : Text(""),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.orange,
                              ),
                              onPressed: () => _showDetailDialog(
                                editingItem: d,
                                index: details.indexOf(d),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteDetail(details.indexOf(d)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const Divider(),
                ],
              );
            }).toList(),

            const Text(
              '各自の支払合計',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...paymentTotals.entries
                .map((e) => Text('${e.key} は合計 ${e.value.toInt()}円 支払'))
                .toList(),
            const Divider(),

            const Text('精算結果', style: TextStyle(fontWeight: FontWeight.bold)),
            ...settlementResults.map((s) => Text(s)).toList(),
          ],
        ),
      ),
    );
  }
}
