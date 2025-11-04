import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/event_detail_page.dart';
import 'dart:convert';

void main() {
  runApp(const WariCanApp());
}

class WariCanApp extends StatefulWidget {
  const WariCanApp({super.key});

  @override
  State<WariCanApp> createState() => _WariCanAppState();
}

class _WariCanAppState extends State<WariCanApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = _themeMode == ThemeMode.dark;
    await prefs.setBool('isDark', !isDark);
    setState(() => _themeMode = !isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '割り勘アプリ',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light, colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: Colors.teal),
      themeMode: _themeMode,
      home: EventListPage(onToggleTheme: _toggleTheme),
    );
  }
}

class EventListPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const EventListPage({super.key, required this.onToggleTheme});

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  List<Map<String, dynamic>> events = [];
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('events') ?? [];
    setState(() {
      events = list.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
    });
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('events', events.map((e) => jsonEncode(e)).toList());
  }

  void _addEvent() {
    if (controller.text.isEmpty) return;
    final newEvent = {'name': controller.text, 'start': null, 'end': null};
    setState(() {
      events.add(newEvent);
      controller.clear();
    });
    _saveEvents();
  }

  void _deleteEvent(int index) {
    setState(() => events.removeAt(index));
    _saveEvents();
  }

  void _editEventName(int index) async {
    final editController = TextEditingController(text: events[index]['name']);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('イベント名を編集'),
        content: TextField(controller: editController, decoration: const InputDecoration(labelText: 'イベント名')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, editController.text), child: const Text('保存')),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      setState(() => events[index]['name'] = result.trim());
      _saveEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('イベント一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.onToggleTheme,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'イベント名を入力'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addEvent,
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: events.length,
                itemBuilder: (context, i) {
                  final e = events[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(e['name']),
                      subtitle: Text(
                        '開始: ${e['start'] ?? '-'}  終了: ${e['end'] ?? '-'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _editEventName(i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteEvent(i),
                          ),
                        ],
                      ),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EventDetailPage(eventData: e)),
                        );
                        if (result != null) {
                          setState(() {
                            events[i]['start'] = result['start'];
                            events[i]['end'] = result['end'];
                          });
                          _saveEvents();
                        }
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
