import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wari_can/pages/name_input_screen.dart';
import 'package:wari_can/utils/exception_utils.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
import '../pages/event_list_page.dart';
import '../auth/google_auth_web.dart';

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
  /// 匿名ログイン
  Future<void> _handleAnonymousLogin() async {
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      // awaitの後は常にmountedをチェック
      if (!mounted) return;

      final user = cred.user;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;

      final name = doc.data()?['name'];

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

  /// Googleログイン
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

      if (!doc.exists || doc.data()?['name'] == null) {
        await docRef.set({
          'name': user.displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isAnonymous': user.isAnonymous,
        }, SetOptions(merge: true));
        if (!mounted) return;
      }
    }

    _navigateToEventList();
  }

  /// ローカルモード
  void _handleLocalMode() {
    showAppSnackBar(
      context,
      message: '🚧 この機能は現在作成中です',
      type: SnackBarType.error,
    );
  }

  /// イベント一覧ページへ遷移
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

  /// エラーメッセージ表示
  void _showError(String message) {
    showAppSnackBar(context, message: message, type: SnackBarType.error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン方法を選択'),
        actions: [
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
