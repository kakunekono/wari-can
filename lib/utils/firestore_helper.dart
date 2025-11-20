import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';

/// イベント保存先の種類を指定するための列挙型。
enum SaveTarget { firestoreOnly, localOnly, both }

/// 指定された保存先にイベントを保存します。
/// - [context] は Provider から SharedPreferences や FirebaseAuth を取得するために使用します。
/// - [event] は保存対象のイベント。
/// - [target] に応じて保存先を切り替えます。
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

      final updated = Event(
        id: event.id,
        name: event.name,
        startDate: event.startDate,
        endDate: event.endDate,
        members: event.members,
        details: event.details,
        ownerUid: event.ownerUid,
        sharedWith: event.sharedWith.isNotEmpty ? event.sharedWith : [uid],
        createAt: event.createAt,
        updateAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection("events")
          .doc(event.id)
          .set(updated.toJson(), SetOptions(merge: true));

      debugPrint("Firestore保存完了: ${event.name}");
    } catch (e) {
      debugPrint("Firestore保存失敗: $e");
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

/// Firestoreから指定IDのイベントを削除します。
///
/// [eventId] は削除対象のイベントID。
Future<void> deleteEventFromFirestore(String eventId) async {
  try {
    await FirebaseFirestore.instance.collection("events").doc(eventId).delete();
    debugPrint("Firestoreからイベント削除完了: $eventId");
  } catch (e) {
    debugPrint("Firestore削除失敗: $e");
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
