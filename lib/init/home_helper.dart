import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wari_can/auth/auth_gate.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
import 'dart:html' as html;

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
    // queryParametersから値を取得
    final eventId = uri.queryParameters['eventId'];
    final token = uri.queryParameters['token'] ?? "";

    debugPrint("Invite Link Params - eventId: $eventId, token: $token");

    // idが存在する場合のみ処理を続行
    if (eventId != null && eventId.isNotEmpty) {
      final isValid = await validateInviteLink(eventId, token);

      if (!isValid) {
        showAppSnackBar(context, message: "リンクが無効です", type: SnackBarType.error);
        return;
      }

      debugPrint("Invite link is valid. Registering shared user...");
      await registerSharedUser(eventId);

      // 処理完了後、クエリパラメータを消去してURLをクリーンにする
      html.window.history.replaceState(null, 'トップ', '/');
    }
  }

  Future<bool> validateInviteLink(String eventId, String token) async {
    try {
      // 1. コレクション・ドキュメントの参照を作成
      final docRef = FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('inviteLink')
          .doc('current');

      debugPrint('--- Debug: Fetching doc for eventId: $eventId ---');

      // 2. ドキュメントの取得
      final doc = await docRef.get();

      // 3. ドキュメントの存在確認
      if (!doc.exists) {
        debugPrint(
          'Error: Document "current" does not exist for event: $eventId',
        );
        return false;
      }

      // 4. データの取り出し
      final data = doc.data();
      if (data == null) {
        debugPrint('Error: Document data is null');
        return false;
      }

      // 5. トークンの比較
      final dbToken = data['token'] as String?;
      debugPrint('Debug: DB Token = $dbToken, Input Token = $token');

      if (dbToken == null) {
        debugPrint('Error: Token field is missing in Firestore');
        return false;
      }

      return dbToken == token;
    } catch (e) {
      // 6. エラー（権限不足やネットワークエラーなど）の捕捉
      debugPrint('Exception caught: $e');
      return false;
    }
  }

  /// 共有ユーザのIDをイベントに追加
  Future<void> registerSharedUser(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint("Registering shared user for eventId: $eventId");
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
