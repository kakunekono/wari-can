import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wari_can/pages/name_input_screen.dart';
import 'package:wari_can/utils/exception_utils.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
import '../pages/event_list_page.dart';
import '../auth/google_auth_web.dart';

/// ログイン方法の選択画面。
///
/// ユーザーに対して「匿名」「Google」「ローカル」の3つの利用形態を提示します。
/// 各認証後の [FirebaseFirestore] へのユーザープロファイル作成と、
/// 初回ログイン時の名前入力画面への遷移を管理します。
class LoginChoicePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const LoginChoicePage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<LoginChoicePage> createState() => _LoginChoicePageState();
}

class _LoginChoicePageState extends State<LoginChoicePage> {
  /// 匿名ログインの実行
  ///
  /// 手軽にアプリを使い始めたいユーザー向け。
  /// ログイン後、Firestoreに名前が登録されていない場合は [NameInputScreen] へ誘導します。
  Future<void> _handleAnonymousLogin() async {
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      // 非同期処理の後は常に mounted チェックを行い、Context 操作の安全性を確保
      if (!mounted) return;

      final user = cred.user;
      if (user == null) return;

      // Firestoreからユーザー設定を取得
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;

      final name = doc.data()?['name'];

      // 名前が未設定（または空）の場合は名前入力画面へ、設定済みの場合は一覧へ
      if (name == null || (name is String && name.trim().isEmpty)) {
        await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => NameInputScreen(
              onToggleTheme: widget.onToggleTheme,
              isDark: widget.isDark,
            ),
          ),
        );
      } else {
        _navigateToEventList();
      }
    } on Exception catch (e) {
      if (!mounted) return;
      _showError('匿名ログイン失敗: ${ExceptionUtils.format(e)}');
    }
  }

  /// Googleログインの実行
  ///
  /// ログイン成功後、Firestoreにプロファイルが存在しない場合は、
  /// Googleアカウントの表示名をデフォルト名として自動登録します。
  Future<void> _handleGoogleLogin() async {
    final result = await signInWithGoogleWeb();
    if (!mounted) return;

    if (result == null) {
      _showError('Googleログイン失敗');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final doc = await docRef.get();
      if (!mounted) return;

      // ユーザーデータが存在しない、または名前が未登録の場合のみ初期データをセット
      if (!doc.exists || doc.data()?['name'] == null) {
        await docRef.set({
          'name': user.displayName, // Googleアカウントの名前を初期値にする
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isAnonymous': user.isAnonymous,
        }, SetOptions(merge: true));
        if (!mounted) return;
      }
    }

    _navigateToEventList();
  }

  /// ローカルモード（オフライン利用）のハンドラ
  /// 現在開発中のため、ユーザーにその旨を通知します。
  void _handleLocalMode() {
    showAppSnackBar(
      context,
      message: '🚧 この機能は現在作成中です',
      type: SnackBarType.error,
    );
  }

  /// 認証・プロファイル設定完了後の遷移処理
  /// [pushReplacement] を使い、ログイン画面をスタックから削除して戻れないようにします。
  void _navigateToEventList() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EventListPage(
          onToggleTheme: widget.onToggleTheme,
          isDark: widget.isDark,
        ),
      ),
    );
  }

  /// 共通エラー表示用スナックバー
  void _showError(String message) {
    showAppSnackBar(context, message: message, type: SnackBarType.error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン方法を選択'),
        actions: [
          // ダークモード切り替えボタンをAppBarに配置
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLoginButton(
              icon: Icons.person_outline,
              label: '匿名でログイン',
              onPressed: _handleAnonymousLogin,
            ),
            const SizedBox(height: 16),
            _buildLoginButton(
              icon: Icons.login,
              label: 'Googleでログイン',
              onPressed: _handleGoogleLogin,
            ),
            const SizedBox(height: 16),
            _buildLoginButton(
              icon: Icons.wifi_off,
              label: 'ローカルモードで使う',
              onPressed: () => _handleLocalMode(),
            ),
          ],
        ),
      ),
    );
  }

  /// ログイン画面専用の共通ボタンウィジェット
  Widget _buildLoginButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 250,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }
}
