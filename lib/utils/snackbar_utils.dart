import 'package:flutter/material.dart';

/// 共通で SnackBar を表示する関数
void showAppSnackBar(
  BuildContext context, {
  required String message,
  SnackBarType type = SnackBarType.info,
}) {
  Color bgColor;
  IconData icon;

  switch (type) {
    case SnackBarType.info:
      bgColor = Theme.of(context).colorScheme.primary; // 情報 → プライマリカラー
      icon = Icons.info;
      break;
    case SnackBarType.warning:
      bgColor = Theme.of(context).colorScheme.secondary; // 警告 → セカンダリカラー
      icon = Icons.warning;
      break;
    case SnackBarType.error:
      bgColor = Theme.of(context).colorScheme.error; // エラー → エラーカラー
      icon = Icons.error;
      break;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: bgColor,
    ),
  );
}

/// SnackBar の種類
enum SnackBarType { info, warning, error }
