import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wari_can/logic/lock_manager.dart';
import 'package:wari_can/utils/firestore_helper.dart';
import 'package:wari_can/widgets/footer.dart';
import '../models/event.dart';
import '../utils/event_json_utils.dart';
import '../utils/utils.dart';
import '../logic/event_detail_logic.dart';
import 'event_detail_member.dart';
import '../logic/event_detail_expense.dart';

/// イベントの詳細ページ。
///
/// メンバーの追加・編集・削除、支出明細の登録・編集・削除、
/// 精算結果の表示、イベントの共有などを行う画面です。
/// 編集はローカルで完結し、保存時にのみ Firebase へ同期されます。
class EventDetailPage extends StatefulWidget {
  /// 表示対象のイベント
  final Event event;

  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

/// イベント詳細ページのステート。
class _EventDetailPageState extends State<EventDetailPage> {
  /// 編集対象のイベントデータ
  late Event _event;

  /// メンバー追加用のテキストコントローラ
  final TextEditingController _memberController = TextEditingController();

  /// 共有中ユーザーの UID → 表示名 のマップ
  Map<String, String> _sharedNames = {};

  /// スクロールコントローラ
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadSharedNames();
    _acquireLockOnEnter();
  }

  @override
  void dispose() {
    _memberController.dispose();
    _scrollController.dispose();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      LockManager.releaseLock(widget.event.id, uid);
    }
    super.dispose();
  }

  /// イベントの状態を更新し、setStateと保存を行う。
  void _updateEvent(Event updated) async {
    setState(() => _event = updated);
    await saveEventFlexible(context, _event, target: SaveTarget.localOnly);
  }

  Future<void> _acquireLockOnEnter() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await LockManager.acquireLock(widget.event.id, uid);
      debugPrint("ロック取得成功: ${widget.event.id}");
    } catch (e) {
      debugPrint("ロック取得失敗: $e");
      // ✅ 他人がロック中ならエラー表示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("他のユーザーが編集中です")));
      // 追加のみ可能にするUI制御をここで入れる
    }
  }

  /// 共有中ユーザーの表示名を取得して _sharedNames に格納する。
  Future<void> _loadSharedNames() async {
    final ids = _event.sharedWith.where(
      (id) => id != FirebaseAuth.instance.currentUser?.uid,
    );
    final Map<String, String> names = {};
    for (final id in ids) {
      names[id] = await fetchUserName(id);
    }
    setState(() => _sharedNames = names);
  }

  /// 戻るときに保存確認を行う。
  Future<bool> _confirmSaveBeforePop() async {
    final confirmed = await onWillPopConfirmSave(context, _event);
    return confirmed;
  }

  /// イベント共有リンクを表示するセクション（Web限定）
  Widget buildShareSection(Event event, BuildContext context) {
    if (!kIsWeb) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('この機能はWeb版でのみ利用可能です。', style: TextStyle(color: Colors.red)),
      );
    }

    final inviteUrl = Utils.generateInviteUrl(event.id);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'イベント共有リンク',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SelectableText(inviteUrl),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('リンクをコピー'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteUrl));
                    Navigator.pop(context, 'copied');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedDetails = List<Expense>.from(_event.details);
    final settlements = calcSettlement(sortedDetails, _event.members);
    final balances = calcTotals(sortedDetails, _event.members);
    final paidTotals = calcPaidTotals(sortedDetails, _event.members);
    final memberShareTotals = memberShareTotalsFunc(sortedDetails);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<bool>(
      future: LockManager.hasValidLock(_event.id, currentUserId!), // 非同期処理
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Text("エラーが発生しました");
        }

        final isLockedByMe = snapshot.data ?? false;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final confirmed = await _confirmSaveBeforePop();
            if (confirmed) Navigator.pop(context);
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(_event.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.link),
                  tooltip: 'イベントを共有',
                  onPressed: () async {
                    final result = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('イベント共有'),
                        content: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 400,
                            maxHeight: 300,
                          ),
                          child: SingleChildScrollView(
                            child: buildShareSection(_event, context),
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: const Text('閉じる'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                    if (result == 'copied') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('招待リンクをコピーしました')),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'テキストで共有',
                  onPressed: () async {
                    final text = buildShareText(_event);
                    await Share.share(text);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.code),
                  tooltip: 'JSONエクスポート',
                  onPressed: () {
                    EventJsonUtils.exportEventJson(context, _event);
                  },
                ),
              ],
            ),
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "btnAddExpense",
                  mini: true,
                  onPressed: () =>
                      addExpense(context, _event, onUpdate: _updateEvent),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10), // ボタン間の余白
                FloatingActionButton(
                  heroTag: "btnScrollToTop",
                  mini: true,
                  onPressed: () {
                    _scrollController.animateTo(
                      0,
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
            body: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ ロック情報を表示
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('locks')
                        .doc(widget.event.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return TextButton(
                          onPressed: () async {
                            // ここでロックを新規作成する処理を呼ぶ
                            try {
                              await LockManager.acquireLock(
                                _event.id,
                                FirebaseAuth.instance.currentUser!.uid,
                              );
                              setState(() {}); // 状態を更新して再描画
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("ロック取得失敗: $e")),
                              );
                            }
                          },
                          child: const Text('ロックを取得する'),
                        );
                      }
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>;
                      final lockedBy = data['lockedBy'] as String?;
                      final expiresAt = (data['expiresAt'] as Timestamp)
                          .toDate();

                      return FutureBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(lockedBy)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text('ユーザー情報取得中...');
                          }
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const Text('不明なユーザー');
                          }

                          final data = snapshot.data!.data();
                          final userName = data?['name'] ?? lockedBy;

                          // 現在のユーザーIDを取得
                          final currentUserId =
                              FirebaseAuth.instance.currentUser?.uid;

                          // 自分がロック保持者ならテキストを出さない
                          if (lockedBy == currentUserId) {
                            return const SizedBox.shrink(); // 空のウィジェットを返す
                          }

                          return Text(
                            '編集中: $userName (有効期限: ${expiresAt.toLocal()})',
                            style: const TextStyle(color: Colors.red),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _event.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('イベントID: ${_event.id}'),
                  const SizedBox(height: 8),
                  Text('メンバー数: ${_event.members.length}人'),
                  Text('支出件数: ${_event.details.length}件'),
                  const SizedBox(height: 8),

                  if (_event.sharedWith.length > 1)
                    ExpansionTile(
                      title: const Text(
                        '共有中のユーザー',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      children: _sharedNames.entries.map((entry) {
                        final id = entry.key;
                        final name = entry.value;
                        return Card(
                          child: ListTile(
                            title: Text(name),
                            subtitle: Text(id),
                            trailing: (_event.ownerUid == currentUserId)
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text("共有解除の確認"),
                                          content: Text(
                                            "このユーザー（$name）との共有を解除しますか？この変更は即反映されます。",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text("キャンセル"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text("解除する"),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        setState(() {
                                          _event.sharedWith.remove(id);
                                          _sharedNames.remove(id);
                                        });
                                        try {
                                          await saveEventFlexible(
                                            context,
                                            _event,
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text("保存しました"),
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text("保存失敗: $e")),
                                          );
                                        }
                                      }
                                    },
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),

                  const Divider(height: 32),

                  ExpansionTile(
                    title: const Text('👥 メンバー一覧'),
                    initiallyExpanded: true,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    collapsedBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.surface,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: buildMemberSection(
                          context,
                          _event,
                          _memberController,
                          onUpdate: _updateEvent,
                          isLockedByMe: true,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),

                  ExpansionTile(
                    title: const Text('💰 支出明細'),
                    initiallyExpanded: true,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    collapsedBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.surface,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: buildExpenseSection(
                          context,
                          _event,
                          onUpdate: _updateEvent,
                          isLockedByMe: true,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),

                  ExpansionTile(
                    title: const Text('💳 各メンバーの支払合計金額'),
                    initiallyExpanded: true,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    collapsedBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.surface,
                    children: paidTotals.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "${Utils.memberName(e.key, _event.members)}: ${Utils.formatAmount(e.value)}円",
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(),

                  ExpansionTile(
                    title: const Text('💸 各メンバーの負担合計金額'),
                    initiallyExpanded: true,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    collapsedBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.surface,
                    children: memberShareTotals.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "${Utils.memberName(e.key, _event.members)}: ${Utils.formatAmount(e.value)}円",
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(),

                  ExpansionTile(
                    title: const Text('📊 メンバーごとの精算差額'),
                    initiallyExpanded: true,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    collapsedBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.surface,
                    children: balances.entries.map((e) {
                      final color = e.value > 0
                          ? Colors.green
                          : (e.value < 0
                                ? Colors.red
                                : Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color);
                      final sign = e.value >= 0 ? '+' : '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "${Utils.memberName(e.key, _event.members)}: $sign${Utils.formatAmount(e.value)}円",
                            style: TextStyle(color: color),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(),

                  ExpansionTile(
                    title: const Text('📈 精算結果'),
                    initiallyExpanded: true,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    collapsedBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.surface,
                    children: settlements.map((s) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(s),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_back),
                        label: const Text("保存して戻る"),
                        onPressed: () async {
                          final allowPop = await _confirmSaveBeforePop();
                          if (allowPop) Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 16), // ボタン間の余白
                      ElevatedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text("保存しないで戻る"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey, // 区別しやすく色を変更
                        ),
                        onPressed: () {
                          Navigator.pop(context); // 保存せずに戻る
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            bottomNavigationBar: const LoginInfoFooter(),
          ),
        );
      },
    );
  }
}
