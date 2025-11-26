import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wari_can/pages/name_input_screen.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
import '../pages/event_list_page.dart';
import '../auth/google_auth_web.dart';

/// ログイン方法選択ページ。
///
/// 匿名ログイン・Googleログイン・ローカルモード（未実装）を選択可能。
class LoginChoicePage extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  /// コンストラクタ。
  const LoginChoicePage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  /// 匿名ログイン → 名前未設定なら入力画面、設定済みならイベント一覧へ遷移
  Future<void> _handleAnonymousLogin(BuildContext context) async {
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      final user = cred.user;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final name = doc.data()?['name'];

      if (name == null || (name is String && name.trim().isEmpty)) {
        // 初回匿名ログイン → 名前入力画面へ
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const NameInputScreen()),
        );

        // 名前入力画面から戻ってきたらイベント一覧へ
        if (result != null && result.isNotEmpty) {
          _navigateToEventList(context);
        }
      } else {
        // 名前設定済み → イベント一覧へ
        _navigateToEventList(context);
      }
    } catch (e) {
      _showError(context, '匿名ログイン失敗: $e');
    }
  }

  /// Googleログイン → Firestoreにユーザー情報保存 → イベント一覧ページへ遷移
  Future<void> _handleGoogleLogin(BuildContext context) async {
    final result = await signInWithGoogleWeb();
    if (result == null) {
      _showError(context, 'Googleログイン失敗');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists || doc.data()?['name'] == null) {
        await docRef.set({
          'name': user.displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isAnonymous': user.isAnonymous,
        }, SetOptions(merge: true));
      }
    }

    _navigateToEventList(context);
  }

  /// ローカルモード（未実装） → 作成中メッセージ表示
  void _handleLocalMode(BuildContext context) {
    showAppSnackBar(
      context,
      message: '🚧 この機能は現在作成中です',
      type: SnackBarType.error,
    );
  }

  /// イベント一覧ページへ遷移
  void _navigateToEventList(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EventListPage(onToggleTheme: onToggleTheme, isDark: isDark),
      ),
    );
  }

  /// エラーメッセージ表示
  void _showError(BuildContext context, String message) {
    showAppSnackBar(context, message: message, type: SnackBarType.error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン方法を選択'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: onToggleTheme,
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
              onPressed: () => _handleAnonymousLogin(context),
            ),
            const SizedBox(height: 16),
            _buildLoginButton(
              icon: Icons.login,
              label: 'Googleでログイン',
              onPressed: () => _handleGoogleLogin(context),
            ),
            const SizedBox(height: 16),
            _buildLoginButton(
              icon: Icons.wifi_off,
              label: 'ローカルモードで使う',
              onPressed: () => _handleLocalMode(context),
            ),
          ],
        ),
      ),
    );
  }

  /// ログインボタン共通ビルダー
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
