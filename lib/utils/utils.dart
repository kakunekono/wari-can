import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
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

  /// 日時を 'yyyy/MM/dd HH:mm:ss' 形式で整形して文字列として返します。
  static formatDateTime(DateTime datetime) {
    return DateFormat('yyyy/MM/dd HH:mm:ss').format(datetime);
  }

  /// 新しいUUIDを生成して返します。
  static String generateUuid() {
    return const Uuid().v4();
  }

  static String generateInviteUrl(String eventId) {
    if (!kIsWeb) return '';

    final uri = Uri.base;
    final scheme = uri.scheme; // ← スキーマ (http / https)
    final host = uri.host;
    final port = uri.hasPort ? uri.port : null;
    final isLocal = host == 'localhost';

    final param = 'eventId=$eventId';

    if (isLocal) {
      final portPart = port != null ? ':$port' : '';
      return '$scheme://$host$portPart/?$param';
    } else {
      final pathSegment = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : '';
      final basePath = pathSegment.isNotEmpty ? '/$pathSegment' : '';
      return '$scheme://$host$basePath/?$param';
    }
  }
}
