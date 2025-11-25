import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wari_can/utils/utils.dart';

import '../pages/event_list_page.dart';
import '../pages/login_choice_page.dart';
import '../pages/name_input_screen.dart';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
  bool _inviteHandled = false;
  Uri? _initialUri;

  @override
  void initState() {
    super.initState();
    _loadInitialUri();
  }

  /// Web版で初期URIを取得する。
  Future<void> _loadInitialUri() async {
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('eventId')) {
        setState(() => _initialUri = uri);
      }
    }
  }

  /// 招待リンクからの参加処理を行う。
  Future<void> _handleInviteIfNeeded(User user) async {
    if (_inviteHandled || _initialUri == null) return;

    final eventId = _initialUri!.queryParameters['eventId'];
    if (eventId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .update({
              'sharedWith': FieldValue.arrayUnion([user.uid]),
            });
      } catch (_) {}
    }

    setState(() => _inviteHandled = true);

    // ✅ 参加処理が終わったらトップURLへ戻す
    if (kIsWeb) {
      // Flutter Navigatorでトップに置き換え
      html.window.history.replaceState(null, 'トップ', Utils.buildBaseUrl());
    }
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
                return const NameInputScreen();
              }

              // 招待処理は通常ログイン時に実行
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handleInviteIfNeeded(user);
              });

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
