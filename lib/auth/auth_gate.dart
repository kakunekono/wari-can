import 'package:flutter/foundation.dart';
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

class _AuthGateState extends State<AuthGate> {
  bool _inviteHandled = false;
  Uri? _initialUri;

  @override
  void initState() {
    super.initState();
    _loadInitialUri();
  }

  Future<void> _loadInitialUri() async {
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('eventId')) {
        setState(() => _initialUri = uri);
      }
    }
  }

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
  }

  Future<void> _handleAnonymousNameIfNeeded(User user) async {
    if (!user.isAnonymous) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final name = doc.data()?['name'];

    if (name == null || (name is String && name.trim().isEmpty)) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NameInputScreen()),
      );
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleInviteIfNeeded(user);
            _handleAnonymousNameIfNeeded(user);
          });
          return EventListPage(
            onToggleTheme: widget.onToggleTheme,
            isDark: widget.isDark,
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
