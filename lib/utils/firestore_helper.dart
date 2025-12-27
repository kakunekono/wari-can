import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wari_can/logic/lock_manager.dart';
import 'package:wari_can/utils/exception_utils.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
import '../models/event.dart';

/// イベント保存先の戦略を指定する列挙型。
enum SaveTarget { firestoreOnly, localOnly, both }

/// イベントを保存する。
///
/// 1. ローカル保存 (SharedPreferences): オフライン時の閲覧やバックアップ用。
/// 2. クラウド保存 (Firestore): 共有・同期用。
///
/// クラウド保存時は、競合を防ぐための「LockManagerによる有効性チェック」と
/// 最新データに基づいた「権限チェック」を厳格に行います。
Future<void> saveEventFlexible(
  BuildContext context,
  Event event, {
  SaveTarget target = SaveTarget.both,
}) async {
  // --- ローカル保存フェーズ ---
  if (target == SaveTarget.localOnly || target == SaveTarget.both) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('event_${event.id}', jsonEncode(event.toJson()));
    debugPrint("ローカル保存完了: ${event.name}");
  }

  // --- Firestore保存フェーズ ---
  if (target == SaveTarget.firestoreOnly || target == SaveTarget.both) {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('ログインユーザーが見つかりません');

      // 1. 最新のイベント情報を取得（他者による削除や共有解除の確認）
      final snapshot = await FirebaseFirestore.instance
          .collection("events")
          .doc(event.id)
          .get();

      if (!snapshot.exists) {
        throw Exception("イベントが存在しません: ${event.id}");
      }

      final latestEvent = Event.fromJson(snapshot.data()!);

      // 2. 権限チェック（オーナーか、共有メンバーか）
      final isOwner = latestEvent.ownerUid == uid;
      final isSharedUser = latestEvent.sharedWith.contains(uid);

      if (!isOwner && !isSharedUser) {
        throw Exception('保存権限がありません: ${event.name}');
      }

      // 3. ロックの有効性確認（他人が編集中ではないか）
      final valid = await LockManager.hasValidLock(event.id, uid);
      if (!valid) {
        throw Exception("有効なロックを保持していません。他の方が編集中の可能性があります。");
      }

      // 4. 最新データをベースに、変更内容を反映して保存
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
    } on Exception catch (e) {
      debugPrint("Firestore保存失敗: ${ExceptionUtils.format(e)}");
      rethrow;
    }
  }
}

/// Firestoreから指定IDのイベントを取得。
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
  } on Exception catch (e) {
    debugPrint("Firestore取得失敗: ${ExceptionUtils.format(e)}");
  }
  return null;
}

/// 指定された保存先からイベントを削除。
/// サブコレクション（招待リンク等）のクリーンアップも併せて行います。
Future<void> deleteEventFlexible(
  String eventId, {
  SaveTarget target = SaveTarget.firestoreOnly,
}) async {
  try {
    switch (target) {
      case SaveTarget.firestoreOnly:
        await _deleteInviteLinkSubcollection(eventId);
        await FirebaseFirestore.instance
            .collection("events")
            .doc(eventId)
            .delete();
        break;

      case SaveTarget.localOnly:
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('event_$eventId');
        break;

      case SaveTarget.both:
        await _deleteInviteLinkSubcollection(eventId);
        await FirebaseFirestore.instance
            .collection("events")
            .doc(eventId)
            .delete();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('event_$eventId');
        break;
    }
    debugPrint("イベント削除完了 ($target): $eventId");
  } on Exception catch (e) {
    debugPrint("イベント削除失敗: ${ExceptionUtils.format(e)}");
    rethrow;
  }
}

/// サブコレクション 'inviteLink' 内のドキュメントを一括削除。
Future<void> _deleteInviteLinkSubcollection(String eventId) async {
  final subCollectionRef = FirebaseFirestore.instance
      .collection("events")
      .doc(eventId)
      .collection("inviteLink");

  final snapshot = await subCollectionRef.get();
  final batch = FirebaseFirestore.instance.batch();
  for (final doc in snapshot.docs) {
    batch.delete(doc.reference);
  }

  await batch.commit();
  debugPrint("サブコレクション 'inviteLink' の一括削除完了");
}

/// ローカルに一時保存された全イベントをクラウドに同期。
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
    showAppSnackBar(
      context,
      message: '全ローカルデータを同期しました',
      type: SnackBarType.info,
    );
  } on Exception catch (e) {
    showAppSnackBar(
      context,
      message: "同期失敗: ${ExceptionUtils.format(e)}",
      type: SnackBarType.error,
    );
  }
}

/// 単一のイベントMapデータをFirestoreにアップロード。
Future<void> uploadEventToCloud(
  BuildContext context,
  Map<String, dynamic> eventData,
) async {
  final id = eventData["id"];
  if (id == null) return;

  eventData["updateAt"] = DateTime.now().toIso8601String();

  try {
    await FirebaseFirestore.instance
        .collection("events")
        .doc(id)
        .set(eventData, SetOptions(merge: true));
  } on Exception catch (e) {
    showAppSnackBar(
      context,
      message: "個別アップロード失敗: ${ExceptionUtils.format(e)}",
      type: SnackBarType.error,
    );
  }
}

/// 指定したUIDからユーザー名を取得。
/// 取得できない場合はUIDをそのまま返し、画面が壊れるのを防ぎます。
Future<String> fetchUserName(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists) {
      return doc.data()?['name'] ?? "不明なユーザー";
    }
  } on Exception catch (e) {
    debugPrint('名前取得失敗: ${ExceptionUtils.format(e)}');
  }
  return uid;
}
