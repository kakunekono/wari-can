import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/event_list_page.dart';
import '../auth/google_auth_web.dart'; // Googleログイン関数を定義したファイル

class LoginChoicePage extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const LoginChoicePage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  Future<void> _signInAnonymously(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EventListPage(onToggleTheme: onToggleTheme, isDark: isDark),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('匿名ログイン失敗: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    final result = await signInWithGoogleWeb();
    if (result != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EventListPage(onToggleTheme: onToggleTheme, isDark: isDark),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Googleログイン失敗'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            ElevatedButton.icon(
              icon: const Icon(Icons.person_outline),
              label: const Text('匿名でログイン'),
              onPressed: () => _signInAnonymously(context),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Googleでログイン'),
              onPressed: () => _signInWithGoogle(context),
            ),
          ],
        ),
      ),
    );
  }
}
