import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wari_can/pages/event_list_page.dart';
import 'package:wari_can/utils/snackbar_utils.dart';

/// 匿名ログインユーザーに表示名を入力させる画面。
class NameInputScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const NameInputScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<NameInputScreen> createState() => _NameInputScreenState();
}

/// 表示名入力画面のステート。
class _NameInputScreenState extends State<NameInputScreen> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _saveName() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(
        context,
        message: '名前を入力してください',
        type: SnackBarType.error,
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Firestoreへの保存を待機
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isAnonymous': user.isAnonymous,
      }, SetOptions(merge: true));

      // 2. 保存中にユーザーが画面を閉じていないかチェック
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EventListPage(
            onToggleTheme: widget.onToggleTheme,
            isDark: widget.isDark,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, message: '保存に失敗しました', type: SnackBarType.error);
    }
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
