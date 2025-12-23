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

  @override
  Widget build(BuildContext context) {
    return AuthGate(onToggleTheme: widget.onToggleTheme, isDark: widget.isDark);
  }
}
