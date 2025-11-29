/// タイムスタンプ付きエンティティの抽象クラス。
/// createAt（作成日時）と updateAt（更新日時）を共通で持つ。
abstract class TimestampedEntity {
  /// 作成日時
  final DateTime createAt;

  /// 更新日時
  final DateTime updateAt;

  const TimestampedEntity({required this.createAt, required this.updateAt});

  /// タイムスタンプをJSON形式に変換する。
  Map<String, dynamic> toTimestampJson() => {
    'createAt': createAt.toIso8601String(),
    'updateAt': updateAt.toIso8601String(),
  };

  /// 新規作成用のタイムスタンプを生成する。
  static Map<String, DateTime> newTimestamps() {
    final now = DateTime.now();
    return {'createAt': now, 'updateAt': now};
  }

  /// 更新時のタイムスタンプを生成する。
  static Map<String, DateTime> updatedTimestamp({
    required DateTime originalCreateAt,
  }) {
    return {'createAt': originalCreateAt, 'updateAt': DateTime.now()};
  }
}
