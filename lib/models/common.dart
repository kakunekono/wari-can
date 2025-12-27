/// タイムスタンプ（作成日時・更新日時）を持つデータモデルの基盤となる抽象クラス。
///
/// すべてのエンティティ（Event, Memberなど）にこのクラスを継承させることで、
/// データの履歴管理を統一したインターフェースで行うことができます。
abstract class TimestampedEntity {
  /// 作成日時：データが最初に保存された時間を記録します。
  final DateTime createAt;

  /// 更新日時：データの内容が変更されるたびに最新の時間に更新されます。
  final DateTime updateAt;

  const TimestampedEntity({required this.createAt, required this.updateAt});

  /// タイムスタンプをJSON形式（ISO 8601 文字列）に変換します。
  ///
  /// Firestoreやローカルストレージに保存する際の標準的なフォーマットとして使用します。
  Map<String, dynamic> toTimestampJson() => {
    'createAt': createAt.toIso8601String(),
    'updateAt': updateAt.toIso8601String(),
  };

  /// 新規データ作成時に使用する、現在時刻のタイムスタンプペアを生成します。
  ///
  /// [createAt] と [updateAt] の両方に同じ現在時刻がセットされます。
  /// 例: `final ts = TimestampedEntity.newTimestamps();`
  static Map<String, DateTime> newTimestamps() {
    final now = DateTime.now();
    return {'createAt': now, 'updateAt': now};
  }

  /// 既存データの更新時に使用するタイムスタンプペアを生成します。
  ///
  /// [originalCreateAt]（作成時）を維持したまま、[updateAt] のみを現在時刻に更新します。
  static Map<String, DateTime> updatedTimestamp({
    required DateTime originalCreateAt,
  }) {
    return {'createAt': originalCreateAt, 'updateAt': DateTime.now()};
  }
}
