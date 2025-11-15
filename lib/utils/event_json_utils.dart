import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// イベントデータのJSON入出力を扱うユーティリティクラス。
///
/// - JSON形式でイベントを表示・コピー・共有
/// - JSONからイベントを読み込み、IDを再採番して保存
class EventJsonUtils {
  static final _uuid = Uuid();

  /// イベントをJSON形式で表示・コピー・共有します。
  ///
  /// [context] はダイアログ表示に使用するBuildContext。
  /// [event] は対象のイベントデータ。
  ///
  /// ダイアログにはJSON文字列が表示され、コピーや共有が可能です。
  static Future<void> exportEventJson(BuildContext context, Event event) async {
    final jsonStr = jsonEncode(event.toJson());
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("イベントJSON"),
        content: SingleChildScrollView(child: SelectableText(jsonStr)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("閉じる"),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("JSONをコピーしました")));
            },
            child: const Text("コピー"),
          ),
          ElevatedButton(
            onPressed: () {
              Share.share(jsonStr, subject: "イベントJSON");
            },
            child: const Text("共有"),
          ),
        ],
      ),
    );
  }

  /// JSON文字列からイベントを読み込み、IDを再採番して保存します。
  ///
  /// [context] はダイアログ表示に使用するBuildContext。
  ///
  /// ユーザーが貼り付けたJSONを解析し、新しいIDでイベントを生成・保存します。
  /// 読み込みに成功すると新しい [Event] を返します。失敗時は `null` を返します。
  static Future<Event?> importEventJson(BuildContext context) async {
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("JSONからイベント読み込み"),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'ここにコピーしたJSONを貼り付け',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("キャンセル"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("読み込み"),
          ),
        ],
      ),
    );

    if (result != true) return null;

    try {
      final jsonMap = jsonDecode(controller.text) as Map<String, dynamic>;
      final oldEvent = Event.fromJson(jsonMap);

      final timestamps = TimestampedEntity.newTimestamps();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('ログインユーザーが見つかりません');
      }

      final newEvent = Event(
        id: _uuid.v4(),
        name: oldEvent.name,
        startDate: oldEvent.startDate,
        endDate: oldEvent.endDate,
        members: oldEvent.members,
        details: oldEvent.details,
        ownerUid: uid, // 作成者のUIDを設定
        sharedWith: [uid], // 初期状態では自分だけに共有
        createAt: timestamps['createAt']!,
        updateAt: timestamps['updateAt']!,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'event_${newEvent.id}',
        jsonEncode(newEvent.toJson()),
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("イベントを読み込みました（新IDで追加）")));

      return newEvent;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("読み込みエラー: $e")));
      return null;
    }
  }
}
