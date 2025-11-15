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
}
