import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wari_can/init/home_helper.dart';
import 'package:wari_can/models/event.dart';
import 'package:wari_can/pages/event_detail_page.dart';

import 'firebase_options.dart';
import 'logic/event_migration.dart';

/// アプリのエントリーポイント。
///
/// Firebaseの初期化、およびローカルからクラウドへのデータ移行処理を
/// アプリ起動の最優先タスクとして実行します。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebaseの初期化（プラットフォームごとの設定を適用）
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ローカル（SharedPrefs）に古いデータがある場合、必要に応じてマイグレーションを実行
  await migrateLocalEventsIfNeeded();

  runApp(const WariCanApp());
}

/// アプリ全体のルートウィジェット。
///
/// [ThemeData] の管理や、名前付きルートの設定を担当します。
class WariCanApp extends StatefulWidget {
  const WariCanApp({super.key});

  @override
  State<WariCanApp> createState() => _WariCanAppState();
}

class _WariCanAppState extends State<WariCanApp> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  /// ユーザーが保存したテーマ設定（ライト/ダーク）を読み込む
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    setState(() => _isDark = isDark);
  }

  /// ダークモードのオンオフを切り替え、設定を永続化する
  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final newMode = !_isDark;
    await prefs.setBool('isDark', newMode);
    setState(() => _isDark = newMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '割り勘アプリ wari_can',
      // OSの設定ではなく、アプリ内の状態（_isDark）でテーマを決定
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,

      // ライトテーマ設定
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        textTheme: GoogleFonts.notoSansJpTextTheme(), // 日本語に最適なNoto Sansを適用
      ),

      // ダークテーマ設定
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.notoSansJpTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),

      // 名前付きルートの設定（外部URLや通知からの遷移を想定）
      routes: {
        '/eventDetail': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          final eventId = args['eventId'] as String;

          // 詳細画面へ直接遷移する場合、Firestoreから最新データをフェッチして渡す
          return FutureBuilder<Event>(
            future: FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .get()
                .then((doc) => Event.fromJson(doc.data()!)),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Scaffold(
                  body: Center(child: Text("イベントの読み込みに失敗しました")),
                );
              }
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

      // アプリ起動時の初期画面（認証状態に応じた切り替えをHomeWrapperに委譲）
      home: HomeWrapper(isDark: _isDark, onToggleTheme: _toggleTheme),
    );
  }
}
