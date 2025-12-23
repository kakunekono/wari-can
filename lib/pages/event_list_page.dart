import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wari_can/pages/login_choice_page.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
import 'package:wari_can/widgets/footer.dart';
import '../models/event.dart';
import '../utils/utils.dart';
import '../logic/event_list_logic.dart';
import 'dart:html' as html;

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

  /// スクロールコントローラー。
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeOnce(); // 初期化時に一度だけ実行
    _loadEvents().then((_) {
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

    await handleInviteLink(context);

    final reloaded = await reloadEventsFromFirestore(context);

    setState(() => _events = reloaded);
    _initialized = true;
  }

  bool _inviteHandled = false;
  Future<void> handleInviteLink(BuildContext context) async {
    if (_inviteHandled) return;
    _inviteHandled = true;

    final uri = Uri.base;
    final eventId = uri.queryParameters['eventId'];
    final token = uri.queryParameters['token'] ?? "";

    if (eventId != null && eventId.isNotEmpty) {
      // 1. リンクの妥当性確認
      final isValid = await validateInviteLink(eventId, token);
      if (!isValid) {
        if (!mounted) return;
        showAppSnackBar(context, message: "リンクが無効です", type: SnackBarType.error);
        return;
      }

      // 2. ユーザー登録
      await registerSharedUser(eventId);

      // 3. ★ 遷移のために Firestore から Event オブジェクトを取得する
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();

      if (!eventDoc.exists) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          message: "イベントが見つかりませんでした",
          type: SnackBarType.error,
        );
        return;
      }

      // URLをクリーンにする
      html.window.history.replaceState(null, 'トップ', '/');

      if (mounted) {
        showAppSnackBar(
          context,
          message: "イベントに参加しました",
          type: SnackBarType.info,
        );
      }
    }
  }

  Future<bool> validateInviteLink(String eventId, String token) async {
    try {
      // 1. コレクション・ドキュメントの参照を作成
      final docRef = FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('inviteLink')
          .doc('current');

      debugPrint('--- Debug: Fetching doc for eventId: $eventId ---');

      // 2. ドキュメントの取得
      final doc = await docRef.get();

      // 3. ドキュメントの存在確認
      if (!doc.exists) {
        debugPrint(
          'Error: Document "current" does not exist for event: $eventId',
        );
        return false;
      }

      // 4. データの取り出し
      final data = doc.data();
      if (data == null) {
        debugPrint('Error: Document data is null');
        return false;
      }

      // 5. トークンの比較
      final dbToken = data['token'] as String?;
      debugPrint('Debug: DB Token = $dbToken, Input Token = $token');

      if (dbToken == null) {
        debugPrint('Error: Token field is missing in Firestore');
        return false;
      }

      return dbToken == token;
    } catch (e) {
      // 6. エラー（権限不足やネットワークエラーなど）の捕捉
      debugPrint('Exception caught: $e');
      return false;
    }
  }

  /// 共有ユーザのIDをイベントに追加
  Future<void> registerSharedUser(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint("Registering shared user for eventId: $eventId");
    if (user == null) return; // 未ログインなら何もしない
    debugPrint("user:${user.uid}");
    await FirebaseFirestore.instance.collection('events').doc(eventId).update({
      'sharedWith': FieldValue.arrayUnion([user.uid]),
    });
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
            tooltip: 'ローカルクリア',
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "btnScrollToTop",
            mini: true,
            onPressed: () {
              _scrollController.animateTo(
                0, // 一番上まで
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
              );
            },
            child: const Icon(Icons.arrow_upward),
          ),
          const SizedBox(height: 10), // ボタン間の余白
          FloatingActionButton(
            heroTag: "btnScrollToBottom",
            mini: true,
            onPressed: () {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent, // 一番下まで
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
              );
            },
            child: const Icon(Icons.arrow_downward),
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
                    final newEvent = await _logic.addEventWithName(
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
                    controller: _scrollController,
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
                                  onDeleted: () async {
                                    setState(() {});
                                    showAppSnackBar(
                                      context,
                                      message: 'イベント「${e.name}」を削除しました',
                                      type: SnackBarType.info,
                                    );
                                    await _loadEvents();
                                  },
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
                                      'メンバー: ${e.members.length}人',
                                      '明細件数： ${e.details.length}件',
                                      '合計金額： ${Utils.formatAmount(e.details.fold(0, (sum, e) => sum + e.amount))}円',
                                    ].join("\n"),
                                  ),
                                  onTap: () async {
                                    await _logic.openEventDetail(context, e);
                                    await _loadEvents();
                                  },
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
