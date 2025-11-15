import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event.dart';
import '../utils/utils.dart';
import '../logic/event_list_logic.dart';

/// イベント一覧ページ。
/// イベントの表示と、ユーザー操作に応じたロジック呼び出しを行う。
class EventListPage extends StatefulWidget {
  /// テーマ切り替えコールバック。
  final VoidCallback onToggleTheme;

  /// 現在のテーマがダークかどうか。
  final bool isDark;

  /// コンストラクタ。
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
  final _controller = TextEditingController();
  final _logic = EventListLogic();
  List<Event> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();

    // 🔹 ログインの結果を画面に通知
    final user = FirebaseAuth.instance.currentUser;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final message = user != null ? "ログイン成功 ✅ UID: ${user.uid}" : "ログイン失敗 ❌";
      final color = user != null ? Colors.green : Colors.red;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    });
  }

  /// ローカルイベントを読み込んで表示する。
  Future<void> _loadEvents() async {
    final loaded = await _logic.loadEvents();
    setState(() => _events = loaded);
  }

  @override
  Widget build(BuildContext context) {
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
              await FirebaseAuth.instance.signOut();
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
    );
  }
}
