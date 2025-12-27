import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../pages/event_list_page.dart';
import '../pages/login_choice_page.dart';
import '../pages/name_input_screen.dart';

/// アプリの認証状態を監視し、適切な初期画面を動的に切り替えるウィジェット。
///
/// 以下の3段階のチェックを行います：
/// 1. ログインしているか (Firebase Auth)
/// 2. プロファイル（名前）が登録されているか (Firestore)
/// 3. 匿名ユーザーかつ名前未設定の場合、設定画面へ誘導するか
class AuthGate extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const AuthGate({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    // --- ステップ1: 認証状態の監視 ---
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 接続待ち（初期化中）
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // --- ステップ2: ログイン状況による分岐 ---
        if (user != null) {
          // ログイン済みの場合、Firestoreからユーザー情報を取得してプロファイルを確認
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userDocSnapshot) {
              // データ取得待ち
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final doc = userDocSnapshot.data;
              final name = doc?.data() != null
                  ? (doc!.data() as Map<String, dynamic>)['name']
                  : null;

              // --- ステップ3: 詳細なプロファイルチェック ---
              // 匿名ユーザーで、かつ名前がまだ設定されていない場合
              if (user.isAnonymous &&
                  (name == null || (name is String && name.trim().isEmpty))) {
                return NameInputScreen(
                  onToggleTheme: widget.onToggleTheme,
                  isDark: widget.isDark,
                );
              }

              // 通常の利用（名前設定済み、またはソーシャルログイン済み）
              return EventListPage(
                onToggleTheme: widget.onToggleTheme,
                isDark: widget.isDark,
              );
            },
          );
        } else {
          // 未ログインの場合、ログイン選択画面を表示
          return LoginChoicePage(
            onToggleTheme: widget.onToggleTheme,
            isDark: widget.isDark,
          );
        }
      },
    );
  }
}
