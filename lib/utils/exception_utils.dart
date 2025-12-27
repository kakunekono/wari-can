/// アプリ内での例外表示を最適化するためのユーティリティクラス。
///
/// Dart の例外オブジェクト（Exception）を `toString()` した際に付与される
/// 型情報（例: "Exception: " や "FirebaseException: "）を除去し、
/// ユーザーに提示するのに適したメッセージ内容のみを抽出します。
class ExceptionUtils {
  /// 例外オブジェクトを受け取り、メッセージの核心部分を整形して返します。
  ///
  /// 例:
  /// - 入力: "Exception: ネットワーク接続に失敗しました"
  /// - 出力: "ネットワーク接続に失敗しました"
  ///
  /// - 入力: "Error 404"
  /// - 出力: "Error 404"
  static String format<T extends Exception>(T e) {
    // 1. 例外を文字列化
    final msg = e.toString();

    // 2. ":" で分割し、型名とメッセージ内容を分離
    final parts = msg.split(':');

    if (parts.length > 1) {
      // 3. 最初の要素（"Exception" など）を除いた残りのリストを取得
      // 4. メッセージ内に ":" が含まれている場合を考慮し、再度結合
      // 5. 前後の余分な空白を削除して返却
      return parts.sublist(1).join(':').trim();
    }

    // ":" が含まれていない場合は、加工せずそのまま返す
    return msg;
  }
}
