import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wari_can/logic/lock_manager.dart';
import 'package:wari_can/models/common.dart';
import 'package:wari_can/models/menber.dart';
import 'package:wari_can/utils/exception_utils.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
import 'package:wari_can/utils/utils.dart';

import '../models/event.dart';
import '../pages/event_detail_page.dart';
import '../utils/firestore_helper.dart';
import '../utils/event_json_utils.dart';

/// イベント一覧画面のビジネスロジックを管理するクラス。
///
/// Firestore（クラウド）と SharedPreferences（ローカル）の同期、
/// 排他制御（Lock）を考慮したデータ操作、インポート/エクスポートなどを担当します。
class EventListLogic {
  /// メンバーのID再生成などに使用するUUIDジェネレータ
  final _uuid = const Uuid();

  /// アプリ起動中の初期化実行済みフラグ
  bool _initialized = false;

  /// Firestoreからイベントを取得し、ローカルキャッシュ（SharedPrefs）を最新状態に更新します。
  Future<List<Event>> loadEventsAndUpdateLocalCache() async {
    final events = await loadEvents();
    final prefs = await SharedPreferences.getInstance();
    for (final e in events) {
      await prefs.setString('event_${e.id}', jsonEncode(e.toJson()));
    }
    return events;
  }

  /// ローカルのイベントキャッシュを一度全削除したあと、Firestoreから再取得して保存し直します。
  ///
  /// クラウドとローカルの不整合を解消したい場合に呼び出します。
  Future<List<Event>> reloadEventsFromFirestoreAndResave() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. ローカル上の event_ から始まるキーをすべて削除
    final keys = prefs.getKeys().where((k) => k.startsWith('event_')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    debugPrint("[Logic] Cleared ${keys.length} local events.");

    // 2. Firestoreから最新リストを取得
    final events = await loadEvents();
    debugPrint("[Logic] Fetched ${events.length} events from Firestore.");

    // 3. 取得したデータをローカルに再保存
    for (final e in events) {
      await prefs.setString('event_${e.id}', jsonEncode(e.toJson()));
    }
    debugPrint("[Logic] Re-saved events to local storage.");

    return events;
  }

  /// 初期化処理（UI側のinitStateなどで一度だけ呼び出されることを想定）。
  Future<void> initializeOnce(
    BuildContext context,
    void Function(List<Event>) onInitialized,
  ) async {
    if (_initialized) return;
    _initialized = true;
    final events = await reloadEventsFromFirestoreAndResave();
    onInitialized(events);
  }

  /// ログインユーザーが関係する（オーナーまたは共有相手である）イベント一覧をFirestoreから取得します。
  Future<List<Event>> loadEvents() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('ログインしていません');

    final events = <Event>[];

