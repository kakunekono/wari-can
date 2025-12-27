import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wari_can/auth/auth_gate.dart';
import 'package:wari_can/utils/snackbar_utils.dart';

/// アプリ起動時の初期処理と認証フローのラップを担当するウィジェット。
///
/// 起動時に一度だけログイン状態をスナックバーで通知し、
/// その後は [AuthGate] に制御を譲って適切な画面を表示させます。
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
  /// ログイン通知の重複表示を防ぐためのフラグ。
  bool _loginSnackShown = false;

  @override
  void initState() {
    super.initState();

    // ウィジェットのビルドが完了した直後に一度だけ実行。
    // ビルド中に Context 操作（SnackBar表示）を行うのを避けるための作法です。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showLoginSnackOnce(context);
      }
    });
  }

  /// 現在のログイン状態を確認し、ユーザーに通知します。
  void _showLoginSnackOnce(BuildContext context) {
    if (_loginSnackShown) return;
    _loginSnackShown = true;

    final user = FirebaseAuth.instance.currentUser;

    // ログイン済みなら成功メッセージ（UID付き）、未ログインなら失敗メッセージを構築。
    final message = user != null ? "ログイン成功 ✅ UID: ${user.uid}" : "ログインしていません ❌";

    final barType = user != null ? SnackBarType.info : SnackBarType.error;

    showAppSnackBar(context, message: message, type: barType);
  }

  @override
  Widget build(BuildContext context) {
    // 認証状態の監視と画面分岐の本体である AuthGate を呼び出す。
    return AuthGate(onToggleTheme: widget.onToggleTheme, isDark: widget.isDark);
  }
}
