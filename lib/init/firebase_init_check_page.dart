import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import '../pages/event_list_page.dart';

/// Firebase の初期化状態を確認するページ。
/// 成功すれば `EventListPage` に遷移する。
class FirebaseInitCheckPage extends StatefulWidget {
  /// テーマ切り替えコールバック。
  final VoidCallback onToggleTheme;

  /// 現在のテーマがダークかどうか。
  final bool isDark;

  /// コンストラクタ。
  const FirebaseInitCheckPage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<FirebaseInitCheckPage> createState() => _FirebaseInitCheckPageState();
}

/// Firebase 初期化チェックページのステート。
class _FirebaseInitCheckPageState extends State<FirebaseInitCheckPage> {
  /// ステータスメッセージ。
  String _status = "Firebase初期化中...";

  @override
  void initState() {
    super.initState();
    _initFirebase();
  }

  /// Firebase を初期化し、成功すればイベント一覧ページへ遷移。
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
