import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../pages/event_list_page.dart';
import '../pages/login_choice_page.dart';
import '../pages/name_input_screen.dart';

/// 認証状態に応じて適切な画面に遷移するウィジェット。
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

/// AuthGate のステート。
class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final doc = userDocSnapshot.data;
              final name = doc?.data() != null
                  ? (doc!.data() as Map<String, dynamic>)['name']
                  : null;

              // 匿名ユーザで名前未設定なら NameInputScreen を優先
              if (user.isAnonymous &&
                  (name == null || (name is String && name.trim().isEmpty))) {
                return NameInputScreen(
                  onToggleTheme: widget.onToggleTheme,
                  isDark: widget.isDark,
                );
              }

              return EventListPage(
                onToggleTheme: widget.onToggleTheme,
                isDark: widget.isDark,
              );
            },
          );
        } else {
          return LoginChoicePage(
            onToggleTheme: widget.onToggleTheme,
            isDark: widget.isDark,
          );
        }
      },
    );
  }
}
