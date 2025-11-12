import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wari_can/models/event.dart';
import 'package:wari_can/pages/event_detail_page.dart';
import '../utils/event_json_utils.dart';

void main() {
  runApp(const WariCanApp());
}

// ----------------------
// アプリ全体
// ----------------------
class WariCanApp extends StatefulWidget {
  const WariCanApp({super.key});

  @override
  State<WariCanApp> createState() => _WariCanAppState();
}

class _WariCanAppState extends State<WariCanApp> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    setState(() => _isDark = isDark);
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final newMode = !_isDark;
    await prefs.setBool('isDark', newMode);
    setState(() => _isDark = newMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '割り勘アプリ',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: EventListPage(onToggleTheme: _toggleTheme, isDark: _isDark),
    );
  }
}

// ----------------------
// イベント一覧ページ
// ----------------------
class EventListPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const EventListPage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  final _uuid = const Uuid();
  final _controller = TextEditingController();
  List<Event> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('event_')).toList();
    final events = <Event>[];

    for (final key in keys) {
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        final decoded = jsonDecode(jsonString);
        events.add(Event.fromJson(decoded));
      }
    }

    events.sort((a, b) => a.name.compareTo(b.name));
    setState(() => _events = events);
  }

  Future<void> _saveEvent(Event event) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('event_${event.id}', jsonEncode(event.toJson()));
  }

  Future<void> _deleteEvent(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('本当にこのイベントを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('はい'),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // 「はい」以外は処理中止

    final prefs = await SharedPreferences.getInstance();
    final event = _events[index];
    await prefs.remove('event_${event.id}');
    setState(() => _events.removeAt(index));
  }

  void _addEvent() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    final newEvent = Event(id: _uuid.v4(), name: name);
    await _saveEvent(newEvent);
    _controller.clear();
    _loadEvents();
  }

  void _openEventDetail(Event event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailPage(event: event)),
    );
    _loadEvents();
  }

  // 🔹 イベント名の編集処理
  Future<void> _editEventName(Event event) async {
    final controller = TextEditingController(text: event.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('イベント名を編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新しいイベント名',
            border: OutlineInputBorder(),
          ),
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

    if (newName != null && newName.isNotEmpty && newName != event.name) {
      final updated = Event(
        id: event.id,
        name: newName,
        startDate: event.startDate,
        endDate: event.endDate,
        members: event.members,
        details: event.details,
      );
      await _saveEvent(updated);
      _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('イベント一覧'),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDark ? Icons.light_mode : Icons.dark_mode_outlined,
            ),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'JSON取込',
            onPressed: () async {
              final newEvent = await EventJsonUtils.importEventJson(context);
              if (newEvent != null) {
                await _loadEvents(); // 一覧更新
                // 新しいイベントの明細ページへ遷移
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailPage(event: newEvent),
                  ),
                );
                _loadEvents(); // 明細で変更があった場合に再読み込み
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'すべて削除',
            onPressed: _confirmDeleteAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'イベント名を入力',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _addEvent, child: const Text('追加')),
              ],
            ),
          ),
          Expanded(
            child: _events.isEmpty
                ? const Center(child: Text('登録されたイベントはありません'))
                : ListView.builder(
                    itemCount: _events.length,
                    itemBuilder: (context, i) {
                      final e = _events[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(e.name),
                          subtitle: Text(
                            [
                              'イベントID： ${e.id}',
                              'メンバー: ${e.members.length}人',
                            ].join("\n"),
                          ),
                          onTap: () => _openEventDetail(e),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              // 既存 ListTile の trailing Wrap 内に追加
                              IconButton(
                                icon: const Icon(Icons.code),
                                tooltip: 'JSON出力',
                                onPressed: () =>
                                    EventJsonUtils.exportEventJson(context, e),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                tooltip: '編集',
                                onPressed: () => _editEventName(e),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: '削除',
                                onPressed: () => _deleteEvent(i),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('本当にすべてのイベントとデータを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('はい'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      setState(() => _events.clear());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('すべてのデータを削除しました')));
    }
  }
}
