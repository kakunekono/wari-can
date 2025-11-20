import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wari_can/utils/utils.dart';

import '../models/event.dart';
import '../pages/event_detail_page.dart';
import '../utils/firestore_helper.dart';
import '../utils/event_json_utils.dart';

/// イベント一覧画面のロジックをまとめたクラス。
class EventListLogic {
  final _uuid = const Uuid();
  bool _initialized = false;

  /// Firestoreからイベントを取得し、ローカルキャッシュも更新して返す。
  Future<List<Event>> loadEventsAndUpdateLocalCache() async {
    final events = await loadEvents();

    final prefs = await SharedPreferences.getInstance();
    for (final e in events) {
      await prefs.setString('event_${e.id}', jsonEncode(e.toJson()));
    }

    return events;
  }

  /// Firestoreからイベントを取得し、ローカルストレージを再構成して返す。
  Future<List<Event>> reloadEventsFromFirestoreAndResave() async {
    final prefs = await SharedPreferences.getInstance();

    // 🔸 ローカルイベントキーをすべて削除
    final keys = prefs.getKeys().where((k) => k.startsWith('event_')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }

    debugPrint("[Logic] Cleared ${keys.length} local events.");

    // 🔸 Firestoreからイベント一覧を取得
    final events = await loadEvents();

    debugPrint("[Logic] Fetched ${events.length} events from Firestore.");

    // 🔸 ローカルに保存し直す
    for (final e in events) {
      await prefs.setString('event_${e.id}', jsonEncode(e.toJson()));
    }

    debugPrint("[Logic] Re-saved events to local storage.");
    return events;
  }

  /// 初期化処理を一度だけ実行する（UI側から呼び出し）。
  Future<void> initializeOnce(
    BuildContext context,
    void Function(List<Event>) onInitialized,
  ) async {
    if (_initialized) return;
    _initialized = true;
    final events = await reloadEventsFromFirestoreAndResave();
    onInitialized(events);
  }

  /// Firestoreから、ログインユーザーがアクセス可能なイベント一覧を読み込む。
  Future<List<Event>> loadEvents() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('ログインしていません');
    }

    final events = <Event>[];

    try {
      // 🔹 自分が作成したイベント
      final ownerSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('ownerUid', isEqualTo: uid)
          .get();

      events.addAll(
        ownerSnapshot.docs.map((doc) => Event.fromJson(doc.data())),
      );

      // 🔹 自分が共有されているイベント
      final sharedSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('sharedWith', arrayContains: uid)
          .get();

      for (final doc in sharedSnapshot.docs) {
        final event = Event.fromJson(doc.data());
        // 重複チェック（ownerとshared両方に含まれる場合）
        if (!events.any((e) => e.id == event.id)) {
          events.add(event);
        }
      }

      events.sort((a, b) => a.name.compareTo(b.name));
      return events;
    } catch (e) {
      debugPrint('Firestoreイベント取得失敗: $e');
      return [];
    }
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('ログインユーザーが見つかりません');
    }

    final newEvent = Event(
      id: Utils.generateUuid(),
      name: trimmed,
      ownerUid: uid,
      sharedWith: [uid],
      createAt: timestamps['createAt']!,
      updateAt: timestamps['updateAt']!,
    );

    try {
      // 🔹 Firestore に保存
      await FirebaseFirestore.instance
          .collection("events")
          .doc(newEvent.id)
          .set(newEvent.toJson());

      // 🔹 SharedPreferences に保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'event_${newEvent.id}',
        jsonEncode(newEvent.toJson()),
      );

      debugPrint("イベント作成完了: ${newEvent.name}");
      return newEvent;
    } catch (e) {
      debugPrint("イベント保存失敗: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("イベントの保存に失敗しました: $e"),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
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
        await saveEventFlexible(context, updated);
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

  /// メンバーをコピーしてイベントを新規作成する。
  Future<void> copyEvent(
    BuildContext context,
    Event original,
    VoidCallback onUpdated,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("メンバーをコピーしてイベントを追加"),
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

    await saveEventFlexible(context, newEvent);
    onUpdated();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("「${original.name}」のメンバーをコピーして新規イベントを作成しました"),
        backgroundColor: Colors.green,
      ),
    );

    await openEventDetail(context, newEvent);
  }

  /// イベント詳細ページを開き、Firestoreから最新データを取得してローカルに保存する。
  Future<void> openEventDetail(BuildContext context, Event event) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('ユーザーが未ログインです');

      final docRef = FirebaseFirestore.instance
          .collection("events")
          .doc(event.id);

      // 🔹 Firestoreから最新データを取得（キャッシュ無視）
      final snapshot = await docRef.get(
        const GetOptions(source: Source.server),
      );

      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('イベントが存在しません');
      }

      final data = snapshot.data()!;
      final updatedEvent = Event.fromJson(data);

      // 🔹 アクセス権の確認
      final ownerUid = data['ownerUid'] as String?;
      final sharedWith = List<String>.from(data['sharedWith'] ?? []);
      if (ownerUid != uid && !sharedWith.contains(uid)) {
        throw Exception('このイベントにアクセスする権限がありません');
      }

      // 🔹 ローカルに保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'event_${updatedEvent.id}',
        jsonEncode(updatedEvent.toJson()),
      );

      // 🔹 最新データで画面を開く
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailPage(event: updatedEvent)),
      );
    } catch (e) {
      debugPrint('イベント取得エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('イベントの読み込みに失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
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
      await saveEventFlexible(context, e, target: SaveTarget.firestoreOnly);
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
        onPressed: () =>
            saveEventFlexible(context, event, target: SaveTarget.firestoreOnly),
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
