// lib/utils/firestore_helper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
      uploadedAt: DateTime.now(),
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
