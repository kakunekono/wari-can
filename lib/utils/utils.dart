import 'package:intl/intl.dart';
import 'package:wari_can/models/event.dart';

/// ユーティリティ関数群（メンバー名変換、金額整形など）
class Utils {
  /// 指定されたメンバーIDに対応する名前を返します。
  ///
  /// [id] はメンバーのID、[members] はメンバー一覧です。
  /// 一致するIDが見つからない場合は「不明」という名前の仮メンバーを生成して返します。
  static String memberName(String id, List<Member> members) {
    final now = DateTime.now();
    return members
        .firstWhere(
          (m) => m.id == id,
          orElse: () =>
              Member(id: id, name: '不明', createAt: now, updateAt: now),
        )
        .name;
  }

  /// 金額をカンマ区切りで整形して文字列として返します。
  ///
  /// [value] は整形対象の数値です。
  /// 整数の場合は小数点なし、小数がある場合は小数第2位まで表示します。
  ///
  /// 例:
  /// ```dart
  /// Utils.formatAmount(1000);      // "1,000"
  /// Utils.formatAmount(1234.56);   // "1,234.56"
  /// ```
  static String formatAmount(num value) {
    if (value % 1 == 0) {
      return NumberFormat('#,###').format(value);
    } else {
      return NumberFormat('#,###.00').format(value);
    }
  }
}
