import 'package:intl/intl.dart';
import 'package:wari_can/models/event.dart';

class Utils {
  // ----------------------
  // id → name 変換
  // ----------------------
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

  static String formatAmount(num value) {
    if (value % 1 == 0) {
      // 整数なら小数なしで表示
      return NumberFormat('#,###').format(value);
    } else {
      // 小数がある場合のみ小数2桁表示
      return NumberFormat('#,###.00').format(value);
    }
  }
}
