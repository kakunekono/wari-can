// lib/main.dart
// WariCan - Minimal Flutter Web 割り勘アプリ (ステップ1)
// 実行手順:
// 1) Flutter SDK をインストール（Flutter 3.0+ を推奨）
// 2) 新規プロジェクト作成: `flutter create wari_can` 
// 3) `cd wari_can` で移動し、`web` が有効なことを確認
// 4) このファイルの内容を `lib/main.dart` に置き換える
// 5) `flutter run -d chrome` で実行（または `flutter build web`）

import 'dart:convert';
import 'dart:html' as html; // web専用: localStorage 利用

import 'package:flutter/material.dart';

void main() {
  runApp(const WariCanApp());
}

class WariCanApp extends StatelessWidget {
  const WariCanApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WariCan (割り勘アプリ) - Minimal',
      theme: ThemeData(useMaterial3: true),
      home: const EventListScreen(),
    );
  }
}

// --- Models ---
class Member {
  String id;
  String name;
  Member({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Member.fromJson(Map<String, dynamic> j) => Member(id: j['id'], name: j['name']);
}

class Expense {
  String id;
  String title;
  String payerId;
  double amount;
  List<String> participantIds;

  Expense({
    required this.id,
    required this.title,
    required this.payerId,
    required this.amount,
    required this.participantIds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'payerId': payerId,
        'amount': amount,
        'participantIds': participantIds,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'],
        title: j['title'],
        payerId: j['payerId'],
        amount: (j['amount'] as num).toDouble(),
        participantIds: List<String>.from(j['participantIds']),
      );
}

class EventData {
  String id;
  String title;
  List<Member> members;
  List<Expense> expenses;

  EventData({required this.id, required this.title, List<Member>? members, List<Expense>? expenses})
      : members = members ?? [],
        expenses = expenses ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'members': members.map((m) => m.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

  factory EventData.fromJson(Map<String, dynamic> j) => EventData(
        id: j['id'],
        title: j['title'],
        members: (j['members'] as List).map((x) => Member.fromJson(x)).toList(),
        expenses: (j['expenses'] as List).map((x) => Expense.fromJson(x)).toList(),
      );
}

// --- Persistence (localStorage) ---
class Storage {
  static const _key = 'warican_events_v1';

  static List<EventData> loadEvents() {
    try {
      final s = html.window.localStorage[_key];
      if (s == null) return [];
      final data = json.decode(s) as List;
      return data.map((e) => EventData.fromJson(e)).toList();
    } catch (e) {
      debugPrint('loadEvents error: $e');
      return [];
    }
  }

  static void saveEvents(List<EventData> events) {
    final s = json.encode(events.map((e) => e.toJson()).toList());
    html.window.localStorage[_key] = s;
  }
}

// --- Utilities ---
String _id() => DateTime.now().microsecondsSinceEpoch.toString();

Map<String, double> calculateBalances(List<EventData> events, String eventId) {
  final balances = <String, double>{};
  final event = events.firstWhere((e) => e.id == eventId);

  for (final m in event.members) {
    balances[m.id] = 0.0;
  }

  for (final ex in event.expenses) {
    if (ex.participantIds.isEmpty) continue;
    final share = ex.amount / ex.participantIds.length;
    for (final pid in ex.participantIds) {
      balances[pid] = (balances[pid] ?? 0) - share;
    }
    balances[ex.payerId] = (balances[ex.payerId] ?? 0) + ex.amount;
  }

  return balances;
}

List<Map<String, dynamic>> settleBalances(Map<String, double> balances) {
  // 単純な貪欲アルゴリズム: 支払う側(負)と受け取る側(正)をマッチング
  final results = <Map<String, dynamic>>[];

  final debtors = balances.entries.where((e) => e.value < -0.005).map((e) => MapEntry(e.key, e.value)).toList();
  final creditors = balances.entries.where((e) => e.value > 0.005).map((e) => MapEntry(e.key, e.value)).toList();

  debtors.sort((a, b) => a.value.compareTo(b.value)); // most negative first
  creditors.sort((a, b) => b.value.compareTo(a.value)); // most positive first

  int di = 0, ci = 0;
  while (di < debtors.length && ci < creditors.length) {
    final d = debtors[di];
    final c = creditors[ci];
    final payAmount = (d.value.abs() < c.value) ? d.value.abs() : c.value;

    results.add({'from': d.key, 'to': c.key, 'amount': double.parse(payAmount.toStringAsFixed(2))});

    final newD = d.value + payAmount; // d.value is negative
    final newC = c.value - payAmount;

    debtors[di] = MapEntry(d.key, newD);
    creditors[ci] = MapEntry(c.key, newC);

    if (debtors[di].value.abs() < 0.005) di++;
    if (creditors[ci].value.abs() < 0.005) ci++;
  }

  return results;
}

// --- Screens ---
class EventListScreen extends StatefulWidget {
  const EventListScreen({Key? key}) : super(key: key);

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  List<EventData> events = [];
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    events = Storage.loadEvents();
    if (events.isEmpty) {
      // sample data
      events.add(EventData(id: _id(), title: 'サンプル飲み会'));
    }
  }

  void _save() {
    Storage.saveEvents(events);
    setState(() {});
  }

  void _addEvent(String title) {
    events.add(EventData(id: _id(), title: title));
    _controller.clear();
    _save();
  }

  void _removeEvent(String id) {
    events.removeWhere((e) => e.id == id);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WariCan - イベント一覧 (Minimal)')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(labelText: '新しいイベント名'),
                  onSubmitted: (v) {
                    if (v.trim().isEmpty) return;
                    _addEvent(v.trim());
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final v = _controller.text.trim();
                  if (v.isEmpty) return;
                  _addEvent(v);
                },
                child: const Text('追加'),
              )
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: events.length,
                itemBuilder: (context, idx) {
                  final e = events[idx];
                  return Card(
                    child: ListTile(
                      title: Text(e.title),
                      subtitle: Text('${e.members.length} 人, ${e.expenses.length} 件'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_forever),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('削除確認'),
                            content: const Text('このイベントを削除しますか？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
                              TextButton(
                                onPressed: () {
                                  _removeEvent(e.id);
                                  Navigator.pop(context);
                                },
                                child: const Text('削除', style: TextStyle(color: Colors.red)),
                              )
                            ],
                          ),
                        ),
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EventDetailScreen(events: events, eventId: e.id)),
                        );
                        _save();
                      },
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class EventDetailScreen extends StatefulWidget {
  final List<EventData> events;
  final String eventId;
  const EventDetailScreen({Key? key, required this.events, required this.eventId}) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late EventData event;

  final _memberController = TextEditingController();
  final _expenseTitleController = TextEditingController();
  final _expenseAmountController = TextEditingController();
  String? _selectedPayerId;
  final Set<String> _selectedParticipants = {};

  @override
  void initState() {
    super.initState();
    event = widget.events.firstWhere((e) => e.id == widget.eventId);
  }

  void _addMember(String name) {
    if (name.trim().isEmpty) return;
    event.members.add(Member(id: _id(), name: name.trim()));
    _memberController.clear();
    _save();
  }

  void _removeMember(String id) {
    event.members.removeWhere((m) => m.id == id);
    // remove member from expenses
    for (final ex in event.expenses) {
      ex.participantIds.remove(id);
      if (ex.payerId == id) ex.payerId = event.members.isNotEmpty ? event.members.first.id : '';
    }
    _save();
  }

  void _addExpense() {
    final title = _expenseTitleController.text.trim();
    final amount = double.tryParse(_expenseAmountController.text) ?? 0.0;
    final payer = _selectedPayerId;
    final participants = _selectedParticipants.toList();

    if (title.isEmpty || amount <= 0 || payer == null || participants.isEmpty) return;

    event.expenses.add(Expense(id: _id(), title: title, payerId: payer, amount: amount, participantIds: participants));
    _expenseTitleController.clear();
    _expenseAmountController.clear();
    _selectedParticipants.clear();
    _selectedPayerId = null;
    _save();
  }

  void _removeExpense(String id) {
    event.expenses.removeWhere((e) => e.id == id);
    _save();
  }

  void _save() {
    Storage.saveEvents(widget.events);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final balances = calculateBalances(widget.events, widget.eventId);
    final settlements = settleBalances(balances);

    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('メンバー', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(children: [
                Expanded(
                  child: TextField(controller: _memberController, decoration: const InputDecoration(labelText: 'メンバー名')),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () => _addMember(_memberController.text), child: const Text('追加'))
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: event.members
                    .map((m) => Chip(
                          label: Text(m.name),
                          onDeleted: () => _removeMember(m.id),
                        ))
                    .toList(),
              ),

              const Divider(height: 24),

              const Text('明細 (Expense)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (event.members.isEmpty)
                const Text('メンバーを追加してください')
              else
                Column(children: [
                  TextField(controller: _expenseTitleController, decoration: const InputDecoration(labelText: '項目名')),
                  Row(children: [
                    Expanded(child: TextField(controller: _expenseAmountController, decoration: const InputDecoration(labelText: '金額'))),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      hint: const Text('支払者'),
                      value: _selectedPayerId,
                      items: event.members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                      onChanged: (v) => setState(() => _selectedPayerId = v),
                    )
                  ]),
                  const SizedBox(height: 8),
                  const Text('参加者'),
                  Wrap(
                    spacing: 8,
                    children: event.members
                        .map((m) => FilterChip(
                              label: Text(m.name),
                              selected: _selectedParticipants.contains(m.id),
                              onSelected: (sel) => setState(() {
                                if (sel)
                                  _selectedParticipants.add(m.id);
                                else
                                  _selectedParticipants.remove(m.id);
                              }),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    ElevatedButton(onPressed: _addExpense, child: const Text('明細追加')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: () {
                          // quick split: select all participants
                          setState(() {
                            _selectedParticipants.clear();
                            for (final m in event.members) _selectedParticipants.add(m.id);
                            _selectedPayerId = event.members.first.id;
                          });
                        },
                        child: const Text('全員で割る'))
                  ])
                ]),

              const SizedBox(height: 12),

              if (event.expenses.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('明細一覧', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Column(
                  children: event.expenses
                      .map((ex) => Card(
                            child: ListTile(
                              title: Text('${ex.title} — ¥${ex.amount.toStringAsFixed(0)}'),
                              subtitle: Text('支払者: ${event.members.firstWhere((m) => m.id == ex.payerId, orElse: () => Member(id: '', name: '不明')).name}  参加: ${ex.participantIds.map((pid) => event.members.firstWhere((m) => m.id == pid, orElse: () => Member(id: '', name: '??')).name).join(', ')}'),
                              trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _removeExpense(ex.id)),
                            ),
                          ))
                      .toList(),
                )
              ],

              const Divider(height: 24),

              const Text('計算結果', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (event.members.isEmpty)
                const Text('メンバーがいません')
              else
                Column(
                  children: event.members.map((m) {
                    final bal = balances[m.id] ?? 0.0;
                    return ListTile(
                      title: Text(m.name),
                      trailing: Text((bal >= 0 ? '受取 ' : '支払 ') + '¥${bal.abs().toStringAsFixed(2)}'),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 12),
              const Text('精算提案', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (settlements.isEmpty)
                const Text('未精算またはお互いに相殺されています')
              else
                Column(
                  children: settlements.map((s) {
                    final fromName = event.members.firstWhere((m) => m.id == s['from'], orElse: () => Member(id: '', name: '不明')).name;
                    final toName = event.members.firstWhere((m) => m.id == s['to'], orElse: () => Member(id: '', name: '不明')).name;
                    return ListTile(
                      leading: const Icon(Icons.sync_alt),
                      title: Text('$fromName → $toName'),
                      trailing: Text('¥${(s['amount'] as double).toStringAsFixed(2)}'),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),
              Row(children: [
                ElevatedButton(
                    onPressed: () {
                      // エクスポート: JSON を新しいタブで表示（ユーザーがコピペできる）
                      final jsonStr = json.encode(event.toJson());
                      final blob = html.Blob([jsonStr], 'application/json');
                      final url = html.Url.createObjectUrlFromBlob(blob);
                      html.window.open(url, '_blank');
                      html.Url.revokeObjectUrl(url);
                    },
                    child: const Text('イベントをJSONで表示')),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: () {
                      // 全データ保存
                      Storage.saveEvents(widget.events);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存しました')));
                    },
                    child: const Text('保存'))
              ])
            ],
          ),
        ),
      ),
    );
  }
}
