import 'package:cloud_firestore/cloud_firestore.dart';

class LockManager {
  static final _locks = FirebaseFirestore.instance.collection('locks');

  /// ロック取得
  static Future<void> acquireLock(String eventId, String uid) async {
    final ref = _locks.doc(eventId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final now = DateTime.now();
      final expiresAt = snap.data()?['expiresAt']?.toDate();
      final lockedBy = snap.data()?['lockedBy'];

      if (!snap.exists || expiresAt!.isBefore(now) || lockedBy == uid) {
        tx.set(ref, {
          'lockedBy': uid,
          'lockedAt': now,
          'expiresAt': now.add(const Duration(minutes: 30)),
        });
      } else {
        throw Exception('他ユーザーが編集中です');
      }
    });
  }

  /// ロック延長
  static Future<void> refreshLock(String eventId, String uid) async {
    final ref = _locks.doc(eventId);
    final now = DateTime.now();
    await ref.update({
      'lockedBy': uid,
      'lockedAt': now,
      'expiresAt': now.add(const Duration(minutes: 30)),
    });
  }

  /// ロック解除
  static Future<void> releaseLock(
    String eventId,
    String uid, {
    bool isAdmin = false,
    String? ownerUid,
  }) async {
    final ref = _locks.doc(eventId);
    final snap = await ref.get();
    final lockedBy = snap.data()?['lockedBy'];

    if (lockedBy == uid || ownerUid == uid || isAdmin) {
      await ref.delete();
    } else {
      throw Exception('ロック解除権限がありません');
    }
  }

  /// 現在のユーザーが有効なロックを保持しているか確認
  static Future<bool> hasValidLock(String eventId, String uid) async {
    final ref = _locks.doc(eventId);
    final snap = await ref.get();
    if (!snap.exists) return false;

    final data = snap.data()!;
    final lockedBy = data['lockedBy'] as String?;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();

    final now = DateTime.now();
    return lockedBy == uid && expiresAt.isAfter(now);
  }
}
