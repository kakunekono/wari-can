import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'pages/firebase_init_check_page.dart';
import 'pages/event_list_page.dart';

/// アプリのエントリーポイント。
Future<void> main() async {
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
      home: kDebugMode
          ? FirebaseInitCheckPage(onToggleTheme: _toggleTheme, isDark: _isDark)
          : EventListPage(onToggleTheme: _toggleTheme, isDark: _isDark),
    );
  }
}
