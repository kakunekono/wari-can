// lib/main.dart
// WariCan - Flutter Web 割り勘アプリ (ステップ2: UI整備 + レスポンシブ対応)
// Material 3 + ResponsiveLayoutBuilder を採用

import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';

void main() => runApp(const WariCanApp());

class WariCanApp extends StatelessWidget {
  const WariCanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WariCan 割り勘アプリ',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      home: const EventListScreen(),
    );
  }
}

// ---------------- Models ----------------
class Member {
  final String id;
  String name;
  Member({required this.id, required this.name});
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Member.fromJson(Map<String, dynamic> j) => Member(id: j['id'], name: j['name']);
}

class Expense {
  final String id;
  String title;
  String payerId;
  double amount;
  List<String> participantIds;
  Expense({required this.id, required this.title, required this.payerId, required this.amount, required this.participantIds});
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
  final String id;
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

// ---------------- Storage ----------------
class Storage {
  static const _key = 'warican_events_v2';
  static List<EventData> load() {
    try {
      final str = html.window.localStorage[_key];
      if (str == null) return [];
      final data = json.decode(str) as List;
      return data.map((e) => EventData.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static void save(List<EventData> events) {
    final str = json.encode(events.map((e) => e.toJson()).toList());
    html.window.localStorage[_key] = str;
  }
}

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

Map<String, double> calcBalances(EventData event) {
  final balances = {for (var m in event.members) m.id: 0.0};
  for (var ex in event.expenses) {
    if (ex.participantIds.isEmpty) continue;
    final share = ex.amount / ex.participantIds.length;
    for (var pid in ex.participantIds) {
      balances[pid] = (balances[pid] ?? 0) - share;
    }
    balances[ex.payerId] = (balances[ex.payerId] ?? 0) + ex.amount;
  }
  return balances;
}

List<Map<String, dynamic>> settle(Map<String, double> balances) {
  final res = <Map<String, dynamic>>[];
  final debtors = balances.entries.where((e) => e.value < 0).toList()..sort((a, b) => a.value.compareTo(b.value));
  final creditors = balances.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
  int i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    final d = debtors[i];
    final c = creditors[j];
    final amt = (d.value.abs() < c.value) ? d.value.abs() : c.value;
    res.add({'from': d.key, 'to': c.key, 'amount': amt});
    debtors[i] = MapEntry(d.key, d.value + amt);
    creditors[j] = MapEntry(c.key, c.value - amt);
    if (debtors[i].value.abs() < 0.01) i++;
    if (creditors[j].value.abs() < 0.01) j++;
  }
  return res;
}

// ---------------- Screens ----------------
class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});
  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  List<EventData> events = [];
  final titleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    events = Storage.load();
    if (events.isEmpty) events.add(EventData(id: _id(), title: 'サンプルイベント'));
  }

  void save() => Storage.save(events);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('イベント一覧')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('新しいイベント'),
              content: TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'タイトル')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
                ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    setState(() => events.add(EventData(id: _id(), title: titleCtrl.text.trim())));
                    save();
                    Navigator.pop(context);
                  },
                  child: const Text('追加'),
                ),
              ],
            ),
          );
        },
        label: const Text('追加'),
        icon: const Icon(Icons.add),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          return GridView.count(
            crossAxisCount: isWide ? 3 : 1,
            childAspectRatio: isWide ? 1.8 : 3,
            padding: const EdgeInsets.all(16),
            children: events
                .map((e) => Card(
                      elevation: 2,
                      clipBehavior: Clip.hardEdge,
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: e)));
                          setState(() {});
                          save();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(e.title, style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Text('${e.members.length}人 / 明細 ${e.expenses.length}件'),
                            ],
                          ),
                        ),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class EventDetailScreen extends StatefulWidget {
  final EventData event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final memberCtrl = TextEditingController();
  final expTitleCtrl = TextEditingController();
  final expAmtCtrl = TextEditingController();
  String? payerId;
  Set<String> selected = {};

  void save() => Storage.save([widget.event]);

  @override
  Widget build(BuildContext context) {
    final balances = calcBalances(widget.event);
    final settlements = settle(balances);

    return Scaffold(
      appBar: AppBar(title: Text(widget.event.title)),
      body: LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth > 800;
          final content = SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('メンバー', style: Theme.of(context).textTheme.titleMedium),
              Row(children: [
                Expanded(child: TextField(controller: memberCtrl, decoration: const InputDecoration(labelText: 'メンバー名'))),
                const SizedBox(width: 8),
                FilledButton(onPressed: () {
                  if (memberCtrl.text.isEmpty) return;
                  widget.event.members.add(Member(id: _id(), name: memberCtrl.text));
                  memberCtrl.clear();
                  setState(() {});
                  save();
                }, child: const Text('追加'))
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: widget.event.members
                    .map((m) => InputChip(
                          label: Text(m.name),
                          onDeleted: () {
                            widget.event.members.remove(m);
                            setState(() {});
                            save();
                          },
                        ))
                    .toList(),
              ),
              const Divider(height: 24),
              Text('明細', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(controller: expTitleCtrl, decoration: const InputDecoration(labelText: '項目名')),
              Row(children: [
                Expanded(child: TextField(controller: expAmtCtrl, decoration: const InputDecoration(labelText: '金額'))),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  hint: const Text('支払者'),
                  value: payerId,
                  items: widget.event.members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                  onChanged: (v) => setState(() => payerId = v),
                )
              ]),
              const SizedBox(height: 8),
              const Text('参加者:'),
              Wrap(
                spacing: 8,
                children: widget.event.members
                    .map((m) => FilterChip(
                          label: Text(m.name),
                          selected: selected.contains(m.id),
                          onSelected: (v) => setState(() => v ? selected.add(m.id) : selected.remove(m.id)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              Row(children: [
                FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('追加'),
                    onPressed: () {
                      if (expTitleCtrl.text.isEmpty || payerId == null || selected.isEmpty) return;
                      final amt = double.tryParse(expAmtCtrl.text) ?? 0;
                      widget.event.expenses.add(Expense(id: _id(), title: expTitleCtrl.text, payerId: payerId!, amount: amt, participantIds: selected.toList()));
                      expTitleCtrl.clear();
                      expAmtCtrl.clear();
                      payerId = null;
                      selected.clear();
                      setState(() {});
                      save();
                    })
              ]),
              const Divider(height: 24),
              Text('計算結果', style: Theme.of(context).textTheme.titleMedium),
              ...widget.event.members.map((m) {
                final v = balances[m.id] ?? 0;
                return ListTile(
                  title: Text(m.name),
                  trailing: Text(v >= 0 ? '受取 ¥${v.toStringAsFixed(2)}' : '支払 ¥${v.abs().toStringAsFixed(2)}'),
                );
              }),
              const Divider(height: 24),
              Text('精算提案', style: Theme.of(context).textTheme.titleMedium),
              ...settlements.map((s) {
                final from = widget.event.members.firstWhere((m) => m.id == s['from']).name;
                final to = widget.event.members.firstWhere((m) => m.id == s['to']).name;
                return ListTile(title: Text('$from → $to'), trailing: Text('¥${(s['amount'] as double).toStringAsFixed(2)}'));
              })
            ]),
          );
          if (isWide) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: content,
              ),
            );
          }
          return content;
        },
      ),
    );
  }
}
