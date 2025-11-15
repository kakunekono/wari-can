import 'dart:convert';

import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wari_can/models/event.dart';
import 'package:wari_can/pages/event_detail_page.dart';
import 'package:wari_can/utils/event_json_utils.dart';
import 'package:wari_can/utils/firestore_helper.dart';
import 'package:wari_can/utils/utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔹 匿名認証を実行
  try {
    await FirebaseAuth.instance.signInAnonymously();
    debugPrint("匿名ログイン成功: ${FirebaseAuth.instance.currentUser?.uid}");
  } catch (e) {
    debugPrint("匿名ログイン失敗: $e");
  }

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
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        textTheme: GoogleFonts.notoSansJpTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.notoSansJpTextTheme(
          ThemeData.dark().textTheme, // ← ここが重要
        ),
      ),

      home: kDebugMode
          ? FirebaseInitCheckPage(onToggleTheme: _toggleTheme, isDark: _isDark)
          : EventListPage(onToggleTheme: _toggleTheme, isDark: _isDark),
    );
  }
}

// ----------------------
// Firebase初期化チェックページ
// ----------------------
class FirebaseInitCheckPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const FirebaseInitCheckPage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<FirebaseInitCheckPage> createState() => _FirebaseInitCheckPageState();
}

class _FirebaseInitCheckPageState extends State<FirebaseInitCheckPage> {
  String _status = "Firebase初期化中...";

  @override
  void initState() {
    super.initState();
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      setState(() {
        _status = "✅ Firebase接続成功";
      });

      // 成功したら EventListPage に遷移
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EventListPage(
              onToggleTheme: widget.onToggleTheme,
              isDark: widget.isDark,
            ),
          ),
        );
      });
    } catch (e) {
      setState(() {
        _status = "❌ Firebase接続失敗: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("接続確認")),
      body: Center(child: Text(_status, style: const TextStyle(fontSize: 20))),
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

    // 🔹 匿名ログインの結果を画面に通知
    final user = FirebaseAuth.instance.currentUser;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("匿名ログイン成功 ✅ UID: ${user.uid}"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("匿名ログイン失敗 ❌"),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
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

  Future<void> _copyEvent(Event e) async {
    final controller = TextEditingController(text: "");

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("イベントをコピーして追加"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "新しいイベント名"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("イベント名を入力してください"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, name);
            },
            child: const Text("作成"),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    final now = DateTime.now();

    final newEvent = e.copyWith(
      id: Uuid().v4(),
      name: result,
      members: e.members
          .map((m) => m.copyWith(id: Uuid().v4(), createAt: now, updateAt: now))
          .toList(),
      details: [], // Expenseも複製したい場合はここで map する
      createAt: now,
      updateAt: now,
    );

    setState(() => _events.add(newEvent));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("「${e.name}」のメンバーをコピーして新規イベントを作成しました"),
        backgroundColor: Colors.green,
      ),
    );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailPage(event: newEvent)),
    );

    setState(() {});
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
    await deleteEventFromFirestore(event.id); // Firestore削除
    setState(() => _events.removeAt(index));
  }

  Future<void> _addEvent() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("イベント名を入力してください"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final timestamps = TimestampedEntity.newTimestamps();

    final newEvent = Event(
      id: _uuid.v4(),
      name: name,
      createAt: timestamps['createAt']!,
      updateAt: timestamps['updateAt']!,
    );

    await _saveEvent(newEvent);
    _controller.clear();
    _loadEvents();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailPage(event: newEvent)),
    );

    // 戻ってきたらリストを更新（必要なら _loadEvents() 再呼び出し）
    setState(() {});
  }

  void _openEventDetail(Event event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailPage(event: event)),
    );

    // 🔹 Firestoreから最新イベントを取得
    final snapshot = await FirebaseFirestore.instance
        .collection("events")
        .doc(event.id)
        .get();

    if (snapshot.exists) {
      final data = snapshot.data();
      if (data != null) {
        final updatedEvent = Event.fromJson(data);
        final index = _events.indexWhere((e) => e.id == updatedEvent.id);
        if (index != -1) {
          setState(() => _events[index] = updatedEvent);
        }
      }
    }
  }

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

    if (newName != null && newName.trim().isNotEmpty && newName != event.name) {
      final updated = event.copyWith(
        name: newName.trim(),
        updateAt: DateTime.now(),
      );
      try {
        await _saveEvent(updated);
        await saveEventToFirestore(updated);
        _loadEvents();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("イベント名を「${newName}」に変更しました"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("保存に失敗しました: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ----------------------
  // 共通のイベント操作ボタン
  // ----------------------
  List<Widget> buildEventActionButtons(
    BuildContext context,
    Event e,
    int index,
  ) {
    return [
      IconButton(
        icon: const Icon(Icons.content_copy),
        tooltip: 'メンバーをコピーして追加',
        iconSize: 20,
        onPressed: () => _copyEvent(e),
      ),
      IconButton(
        icon: const Icon(Icons.cloud_upload, color: Colors.green),
        tooltip: 'クラウドへアップロード',
        onPressed: () => uploadEventToCloud(context, e.toJson()),
        iconSize: 20,
      ),
      IconButton(
        icon: const Icon(Icons.code),
        tooltip: 'JSON出力',
        onPressed: () => EventJsonUtils.exportEventJson(context, e),
        iconSize: 20,
      ),
      IconButton(
        icon: const Icon(Icons.edit, color: Colors.blue),
        tooltip: '編集',
        onPressed: () => _editEventName(e),
        iconSize: 20,
      ),
      IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        tooltip: '削除',
        onPressed: () => _deleteEvent(index),
        iconSize: 20,
      ),
    ];
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
          // 🔹 一括アップロードボタンを追加
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'クラウドへ一括アップロード',
            onPressed: () async {
              await uploadLocalEventsToFirestore(context);
            },
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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 600;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  title: Text(
                                    e.name,
                                    style: const TextStyle(
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      'イベントID： ${e.id}',
                                      'メンバー: ${e.members.map((m) => Utils.memberName(m.id, e.members)).join(",")}',
                                      '明細件数： ${e.details.length}件',
                                      '合計金額： ${Utils.formatAmount(e.details.fold(0, (sum, e) => sum + e.amount))}円',
                                    ].join("\n"),
                                  ),
                                  onTap: () => _openEventDetail(e),

                                  // 幅が広いときは trailing に右寄せで表示
                                  trailing: isWide
                                      ? Wrap(
                                          spacing: 8,
                                          children: buildEventActionButtons(
                                            context,
                                            e,
                                            i,
                                          ),
                                        )
                                      : null,
                                ),

                                // 幅が狭いときは下部に横並びで表示
                                if (!isWide)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: buildEventActionButtons(
                                        context,
                                        e,
                                        i,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
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