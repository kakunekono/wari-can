import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event.dart';
import '../pages/event_detail_page.dart';
import '../utils/firestore_helper.dart';
import '../utils/event_json_utils.dart';

/// イベント一覧画面のロジックをまとめたクラス。
class EventListLogic {
  final _uuid = const Uuid();

  /// ローカルストレージからイベント一覧を読み込む。
  Future<List<Event>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('event_')).toList();
    final events = <Event>[];

    for (final key in keys) {
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        final decoded = jsonDecode(jsonString);
        events.add(Event.fromJson(decoded));
      }
    }

    events.sort((a, b) => a.name.compareTo(b.name));
    return events;
  }

  /// イベントをローカルストレージに保存する。
  Future<void> saveEvent(Event event) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('event_${event.id}', jsonEncode(event.toJson()));
  }

  /// 新しいイベントを作成して保存・返却する。
  Future<Event?> addEvent(BuildContext context, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("イベント名を入力してください"),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    final timestamps = TimestampedEntity.newTimestamps();
    final newEvent = Event(
      id: _uuid.v4(),
      name: trimmed,
      createAt: timestamps['createAt']!,
      updateAt: timestamps['updateAt']!,
    );

    await saveEvent(newEvent);
    return newEvent;
  }

  /// イベントを削除する（ローカル + Firestore）。
  Future<void> deleteEvent(BuildContext context, Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認'),
        content: const Text('本当にこのイベントを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('はい'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('event_${event.id}');
    await deleteEventFromFirestore(event.id);
  }

  /// イベント名を編集する。
  Future<void> editEventName(
    BuildContext context,
    Event event,
    VoidCallback onUpdated,
  ) async {
    final controller = TextEditingController(text: event.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('イベント名を編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新しいイベント名',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && newName != event.name) {
      final updated = event.copyWith(
        name: newName.trim(),
        updateAt: DateTime.now(),
      );
      try {
        await saveEvent(updated);
        await saveEventToFirestore(updated);
        onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("イベント名を「$newName」に変更しました"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("保存に失敗しました: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// イベントをコピーして新規作成する。
  Future<void> copyEvent(
    BuildContext context,
    Event original,
    VoidCallback onUpdated,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("イベントをコピーして追加"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "新しいイベント名"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context, name);
            },
            child: const Text("作成"),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    final now = DateTime.now();
    final newEvent = original.copyWith(
      id: _uuid.v4(),
      name: result,
      members: original.members
          .map((m) => m.copyWith(id: _uuid.v4(), createAt: now, updateAt: now))
          .toList(),
      details: [],
      createAt: now,
      updateAt: now,
    );

    await saveEvent(newEvent);
    onUpdated();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("「${original.name}」のメンバーをコピーして新規イベントを作成しました"),
        backgroundColor: Colors.green,
      ),
    );

    await openEventDetail(context, newEvent);
  }

  /// イベント詳細ページを開き、Firestoreから最新データを取得して更新。
  Future<void> openEventDetail(BuildContext context, Event event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailPage(event: event)),
    );

    final snapshot = await FirebaseFirestore.instance
        .collection("events")
        .doc(event.id)
        .get();
    if (snapshot.exists) {
      final updatedEvent = Event.fromJson(snapshot.data()!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'event_${updatedEvent.id}',
        jsonEncode(updatedEvent.toJson()),
      );
    }
  }

  /// すべてのイベントを削除する確認ダイアログ。
  Future<bool> confirmDeleteAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認'),
        content: const Text('本当にすべてのイベントとデータを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('はい'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('すべてのデータを削除しました')));
      return true;
    }
    return false;
  }

  /// JSONからイベントをインポートする。
  Future<Event?> importEventJson(BuildContext context) async {
    return await EventJsonUtils.importEventJson(context);
  }

  /// ローカルイベントをすべてクラウドにアップロードする。
  Future<void> uploadAllEvents(BuildContext context) async {
    final events = await loadEvents();
    for (final e in events) {
      await saveEventToFirestore(e);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('クラウドへアップロード完了')));
  }

  /// イベント操作ボタン群を構築する。
  List<Widget> buildEventActionButtons(
    BuildContext context,
    Event event, {
    required VoidCallback onUpdated,
    required VoidCallback onDeleted,
  }) {
    return [
      IconButton(
        icon: const Icon(Icons.content_copy),
        tooltip: 'メンバーをコピーして追加',
        iconSize: 20,
        onPressed: () => copyEvent(context, event, onUpdated),
      ),
      IconButton(
        icon: const Icon(Icons.cloud_upload, color: Colors.green),
        tooltip: 'クラウドへアップロード',
        iconSize: 20,
        onPressed: () => saveEventToFirestore(event),
      ),
      IconButton(
        icon: const Icon(Icons.code),
        tooltip: 'JSON出力',
        iconSize: 20,
        onPressed: () => EventJsonUtils.exportEventJson(context, event),
      ),
      IconButton(
        icon: const Icon(Icons.edit, color: Colors.blue),
        tooltip: '編集',
        iconSize: 20,
        onPressed: () => editEventName(context, event, onUpdated),
      ),
      IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        tooltip: '削除',
        iconSize: 20,
        onPressed: () async {
          await deleteEvent(context, event);
          onDeleted();
        },
      ),
    ];
  }
}
