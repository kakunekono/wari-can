/// 共通的な例外メッセージ整形ユーティリティ
class ExceptionUtils {
  /// ExceptionやErrorを受け取ってメッセージ部分だけを返す
  static String format<T extends Exception>(T e) {
    final msg = e.toString();
    final parts = msg.split(':');
    if (parts.length > 1) {
      // 先頭を捨てて残りを結合（trimで余分な空白を削除）
      return parts.sublist(1).join(':').trim();
    }
    return msg; // ":" が含まれない場合はそのまま返す
  }
}
