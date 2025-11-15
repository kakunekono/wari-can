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
