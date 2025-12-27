import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wari_can/models/common.dart';
import 'package:wari_can/utils/exception_utils.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
import '../models/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// イベントデータのJSON形式でのエクスポートおよびインポートを管理するユーティリティ。
///
/// 外部アプリへの共有や、コピー＆ペーストによるイベントの複製を可能にします。
/// インポート時には、既存データとの衝突を避けるためにIDの再発行（再採番）を行います。
class EventJsonUtils {
  static const _uuid = Uuid();

  /// イベントをJSON形式の文字列に変換し、ダイアログで表示します。
  ///
  /// ユーザーはダイアログを通じて以下の操作が可能です。
  /// - JSONの閲覧（SelectableText）
  /// - クリップボードへのコピー
  /// - OS標準の共有シート呼び出し
  static Future<void> exportEventJson(BuildContext context, Event event) async {
    final jsonStr = jsonEncode(event.toJson());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("イベントJSON"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonStr,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("閉じる"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text("コピー"),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(context);
              showAppSnackBar(
                context,
                message: 'JSONをクリップボードにコピーしました',
                type: SnackBarType.info,
              );
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share, size: 18),
            label: const Text("共有"),
            onPressed: () {
              Share.share(jsonStr, subject: "イベントデータ: ${event.name}");
            },
          ),
        ],
      ),
    );
  }

  /// JSON文字列を解析し、新しいイベントとしてアプリに読み込みます。
  ///
  /// セキュリティと整合性のための処理：
  /// 1. 解析したイベントに新しい UUID を割り振る（既存イベントとの衝突防止）。
  /// 2. 現在のログインユーザーをオーナーとして設定。
  /// 3. 作成・更新日時を現在時刻にリセット。
  /// 4. SharedPreferences に永続化。
  static Future<Event?> importEventJson(BuildContext context) async {
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("JSONから読み込み"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "エクスポートされたJSONを以下に貼り付けてください。",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '{"id": "...", "name": "..."}',
                border: OutlineInputBorder(),
                filled: true,
              ),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("キャンセル"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("読み込み実行"),
          ),
        ],
      ),
    );

    if (result != true || controller.text.trim().isEmpty) return null;

    try {
      // 1. JSONデコード
      final jsonMap =
          jsonDecode(controller.text.trim()) as Map<String, dynamic>;
      final oldEvent = Event.fromJson(jsonMap);

      // 2. タイムスタンプの生成
      final timestamps = TimestampedEntity.newTimestamps();

      // 3. ユーザー情報の取得
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('ログインユーザーが見つからないため、インポートできません');
      }

      // 4. 新しいIDと権限でイベントを再構築
      final newEvent = Event(
        id: _uuid.v4(), // 重要：新しいIDを生成
        name: "${oldEvent.name} (コピー)", // コピーであることがわかるように
        startDate: oldEvent.startDate,
        endDate: oldEvent.endDate,
        members: oldEvent.members,
        details: oldEvent.details,
        ownerUid: uid,
        sharedWith: [uid],
        createAt: timestamps['createAt']!,
        updateAt: timestamps['updateAt']!,
      );

      // 5. ローカルストレージ（SharedPreferences）へ保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'event_${newEvent.id}',
        jsonEncode(newEvent.toJson()),
      );

      if (!context.mounted) return newEvent;

      showAppSnackBar(
        context,
        message: 'イベントを新しく作成しました',
        type: SnackBarType.info,
      );

      return newEvent;
    } on Exception catch (e) {
      if (!context.mounted) return null;
      showAppSnackBar(
        context,
        message: "解析に失敗しました: ${ExceptionUtils.format(e)}",
        type: SnackBarType.error,
      );
      return null;
    } finally {
      controller.dispose();
    }
  }
}
