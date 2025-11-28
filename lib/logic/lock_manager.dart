import 'package:cloud_firestore/cloud_firestore.dart';

class LockManager {
  static final _locks = FirebaseFirestore.instance.collection('locks');

  /// ロック取得（成功なら true、失敗なら false）
  static Future<bool> acquireLock(
    String eventId,
    String uid, {
    String? ownerUid,
    bool force = false,
  }) async {
    final ref = _locks.doc(eventId);
    return await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final now = DateTime.now();
      final expiresAt = snap.data()?['expiresAt']?.toDate();
      final lockedBy = snap.data()?['lockedBy'];

      final isOwner = ownerUid != null && uid == ownerUid;

      if (!snap.exists ||
          expiresAt == null ||
          expiresAt.isBefore(now) ||
          lockedBy == uid ||
          (force && isOwner) // オーナーかつ強制フラグがtrueの時のみ強制取得
          ) {
        tx.set(ref, {
          'lockedBy': uid,
          'lockedAt': now,
          'expiresAt': now.add(const Duration(minutes: 15)),
        });
        return true;
      }
      return false;
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

  /// 有効ロック確認
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

  /// ロック付き処理を共通化
  static Future<T?> runWithLock<T>(
    String eventId,
    String uid,
    Future<T> Function() action,
  ) async {
    bool acquired = false;
    try {
      acquired = await acquireLock(eventId, uid);
      if (!acquired) throw Exception('他ユーザーが編集中です');
      return await action();
    } finally {
      if (acquired) {
        await releaseLock(eventId, uid);
      }
    }
  }
}
