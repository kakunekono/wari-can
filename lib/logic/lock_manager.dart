import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestoreを使用したイベントの排他制御（ロック管理）を行うクラス。
///
/// 同じイベントを複数のユーザーが同時に編集して上書きしてしまうのを防ぐため、
/// 編集権（ロック）を特定のユーザーに一定時間付与する仕組みを提供します。
class LockManager {
  /// Firestoreの 'locks' コレクションへの参照
  static final _locks = FirebaseFirestore.instance.collection('locks');

  /// 指定したイベントのロック取得を試みます。
  ///
  /// [eventId] ロック対象のイベントID
  /// [uid] ロックを取得しようとしているユーザーのID
  /// [ownerUid] イベントのオーナーID（強制取得判定に使用）
  /// [force] オーナーが強制的にロックを奪取するかどうかのフラグ
  ///
  /// 戻り値: ロック取得に成功した場合は true、失敗した場合は false
  static Future<bool> acquireLock(
    String eventId,
    String uid, {
    String? ownerUid,
    bool force = false,
  }) async {
    final ref = _locks.doc(eventId);

    // トランザクションを使用して、読み取りと書き込みの間に他者の介入を許さない
    return await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final now = DateTime.now();
      final expiresAt = snap.data()?['expiresAt']?.toDate();
      final lockedBy = snap.data()?['lockedBy'];

      final isOwner = ownerUid != null && uid == ownerUid;

      // ロックが取得可能な条件:
      // 1. ロックドキュメントが存在しない
      // 2. 有効期限が切れている
      // 3. 既に自分がロックを保持している
      // 4. 強制フラグ(force)が true で、かつ自分がオーナーである
      if (!snap.exists ||
          expiresAt == null ||
          expiresAt.isBefore(now) ||
          lockedBy == uid ||
          (force && isOwner)) {
        // ロック情報を書き込み（有効期限は15分間に設定）
        tx.set(ref, {
          'lockedBy': uid,
          'lockedAt': now,
          'expiresAt': now.add(const Duration(minutes: 15)),
        });
        return true;
      }
      // 他の誰かが有効なロックを保持している場合は失敗
      return false;
    });
  }

  /// 保持しているロックを解放（ドキュメント削除）します。
  ///
  /// [isAdmin] 管理者権限（強制解除）フラグ
  /// [ownerUid] オーナーであれば他者のロックでも解除可能
  static Future<void> releaseLock(
    String eventId,
    String uid, {
    bool isAdmin = false,
    String? ownerUid,
  }) async {
    final ref = _locks.doc(eventId);
    final snap = await ref.get();

    if (!snap.exists) return; // 既にロックがない場合は何もしない

    final lockedBy = snap.data()?['lockedBy'];

    // 解除できる条件: 本人、オーナー、または管理者
    if (lockedBy == uid || ownerUid == uid || isAdmin) {
      await ref.delete();
    } else {
      throw Exception('ロック解除権限がありません');
    }
  }

  /// 現在、自分が有効なロックを保持しているか確認します。
  static Future<bool> hasValidLock(String eventId, String uid) async {
    final ref = _locks.doc(eventId);
    final snap = await ref.get();
    if (!snap.exists) return false;

    final data = snap.data()!;
    final lockedBy = data['lockedBy'] as String?;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();

    final now = DateTime.now();
    // 保持者が自分であり、かつ期限内であれば true
    return lockedBy == uid && expiresAt.isAfter(now);
  }

  /// ロックの取得・処理・解放をひとまとめに行う高階関数です。
  ///
  /// 取得に失敗した場合は例外を投げ、成功した場合は [action] を実行した後に必ずロックを解放します。
  static Future<T?> runWithLock<T>(
    String eventId,
    String uid,
    Future<T> Function() action,
  ) async {
    bool acquired = false;
    try {
      acquired = await acquireLock(eventId, uid);
      if (!acquired) throw Exception('他のユーザーがこのイベントを編集中です。しばらく待ってからやり直してください。');

      // 実際の業務ロジックを実行
      return await action();
    } finally {
      // 成功・失敗に関わらず、ロックを取得していた場合は確実に解放する
      if (acquired) {
        await releaseLock(eventId, uid);
      }
    }
  }
}
