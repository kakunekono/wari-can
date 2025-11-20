import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wari_can/pages/login_choice_page.dart';
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

/// イベント一覧ページのステート。
class _EventListPageState extends State<EventListPage> {
  /// イベント名入力用のテキストコントローラー。
  final TextEditingController _controller = TextEditingController();

  /// イベント一覧ロジッククラス。
  final EventListLogic _logic = EventListLogic();

  /// 現在表示中のイベント一覧。
  List<Event> _events = [];

  /// 初期化処理がすでに実行されたかどうか。
  bool _initialized = false;

  /// 初期化完了フラグ（描画制御用）。
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initializeOnce(); // 初期化時に一度だけ実行
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
      setState(() => _isReady = true);
    });
  }

  /// ローカルイベントを読み込んで表示する。
  Future<void> _loadEvents() async {
    final loaded = await _logic.loadEventsAndUpdateLocalCache();
    setState(() => _events = loaded);
  }

  /// Firestoreからイベント一覧を取得し、ローカルストレージを再構成する。
  Future<List<Event>> reloadEventsFromFirestore(BuildContext context) async {
    final reloaded = await _logic.reloadEventsFromFirestoreAndResave();
    return reloaded;
  }

  /// 初期化処理を一度だけ実行する。
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
                    (route) => false,
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
