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
      bgColor = Colors.blue;
      icon = Icons.info;
      break;
    case SnackBarType.warning:
      bgColor = Colors.orange;
      icon = Icons.warning;
      break;
    case SnackBarType.error:
      bgColor = Colors.red;
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
