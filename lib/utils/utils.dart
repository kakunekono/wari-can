import 'package:wari_can/models/event.dart';

class Utils {
  // ----------------------
  // id → name 変換
  // ----------------------
  static String memberName(String id, List<Member> members) => members
      .firstWhere(
        (m) => m.id == id,
        orElse: () => Member(id: id, name: '不明'),
      )
      .name;
}
