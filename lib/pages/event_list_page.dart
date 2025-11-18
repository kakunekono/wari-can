import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wari_can/pages/login_choice_page.dart';
import 'package:wari_can/utils/firestore_helper.dart';
import 'package:wari_can/widgets/footer.dart';
import '../models/event.dart';
import '../utils/utils.dart';
import '../logic/event_list_logic.dart';

/// イベント一覧ページ。
///
/// ローカルに保存されたイベントを一覧表示し、追加・削除・インポート・クラウド同期などの操作を提供します。
/// 編集はローカルで完結し、保存時にのみ Firebase へ同期されます。
class EventListPage extends StatefulWidget {
  /// テーマ切り替えコールバック。
  final VoidCallback onToggleTheme;

  /// 現在のテーマがダークかどうか。
  final bool isDark;

  const EventListPage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  final _controller = TextEditingController();
  final _logic = EventListLogic();
  List<Event> _events = [];
  bool _initialized = false;

  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initializeOnce(); // ← 初期化時に一度だけ実行
    _loadEvents().then((_) {
      // ログイン状態を通知（Web共有リンク用）
      final user = FirebaseAuth.instance.currentUser;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final message = user != null ? "ログイン成功 ✅ UID: ${user.uid}" : "ログイン失敗 ❌";
        final color = user != null ? Colors.green : Colors.red;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: color),
        );
      });
      setState(() {
        _isReady = true;
      });
    });
  }

  /// ローカルイベントを読み込んで表示する。
  Future<void> _loadEvents() async {
    final loaded = await _logic.loadEvents();
    setState(() => _events = loaded);
  }

  /// Firestoreからイベント一覧を取得し、ローカルストレージを再構成する。
  ///
  /// 既存の SharedPreferences 上のイベントデータはすべて削除され、
  /// Firestore 上の最新データで上書きされます。
  Future<List<Event>> reloadEventsFromFirestore(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // 🔸 ローカルイベントキーをすべて削除
    final keys = prefs.getKeys().where((k) => k.startsWith('event_')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }

    debugPrint("[EventListPage] Cleared ${keys.length} local events.");

    // 🔸 Firestoreからイベント一覧を取得
    final events = await fetchAllEventsFromFirestore(); // ← FirestoreHelper側で定義

    debugPrint(
      "[EventListPage] Fetched ${events.length} events from Firestore.",
    );

    // 🔸 ローカルに保存し直す
    for (final e in events) {
      await prefs.setString('event_${e.id}', e.toJson().toString());
    }

    debugPrint("[EventListPage] Re-saved events to local storage.");

    // 🔸 UIに反映するために返す
    return events;
  }

  void _initializeOnce() async {
    if (_initialized) return;
    _initialized = true;

    final reloaded = await reloadEventsFromFirestore(context);
    setState(() => _events = reloaded);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return const SizedBox.shrink(); // 初期化完了まで描画しない
    return Scaffold(
      appBar: AppBar(
        title: const Text('イベント一覧'),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDark ? Icons.light_mode : Icons.dark_mode_outlined,
            ),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'クラウドへ一括アップロード',
            onPressed: () => _logic.uploadAllEvents(context),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'JSON取込',
            onPressed: () async {
              final newEvent = await _logic.importEventJson(context);
              if (newEvent != null) {
                await _loadEvents();
                await _logic.openEventDetail(context, newEvent);
                await _loadEvents();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'すべて削除',
            onPressed: () async {
              final cleared = await _logic.confirmDeleteAll(context);
              if (cleared) setState(() => _events.clear());
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("ログアウトの確認"),
                  content: const Text("本当にログアウトしますか？"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("キャンセル"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("ログアウトする"),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await FirebaseAuth.instance.signOut();

                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginChoicePage(
                        onToggleTheme: widget.onToggleTheme,
                        isDark: widget.isDark,
                      ),
                    ),
                    (route) => false, // すべての前の画面を削除
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'イベント名を入力',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final newEvent = await _logic.addEvent(
                      context,
                      _controller.text,
                    );
                    if (newEvent != null) {
                      _controller.clear();
                      await _loadEvents();
                      await _logic.openEventDetail(context, newEvent);
                      await _loadEvents();
                    }
                  },
                  child: const Text('追加'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _events.isEmpty
                ? const Center(child: Text('登録されたイベントはありません'))
                : ListView.builder(
                    itemCount: _events.length,
                    itemBuilder: (context, i) {
                      final e = _events[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 600;
                            final actionButtons = _logic
                                .buildEventActionButtons(
                                  context,
                                  e,
                                  onUpdated: _loadEvents,
                                  onDeleted: () =>
                                      setState(() => _events.removeAt(i)),
                                );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  title: Text(
                                    e.name,
                                    style: const TextStyle(
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      'イベントID： ${e.id}',
                                      'メンバー: ${e.members.map((m) => Utils.memberName(m.id, e.members)).join(",")}',
                                      '明細件数： ${e.details.length}件',
                                      '合計金額： ${Utils.formatAmount(e.details.fold(0, (sum, e) => sum + e.amount))}円',
                                    ].join("\n"),
                                  ),
                                  onTap: () =>
                                      _logic.openEventDetail(context, e),
                                  trailing: isWide
                                      ? Wrap(
                                          spacing: 8,
                                          children: actionButtons,
                                        )
                                      : null,
                                ),
                                if (!isWide)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: actionButtons,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const LoginInfoFooter(),
    );
  }
}
