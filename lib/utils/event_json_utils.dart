// lib/utils/event_json_utils.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/event.dart';

class EventJsonUtils {
  static final _uuid = Uuid();

  // JSON出力（変更なし）
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
        ],
      ),
    );
  }

  // JSON取込（ID再採番）
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
      // Eventオブジェクト生成
      final oldEvent = Event.fromJson(jsonMap);

      // 新しいIDで複製
      final newEvent = Event(
        id: _uuid.v4(),
        name: oldEvent.name,
        startDate: oldEvent.startDate,
        endDate: oldEvent.endDate,
        members: oldEvent.members,
        details: oldEvent.details,
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
