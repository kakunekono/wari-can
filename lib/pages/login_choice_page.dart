import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/event_list_page.dart';
import '../auth/google_auth_web.dart'; // Googleログイン関数を定義したファイル

/// ログイン方法選択ページ
class LoginChoicePage extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  /// コンストラクタ
  const LoginChoicePage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  /// 匿名ログイン処理
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

  /// Googleログイン処理
  Future<void> _signInWithGoogle(BuildContext context) async {
    final result = await signInWithGoogleWeb(); // Googleログイン処理（外部定義）

    if (result != null) {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final doc = await docRef.get();

        // Firestore に displayName を保存
        if (!doc.exists || doc.data()?['name'] == null) {
          await docRef.set({
            'name': user.displayName,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

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
            SizedBox(
              width: 250,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_outline),
                label: const Text('匿名でログイン'),
                onPressed: () => _signInAnonymously(context),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 250,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Googleでログイン'),
                onPressed: () => _signInWithGoogle(context),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 250,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.wifi_off),
                label: const Text('ローカルモードで使う'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("🚧 この機能は現在作成中です"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
