// lib/utils/firestore_helper.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart'; // Eventモデルのパスに応じて調整

/// イベントをFirestoreに保存（merge付き）
Future<void> saveEventToFirestore(Event event) async {
  try {
    final updated = Event(
      id: event.id,
      name: event.name,
      startDate: event.startDate,
      endDate: event.endDate,
      members: event.members,
      details: event.details,
      createAt: event.createAt,
      updateAt: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection("events")
        .doc(event.id)
        .set(updated.toJson(), SetOptions(merge: true));
    debugPrint("Firestoreにイベント保存完了: ${event.name}");
  } catch (e) {
    debugPrint("Firestore保存失敗: $e");
  }
}

/// Firestoreからイベントを取得（存在しない場合はnull）
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

/// イベントをFirestoreから削除
Future<void> deleteEventFromFirestore(String eventId) async {
  try {
    await FirebaseFirestore.instance.collection("events").doc(eventId).delete();
    debugPrint("Firestoreからイベント削除完了: $eventId");
  } catch (e) {
    debugPrint("Firestore削除失敗: $e");
  }
}

// ----------------------
// Firestore アップロード関数
// ----------------------
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

Future<void> uploadEventToCloud(
  BuildContext context,
  Map<String, dynamic> eventData,
) async {
  final id = eventData["id"];
  if (id == null) {
    debugPrint("イベントIDが存在しません");
    return;
  }

  // 現在時刻を追加（ISO8601文字列）
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