    try {
      // 自分が作成（オーナー）したイベントを取得
      final ownerSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('ownerUid', isEqualTo: uid)
          .get();
      events.addAll(
        ownerSnapshot.docs.map((doc) => Event.fromJson(doc.data())),
      );

      // 他人から自分に共有されているイベントを取得
      final sharedSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('sharedWith', arrayContains: uid)
          .get();
      for (final doc in sharedSnapshot.docs) {
        final event = Event.fromJson(doc.data());
        // 重複（オーナーかつ共有者という稀なケース）を排除
        if (!events.any((e) => e.id == event.id)) {
          events.add(event);
        }
      }

      // 名前順にソートして返却
      events.sort((a, b) => a.name.compareTo(b.name));
      return events;
    } on Exception catch (e) {
      debugPrint('Firestoreイベント取得失敗: ${ExceptionUtils.format(e)}');
      return [];
    }
  }

  /// 既存のEventオブジェクトをFirestoreに保存します。
  Future<Event?> addEvent(BuildContext context, Event event) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .set(event.toJson());

      debugPrint("イベント保存成功: ${event.id}");
      return event;
    } on Exception catch (e) {
      final msg = ExceptionUtils.format(e);
      debugPrint("イベント保存失敗: $msg");
      showAppSnackBar(context, message: msg);
      return null;
    }
  }

  /// 新規イベント名から新しいEventを作成し、クラウドとローカルの両方に保存します。
  Future<Event?> addEventWithName(BuildContext context, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      showAppSnackBar(
        context,
        message: 'イベント名を入力してください',
        type: SnackBarType.error,
      );
      return null;
    }

    final timestamps = TimestampedEntity.newTimestamps();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('ログインユーザーが見つかりません');

    // 新規イベントデータの生成
    final newEvent = Event(
      id: Utils.generateUuid(),
      name: trimmed,
      ownerUid: uid,
      sharedWith: [uid],
      createAt: timestamps['createAt']!,
      updateAt: timestamps['updateAt']!,
    );

    try {
      // クラウド保存
      await FirebaseFirestore.instance
          .collection("events")
          .doc(newEvent.id)
          .set(newEvent.toJson());

      // ローカル保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'event_${newEvent.id}',
        jsonEncode(newEvent.toJson()),
      );

      debugPrint("イベント作成完了: ${newEvent.name}");
      return newEvent;
    } on Exception catch (e) {
      debugPrint("イベント保存失敗: ${ExceptionUtils.format(e)}");
      showAppSnackBar(
        context,
        message: "イベントの保存に失敗しました: ${ExceptionUtils.format(e)}",
        type: SnackBarType.error,
      );
      return null;
    }
  }

  /// イベントを削除します。他ユーザーによる編集中の場合は削除をブロックします。
  Future<bool> deleteEvent(BuildContext context, Event event) async {
    // 削除確認
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

    if (confirmed != true) return false;

    final lockRef = FirebaseFirestore.instance
        .collection('locks')
        .doc(event.id);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    bool acquiredLock = false;

    try {
      // 編集ロックを取得できるかトランザクションで確認（競合防止）
      final success = await FirebaseFirestore.instance.runTransaction((
        tx,
      ) async {
        final snapshot = await tx.get(lockRef);
        if (!snapshot.exists || snapshot['lockedBy'] == uid) {
          tx.set(lockRef, {'lockedBy': uid});
          return true;
        }
        return false;
      });

      if (!success) {
        showAppSnackBar(
          context,
          message: "他のユーザーが編集中のため、削除できません。",
          type: SnackBarType.error,
        );
        return false;
      }

      acquiredLock = true;

      // 両ターゲット（Firestore/Local）から削除を実行
      await deleteEventFlexible(event.id, target: SaveTarget.both);

      return true;
    } on Exception catch (e) {
      showAppSnackBar(
        context,
        message: "削除処理中にエラーが発生しました: ${ExceptionUtils.format(e)}",
        type: SnackBarType.error,
      );
      return false;
    } finally {
      // 取得したロックを削除
      if (acquiredLock) {
        await lockRef.delete();
      }
    }
  }

  /// イベント名の変更を行います。ロック取得→保存→ロック解放のフロー。
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

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      bool acquiredLock = false;

      try {
        // ロックを取得
        await LockManager.acquireLock(event.id, uid);
        acquiredLock = true;

        // 更新処理
        await saveEventFlexible(context, updated);
        onUpdated();

        showAppSnackBar(
          context,
          message: 'イベント名を「$newName」に変更しました',
          type: SnackBarType.info,
        );
      } on Exception catch (e) {
        showAppSnackBar(
          context,
          message: "保存に失敗しました: ${ExceptionUtils.format(e)}",
          type: SnackBarType.error,
        );
      } finally {
        // 自分が取得した場合のみロックを解放
        if (acquiredLock) {
          await LockManager.releaseLock(event.id, uid);
        }
      }
    }
  }

  /// 既存イベントのメンバー構成をコピーし、新しい空のイベントを作成します。
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
    // メンバーのIDを新規発行しつつリストを複製
    final newEvent = original.copyWith(
      id: _uuid.v4(),
      name: result,
      members: original.members
          .map((m) => m.copyWith(id: _uuid.v4(), createAt: now, updateAt: now))
          .toList(),
      sharedWith: [],
      details: [],
      createAt: now,
      updateAt: now,
    );

    await addEvent(context, newEvent);
    onUpdated();
    showAppSnackBar(
      context,
      message: "「${original.name}」のメンバーをコピーして新規イベントを作成しました",
      type: SnackBarType.info,
    );

    // 作成後そのまま詳細画面へ遷移
    await openEventDetail(context, newEvent);
  }

  /// イベント詳細画面を開きます。
  /// クラウドから最新データを強制取得（プル）してから遷移することで、他ユーザーの編集を確実に反映します。
  Future<void> openEventDetail(BuildContext context, Event event) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('ユーザーが未ログインです');

      final docRef = FirebaseFirestore.instance
          .collection("events")
          .doc(event.id);

      // キャッシュを無視してサーバーから最新データを取得
      final snapshot = await docRef.get(
        const GetOptions(source: Source.server),
      );

      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('イベントが存在しません:${event.id}');
      }

      final data = snapshot.data()!;
      final updatedEvent = Event.fromJson(data);

      // 権限チェック
      final ownerUid = data['ownerUid'] as String?;
      final sharedWith = List<String>.from(data['sharedWith'] ?? []);
      if (ownerUid != uid && !sharedWith.contains(uid)) {
        throw Exception('このイベントにアクセスする権限がありません');
      }

      // 取得した最新データをローカルキャッシュに上書き保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'event_${updatedEvent.id}',
        jsonEncode(updatedEvent.toJson()),
      );

      // 詳細画面へ遷移し、戻り値を待機
      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => EventDetailPage(event: updatedEvent)),
      );

      debugPrint("イベント詳細ページから戻りました。更新: $updated");

      // 詳細画面で更新があった場合、リスト画面側も最新状態に同期
      if (updated == true) {
        await loadEventsAndUpdateLocalCache();
      }
    } on Exception catch (e) {
      debugPrint('イベント取得エラー: ${ExceptionUtils.format(e)}');
      showAppSnackBar(
        context,
        message: 'イベントの読み込みに失敗しました: ${ExceptionUtils.format(e)}',
        type: SnackBarType.error,
      );
    }
  }

  /// アプリ内のすべてのローカルデータを削除する際の確認・実行。
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
      showAppSnackBar(
        context,
        message: 'すべてのデータを削除しました',
        type: SnackBarType.info,
      );
      return true;
    }
    return false;
  }

  /// 外部ファイル（JSON）からイベントを読み込みます。
  Future<Event?> importEventJson(BuildContext context) async {
    return await EventJsonUtils.importEventJson(context);
  }

  /// 現在読み込んでいるすべてのイベントをFirestoreに強制アップロード（同期）します。
  Future<void> uploadAllEvents(BuildContext context) async {
    final events = await loadEvents();
    for (final e in events) {
      await saveEventFlexible(context, e, target: SaveTarget.firestoreOnly);
    }
    showAppSnackBar(context, message: 'クラウドへアップロード完了', type: SnackBarType.info);
  }

  /// 一覧画面の各行に表示するアクション（コピー・JSON・編集・削除）ボタンのリストを構築します。
  List<Widget> buildEventActionButtons(
    BuildContext context,
    Event event, {
    required VoidCallback onUpdated,
    required VoidCallback onDeleted,
  }) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = event.ownerUid == currentUid;

    return [
      // メンバーコピーボタン
      IconButton(
        icon: const Icon(Icons.content_copy),
        tooltip: 'メンバーをコピーして追加',
        iconSize: 20,
        onPressed: () => copyEvent(context, event, onUpdated),
      ),
      // JSONエクスポートボタン
      IconButton(
        icon: const Icon(Icons.code),
        tooltip: 'JSON出力',
        iconSize: 20,
        onPressed: () => EventJsonUtils.exportEventJson(context, event),
      ),
      // オーナー限定：編集ボタン
      if (isOwner)
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          tooltip: '編集',
          iconSize: 20,
          onPressed: () => editEventName(context, event, onUpdated),
        ),
      // オーナー限定：削除ボタン
      if (isOwner)
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: '削除',
          iconSize: 20,
          onPressed: () async {
            if (await deleteEvent(context, event)) {
              onDeleted();
            }
          },
        ),
    ];
  }
}
