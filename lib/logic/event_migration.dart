import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event.dart';

/// ローカルに保存されたイベントに ownerUid / sharedWith を補完して再保存する。
Future<void> migrateLocalEventsIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys().where((k) => k.startsWith('event_')).toList();
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  for (final key in keys) {
    final jsonString = prefs.getString(key);
    if (jsonString == null) continue;

    try {
      final decoded = jsonDecode(jsonString);
      final event = Event.fromJson(decoded);

      if (event.ownerUid.isNotEmpty && event.sharedWith.isNotEmpty) continue;

      final updated = event.copyWith(
        ownerUid: event.ownerUid.isNotEmpty ? event.ownerUid : uid,
        sharedWith: event.sharedWith.isNotEmpty ? event.sharedWith : [uid],
      );

      await prefs.setString(key, jsonEncode(updated.toJson()));
    } catch (e) {
      // 破損データなどはスキップ
    }
  }
}
