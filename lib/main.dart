import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wari_can/models/event.dart';
import 'package:wari_can/pages/event_list_page.dart';

import 'firebase_options.dart';

import 'pages/login_choice_page.dart'; // ← 新規作成したログイン選択ページ

/// ローカルに保存されたイベントに ownerUid / sharedWith を補完して再保存する。
Future<void> migrateLocalEventsIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys().where((k) => k.startsWith('event_')).toList();

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return; // ログインしていない場合はスキップ

  for (final key in keys) {
    final jsonString = prefs.getString(key);
    if (jsonString == null) continue;

    try {
      final decoded = jsonDecode(jsonString);
      final event = Event.fromJson(decoded);

      // すでに ownerUid があるならスキップ
      if (event.ownerUid.isNotEmpty && event.sharedWith.isNotEmpty) continue;

      final updated = event.copyWith(
        ownerUid: event.ownerUid.isNotEmpty ? event.ownerUid : uid,
        sharedWith: event.sharedWith.isNotEmpty ? event.sharedWith : [uid],
      );

      await prefs.setString(key, jsonEncode(updated.toJson()));
    } catch (e) {
      // 破損データなどはスキップ
      debugPrint('イベント修復失敗 [$key]: $e');
    }
  }

  debugPrint('ローカルイベントのマイグレーション完了');
}

/// アプリのエントリーポイント。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await migrateLocalEventsIfNeeded();

  runApp(const WariCanApp());
}

/// アプリ全体のルートウィジェット。
class WariCanApp extends StatefulWidget {
  const WariCanApp({super.key});

  @override
  State<WariCanApp> createState() => _WariCanAppState();
}

/// アプリのテーマ管理とルーティングを担当するステート。
class _WariCanAppState extends State<WariCanApp> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  /// SharedPreferences からテーマ設定を読み込む。
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    setState(() => _isDark = isDark);
  }

  /// テーマを切り替えて保存する。
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
        textTheme: ThemeData.light().textTheme,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        textTheme: ThemeData.dark().textTheme,
      ),
      home: AuthGate(onToggleTheme: _toggleTheme, isDark: _isDark),
    );
  }
}

/// 認証状態に応じて適切な画面に遷移するウィジェット。
class AuthGate extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const AuthGate({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

/// 認証状態に応じて適切な画面に遷移するウィジェット。
class _AuthGateState extends State<AuthGate> {
  bool _inviteHandled = false;
  Uri? _initialUri;

  @override
  void initState() {
    super.initState();
    _loadInitialUri();
  }

  Future<void> _loadInitialUri() async {
    if (kIsWeb) {
      final uri = Uri.base;
      final eventId = uri.queryParameters['eventId'];
      if (eventId != null) {
        setState(() {
          _initialUri = uri;
        });
      }
    }
  }

  /// 招待リンクからのアクセスであれば、イベントにユーザーを追加する。
  Future<void> _handleInviteIfNeeded(User user) async {
    if (_inviteHandled || _initialUri == null) return;

    final eventId = _initialUri!.queryParameters['eventId'];
    if (eventId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .update({
              'sharedWith': FieldValue.arrayUnion([user.uid]),
            });
        debugPrint('イベント $eventId に共有追加: ${user.uid}');
      } catch (e) {
        debugPrint('共有追加失敗: $e');
      }
    }

    setState(() {
      _inviteHandled = true;
    });
  }

  /// 匿名ユーザーの場合、表示名が設定されていなければ入力画面を表示する。
  Future<void> _handleAnonymousNameIfNeeded(User user) async {
    if (!user.isAnonymous) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final name = doc.data()?['name'];

    if (name == null || (name is String && name.trim().isEmpty)) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NameInputScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleInviteIfNeeded(user);
            _handleAnonymousNameIfNeeded(user); // ← 追加
          });
          return EventListPage(
            onToggleTheme: widget.onToggleTheme,
            isDark: widget.isDark,
          );
        } else {
          return LoginChoicePage(
            onToggleTheme: widget.onToggleTheme,
            isDark: widget.isDark,
          );
        }
      },
    );
  }
}

/// 表示名入力画面のウィジェット。
class NameInputScreen extends StatefulWidget {
  const NameInputScreen({super.key});

  @override
  State<NameInputScreen> createState() => _NameInputScreenState();
}

/// 匿名ログインユーザーに表示名を入力させる画面。
class _NameInputScreenState extends State<NameInputScreen> {
  final _controller = TextEditingController();

  Future<void> _saveName() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    Navigator.pop(context); // 元の画面に戻る
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('名前を入力')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('匿名ログイン中です。表示名を入力してください。'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '表示名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _saveName, child: const Text('保存')),
          ],
        ),
      ),
    );
  }
}
