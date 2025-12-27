import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wari_can/utils/exception_utils.dart';
import '../models/event.dart';

/// ローカル（SharedPref）に保存されたイベントデータの整合性をチェックし、
/// 必要に応じて `ownerUid` や `sharedWith` を補完して再保存します。
///
/// アプリのバージョンアップなどでデータモデルが拡張された際、
/// 既存の古い形式のデータを最新の形式へ「マイグレーション（移行）」するために使用します。
Future<void> migrateLocalEventsIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();

  // 1. ローカル上の event_ から始まるキー（保存済みイベント）をすべて抽出
  final keys = prefs.getKeys().where((k) => k.startsWith('event_')).toList();

  // ログイン中のユーザーIDを取得。未ログインならマイグレーション不可のため終了
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  for (final key in keys) {
    final jsonString = prefs.getString(key);
    if (jsonString == null) continue;

    try {
      // JSONをデコードしてEventモデルに変換
      final decoded = jsonDecode(jsonString);
      final event = Event.fromJson(decoded);

      // すでに最新の形式（オーナー情報や共有情報がある）であれば、何もしない
      if (event.ownerUid.isNotEmpty && event.sharedWith.isNotEmpty) continue;

      // 欠損している項目を、現在のユーザーIDで補完する
      // - ownerUid が空なら、現在のユーザーをオーナーに設定
      // - sharedWith が空なら、現在のユーザーのみを含むリストを設定
      final updated = event.copyWith(
        ownerUid: event.ownerUid.isNotEmpty ? event.ownerUid : uid,
        sharedWith: event.sharedWith.isNotEmpty ? event.sharedWith : [uid],
      );

      // 最新のJSON形式でローカルストレージを上書き保存
      await prefs.setString(key, jsonEncode(updated.toJson()));

      debugPrint(
        "[Migration] Updated local event: ${event.id} with current user info.",
      );
    } on Exception catch (e) {
      // JSONの構造が壊れている場合や、デコードに失敗したデータはスキップする
      debugPrint(
        "[Migration] Failed to migrate event at $key: ${ExceptionUtils.format((e))}",
      );
    }
  }
}
