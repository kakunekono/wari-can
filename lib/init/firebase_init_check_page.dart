import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wari_can/utils/exception_utils.dart';
import '../../firebase_options.dart';
import '../pages/event_list_page.dart';

/// Firebase の初期化状態を視覚的に確認し、接続を確立するページ。
///
/// アプリの起動直後に実行され、Firebase サービスが利用可能であることを
/// 確認してからメイン機能（EventListPage）へと橋渡しします。
class FirebaseInitCheckPage extends StatefulWidget {
  /// テーマ切り替えコールバック。
  final VoidCallback onToggleTheme;

  /// 現在のテーマがダークかどうか。
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
  /// ユーザーに表示する現在のステータスメッセージ。
  String _status = "Firebase初期化中...";

  @override
  void initState() {
    super.initState();
    // 画面が描画された直後に初期化処理を開始
    _initFirebase();
  }

  /// Firebase を初期化し、成功・失敗に応じたフローを制御します。
  Future<void> _initFirebase() async {
    try {
      // 1. Firebase プロジェクトの設定に基づき初期化を実行
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. 状態更新（マウントチェックを入れて安全性を確保）
      if (!mounted) return;
      setState(() {
        _status = "✅ Firebase接続成功";
      });

      // 3. ユーザーが成功を確認できるよう、短いディレイを挟んでから遷移
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EventListPage(
              onToggleTheme: widget.onToggleTheme,
              isDark: widget.isDark,
            ),
          ),
        );
      });
    } on Exception catch (e) {
      // エラー発生時は ExceptionUtils を用いて簡潔なメッセージを表示
      if (!mounted) return;
      setState(() {
        _status = "❌ Firebase接続失敗: ${ExceptionUtils.format(e)}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("システム接続確認"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 状態に応じたインジケーターの表示
            if (_status.contains("初期化中"))
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: CircularProgressIndicator(),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
