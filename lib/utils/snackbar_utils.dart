import 'package:flutter/material.dart';

/// アプリ全体で統一された通知（SnackBar）を表示するための共通関数。
///
/// [context] を通じて現在のテーマ（ThemeData）を参照し、
/// [type] に応じて適切なカラーとアイコンを自動的に選択します。
void showAppSnackBar(
  BuildContext context, {
  required String message,
  SnackBarType type = SnackBarType.info,
}) {
  Color bgColor;
  IconData icon;

  // テーマの ColorScheme に基づいて色を決定することで、
  // ライト/ダークモードの切り替えにも自動対応します。
  switch (type) {
    case SnackBarType.info:
      bgColor = Theme.of(context).colorScheme.primary; // 通常通知: プライマリカラー
      icon = Icons.info_outline;
      break;
    case SnackBarType.warning:
      bgColor = Theme.of(context).colorScheme.secondary; // 警告: セカンダリカラー
      icon = Icons.warning_amber_rounded;
      break;
    case SnackBarType.error:
      bgColor = Theme.of(context).colorScheme.error; // 異常: エラーカラー
      icon = Icons.error_outline;
      break;
  }

  // 既存のスナックバーがある場合は即座にクリアして、最新のものを表示
  ScaffoldMessenger.of(context).hideCurrentSnackBar();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating, // 画面下部に浮かせたモダンなデザイン
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: bgColor,
      duration: const Duration(seconds: 3), // 3秒間表示
    ),
  );
}

/// SnackBar の役割を示す列挙型。
enum SnackBarType {
  /// 成功や一般的な案内
  info,

  /// ユーザーの注意を促す（重複確認など）
  warning,

  /// 保存失敗や権限エラー
  error,
}
