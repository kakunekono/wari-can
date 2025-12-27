import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wari_can/pages/event_list_page.dart';
import 'package:wari_can/utils/snackbar_utils.dart';

/// 匿名ログインユーザーに対して、アプリ内で使用する「表示名」を登録させる画面。
///
/// 認証自体は完了しているが、Firestore側にユーザー情報（名前）が不足している
/// 場合のブリッジUIとして機能します。
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
  /// ユーザー名の入力制御用コントローラ。
  final TextEditingController _controller = TextEditingController();

  /// 入力された名前を Firestore に保存し、メイン画面へ遷移します。
  Future<void> _saveName() async {
    final name = _controller.text.trim();

    // 未入力バリデーション
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
      // 1. Firestoreの 'users' コレクションにプロファイルを保存。
      // SetOptions(merge: true) を指定し、既存のデータ（あれば）を壊さずに更新。
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isAnonymous': user.isAnonymous,
      }, SetOptions(merge: true));

      // 2. 非同期処理（ネットワーク通信）の待機中に、ウィジェットが破棄されていないか確認。
      if (!mounted) return;

      // 保存成功後、イベント一覧へ遷移。
      // pushReplacement を用いることで、戻るボタンでこの画面に戻れないようにします。
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
      // 通信エラーなどの例外ハンドリング。
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'プロファイルの保存に失敗しました',
        type: SnackBarType.error,
      );
    }
  }

  @override
  void dispose() {
    // TextEditingController は必ず破棄してメモリリークを防止。
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィールの設定'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0), // 余白を少し広めに調整
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              '匿名ログインを完了しました。\nアプリ内で表示されるあなたの名前を入力してください。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              autofocus: true, // 画面表示時にすぐ入力できるようフォーカスを当てる
              maxLength: 20, // 名前の長さを制限（任意）
              decoration: const InputDecoration(
                labelText: '表示名',
                hintText: '例：たろう',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              onSubmitted: (_) => _saveName(), // キーボードの確定キーでも保存を実行
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveName,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                '保存してはじめる',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
