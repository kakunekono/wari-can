import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wari_can/init/home_helper.dart';
import 'package:wari_can/models/event.dart';
import 'package:wari_can/pages/event_detail_page.dart';
import 'package:wari_can/utils/snackbar_utils.dart';

import 'firebase_options.dart';
import 'auth/auth_gate.dart';
import 'logic/event_migration.dart';

/// アプリのエントリーポイント。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await migrateLocalEventsIfNeeded();
  runApp(const WariCanApp());
}

/// アプリ全体のルートウィジェット。
class WariCanApp extends StatefulWidget {
  const WariCanApp({super.key});

  @override
  State<WariCanApp> createState() => _WariCanAppState();
}

/// アプリのテーマ管理とルーティングを担当するステート。
class _WariCanAppState extends State<WariCanApp> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  /// SharedPreferences からテーマ設定を読み込む。
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    setState(() => _isDark = isDark);
  }

  /// テーマを切り替えて保存する。
  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final newMode = !_isDark;
    await prefs.setBool('isDark', newMode);
    setState(() => _isDark = newMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '割り勘アプリ',
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      routes: {
        '/eventDetail': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          final eventId = args['eventId'] as String;
          return FutureBuilder<Event>(
            future: FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .get()
                .then((doc) => Event.fromJson(doc.data()!)),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return EventDetailPage(event: snapshot.data!);
            },
          );
        },
      },

      home: HomeWrapper(isDark: _isDark, onToggleTheme: _toggleTheme),
    );
  }
}
