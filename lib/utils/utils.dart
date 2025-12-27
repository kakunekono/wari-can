import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:wari_can/models/menber.dart';

/// アプリ全体で使用される汎用的なユーティリティ関数群。
///
/// データの整形（金額・日付）、識別子の生成、環境依存のパス解決など、
/// ロジックと表示を繋ぐ橋渡しを行います。
class Utils {
  /// メンバーIDから表示名を取得します。
  ///
  /// メンバーリスト内に該当するIDがない場合は「不明」を返します。
  /// データ削除や整合性エラーが発生しても画面がクラッシュしないためのガードが含まれています。
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

  /// 数値を読みやすい通貨形式（カンマ区切り）に整形します。
  ///
  /// [value]: 整形対象の数値（int または double）。
  /// [suffix]: 末尾に "円" を付与するかどうか（デフォルト: true）。
  ///
  /// - 整数の場合: "1,000円"
  /// - 小数の場合: "1,234.56円"（小数第2位まで表示）
  static String formatAmount(num value, [bool suffix = true]) {
    // 整数か小数かを判定してフォーマットを切り替え
    var format = value % 1 == 0
        ? NumberFormat('#,###')
        : NumberFormat('#,###.00');
    return "${format.format(value)}${suffix ? "円" : ""}";
  }

  /// 文字列の数値を金額形式に整形します。
  ///
  /// 入力が不正な文字列（数値以外）の場合は "0" として扱います。
  static String formatStrAmount(String value, [bool suffix = true]) {
    final n = num.tryParse(value) ?? 0;
    return formatAmount(n, suffix);
  }

  /// DateTime を 'yyyy/MM/dd HH:mm:ss' 形式の文字列に変換します。
  static String formatDateTime(DateTime datetime) {
    return DateFormat('yyyy/MM/dd HH:mm:ss').format(datetime);
  }

  /// 一意の識別子（UUID v4）を生成します。
  /// 新しいメンバーやイベントを作成する際のID発行に使用します。
  static String generateUuid() {
    return const Uuid().v4();
  }

  /// アプリが動作しているベースURLを構築します（主にWeb版の招待リンク用）。
  ///
  /// ローカル開発環境（localhost）と本番環境（Firebase Hosting等）の
  /// パス構造の違いを自動的に吸収して正しいURLを返します。
  static String buildBaseUrl() {
    if (!kIsWeb) return '';

    final uri = Uri.base;
    final scheme = uri.scheme;
    final host = uri.host;
    final port = uri.hasPort ? uri.port : null;

    if (host == 'localhost') {
      // ローカル環境: ポート番号を含める
      final portPart = port != null ? ':$port' : '';
      return '$scheme://$host$portPart/';
    } else {
      // 本番環境: サブディレクトリ（Base Path）を考慮して構築
      final pathSegment = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : '';
      final basePath = pathSegment.isNotEmpty ? '/$pathSegment' : '';
      return '$scheme://$host$basePath/';
    }
  }
}
