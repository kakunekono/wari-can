import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wari_can/auth/auth_gate.dart';
import 'package:wari_can/utils/snackbar_utils.dart';

class HomeWrapper extends StatefulWidget {
  final bool isDark;
  final Future<void> Function() onToggleTheme;

  const HomeWrapper({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  bool _loginSnackShown = false;

  @override
  void initState() {
    super.initState();
    // フレーム描画後に一度だけ呼ぶ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handleInviteLink(context);
      _showLoginSnackOnce(context);
    });
  }

  void _showLoginSnackOnce(BuildContext context) {
    if (_loginSnackShown) return;
    _loginSnackShown = true;

    final user = FirebaseAuth.instance.currentUser;
    final message = user != null ? "ログイン成功 ✅ UID: ${user.uid}" : "ログイン失敗 ❌";
    final barType = user != null ? SnackBarType.info : SnackBarType.error;

    showAppSnackBar(context, message: message, type: barType);
  }

  bool _inviteHandled = false;
  void handleInviteLink(BuildContext context) async {
    if (_inviteHandled) return;
    _inviteHandled = true;

    final uri = Uri.base;
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == "event") {
      final eventId = uri.pathSegments[1];
      final token = uri.queryParameters['token'] ?? "";

      final isValid = await validateInviteLink(eventId, token);
      if (!isValid) {
        showAppSnackBar(context, message: "リンクが無効です", type: SnackBarType.error);
        return;
      }
      await registerSharedUser(eventId);
    }
  }

  Future<bool> validateInviteLink(String eventId, String token) async {
    final doc = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('inviteLink')
        .doc('current')
        .get();

    if (!doc.exists) return false;

    final data = doc.data()!;
    return data['token'] == token && data['active'] == true;
  }

  /// 共有ユーザのIDをイベントに追加
  Future<void> registerSharedUser(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // 未ログインなら何もしない
    debugPrint("user:${user.uid}");
    await FirebaseFirestore.instance.collection('events').doc(eventId).update({
      'sharedWith': FieldValue.arrayUnion([user.uid]),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthGate(onToggleTheme: widget.onToggleTheme, isDark: widget.isDark);
  }
}
