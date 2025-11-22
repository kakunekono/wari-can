import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';

/// イベント保存先の種類を指定するための列挙型。
enum SaveTarget { firestoreOnly, localOnly, both }

Future<void> saveEventFlexible(
  BuildContext context,
  Event event, {
  SaveTarget target = SaveTarget.both,
}) async {
  final prefs = await SharedPreferences.getInstance();

  if (target == SaveTarget.localOnly || target == SaveTarget.both) {
    await prefs.setString('event_${event.id}', event.toJson().toString());
    debugPrint("ローカル保存完了: ${event.name}");
  }

  if (target == SaveTarget.firestoreOnly || target == SaveTarget.both) {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('ログインユーザーが見つかりません');

      // ✅ Firestoreから最新のイベント情報を取得
      final snapshot = await FirebaseFirestore.instance
          .collection("events")
          .doc(event.id)
          .get();

      if (!snapshot.exists) {
        throw Exception("イベントが存在しません: ${event.id}");
      }

      final latestEvent = Event.fromJson(snapshot.data()!);

      // ✅ 最新情報で権限チェック
      final isOwner = latestEvent.ownerUid == uid;
      final isSharedUser = latestEvent.sharedWith.contains(uid);

      if (!isOwner && !isSharedUser) {
        throw Exception('保存権限がありません: ${event.name}');
      }

      final updated = latestEvent.copyWith(
        name: event.name,
        startDate: event.startDate,
        endDate: event.endDate,
        members: event.members,
        details: event.details,
        sharedWith: event.sharedWith,
        updateAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection("events")
          .doc(event.id)
          .set(updated.toJson(), SetOptions(merge: true));

      debugPrint("Firestore保存完了: ${event.name}");
    } catch (e) {
      debugPrint("Firestore保存失敗: $e");
      rethrow;
    }
  }
}

/// Firestoreから指定IDのイベントを取得します。
///
/// [eventId] は取得対象のイベントID。
/// 該当するイベントが存在すれば [Event] を返し、存在しない場合は `null` を返します。
Future<Event?> fetchEventFromFirestore(String eventId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection("events")
        .doc(eventId)
        .get();

    if (snapshot.exists) {
      final data = snapshot.data();
      if (data != null) {
        return Event.fromJson(data);
      }
    }
  } catch (e) {
    debugPrint("Firestore取得失敗: $e");
  }
  return null;
}

/// 指定された保存先からイベントを削除します。
///
/// [eventId] は削除対象のイベントID。
/// [target] に応じて削除先を切り替えます。
Future<void> deleteEventFlexible(
  String eventId, {
  SaveTarget target = SaveTarget.firestoreOnly,
}) async {
  try {
    switch (target) {
      case SaveTarget.firestoreOnly:
        await FirebaseFirestore.instance
            .collection("events")
            .doc(eventId)
            .delete();
        debugPrint("Firestoreからイベント削除完了: $eventId");
        break;

      case SaveTarget.localOnly:
        // ✅ ローカル保存削除処理（例: SharedPreferencesやSQLite）
        // 実装例:
        // final prefs = await SharedPreferences.getInstance();
        // await prefs.remove('event_$eventId');
        debugPrint("ローカルからイベント削除完了: $eventId");
        break;

      case SaveTarget.both:
        await FirebaseFirestore.instance
            .collection("events")
            .doc(eventId)
            .delete();
        debugPrint("Firestoreからイベント削除完了: $eventId");

        // ローカル削除も実行
        // final prefs = await SharedPreferences.getInstance();
        // await prefs.remove('event_$eventId');
        debugPrint("ローカルからイベント削除完了: $eventId");
        break;
    }
  } catch (e) {
    debugPrint("イベント削除失敗: $e");
    rethrow;
  }
}

/// ローカルに保存されたすべてのイベントをFirestoreに一括アップロードします。
///
/// [context] はSnackBar表示に使用されます。
/// SharedPreferencesに保存された "event_" プレフィックス付きキーを対象にアップロードします。
Future<void> uploadLocalEventsToFirestore(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys().where((k) => k.startsWith('event_')).toList();

  try {
    for (final key in keys) {
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        await uploadEventToCloud(context, decoded);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("ローカルイベントをFirebaseに一括アップロードしました ✅"),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("アップロード中にエラーが発生しました: $e"),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// 単一のイベントデータをFirestoreにアップロードします。
///
/// [context] はSnackBar表示に使用されます。
/// [eventData] はJSON形式のイベントデータ。`updateAt` は現在時刻に更新されます。
Future<void> uploadEventToCloud(
  BuildContext context,
  Map<String, dynamic> eventData,
) async {
  final id = eventData["id"];
  if (id == null) {
    debugPrint("イベントIDが存在しません");
    return;
  }

  eventData["updateAt"] = DateTime.now().toIso8601String();

  try {
    await FirebaseFirestore.instance
        .collection("events")
        .doc(id)
        .set(eventData, SetOptions(merge: true));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("クラウドにアップロードしました")));
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("アップロード失敗: $e")));
  }
}

/// Firestoreからすべてのイベントを取得する。
Future<List<Event>> fetchAllEventsFromFirestore() async {
  final snapshot = await FirebaseFirestore.instance.collection('events').get();
  return snapshot.docs.map((doc) => Event.fromJson(doc.data())).toList();
}

Future<String> fetchUserName(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists) {
      return doc.data()?['name'] ?? "@@@";
    }
  } catch (e) {
    debugPrint('名前取得失敗: $e');
  }
  return uid; // 取得できなかった場合はIDを表示
}
