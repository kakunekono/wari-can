import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wari_can/logic/lock_manager.dart';
import 'package:wari_can/utils/exception_utils.dart';
import 'package:wari_can/utils/firestore_helper.dart';
import 'package:wari_can/utils/snackbar_utils.dart';
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

  bool _isLockedByMe = false;

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

  /// イベント詳細ページに入ったときにロックを取得する。
  Future<void> _acquireLockOnEnter({bool force = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final acquired = await LockManager.acquireLock(
        widget.event.id,
        uid,
        ownerUid: widget.event.ownerUid,
        force: force,
      );
      if (!acquired) throw Exception('他ユーザーが編集中です');

      // 🔽 ロック成功後に最新イベントを取得
      final latest = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .get();

      if (latest.exists) {
        setState(() {
          _event = Event.fromJson(latest.data()!); // ← State 内の変数を更新
          _isLockedByMe = true;
        });
      }

      debugPrint("ロック取得成功: ${widget.event.id}");
    } on Exception catch (e) {
      final msg = ExceptionUtils.format(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  /// ロック取得前に確認ダイアログを表示し、ユーザーが承認したら true を返す
  Future<bool> confirmLockAcquisition(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ロックを取得しますか？'),
        content: const Text('最新の明細に更新され、入力中の内容は破棄される可能性があります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('取得する'),
          ),
        ],
      ),
    );
    return result ?? false;
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

        final currentUser = FirebaseAuth.instance.currentUser;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final confirmed = await _confirmSaveBeforePop();
            if (confirmed) Navigator.pop(context, true);
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(_event.name),
              actions: [
                // 自分がオーナーのときのみ共有リンク生成ボタンを表示
                if (_event.ownerUid == currentUser?.uid)
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
                        showAppSnackBar(
                          context,
                          message: '招待リンクをコピーしました',
                          type: SnackBarType.info,
                        );
                      }
                    },
                  ),

                // 他の共有機能は誰でも利用可能
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
                if (_isLockedByMe)
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
                      final currentUserId =
                          FirebaseAuth.instance.currentUser?.uid;

                      // ロック情報がない場合 → ボタンを出す
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return TextButton(
                          onPressed: () async {
                            final confirmed = await confirmLockAcquisition(
                              context,
                            );
                            if (confirmed) {
                              await _acquireLockOnEnter(force: true);
                            }
                          },
                          child: const Text('ロックを取得する'),
                        );
                      }

                      // ロック情報あり
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
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text('ユーザー情報取得中...');
                          }
                          if (!userSnapshot.hasData ||
                              !userSnapshot.data!.exists) {
                            return const Text('不明なユーザー');
                          }

                          final userData = userSnapshot.data!.data();
                          final userName = userData?['name'] ?? lockedBy;
                          final isLockedByMe = lockedBy == currentUserId;

                          // 他人がロック保持中 → 「編集中」テキストとボタンを両方出す
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '編集中: $userName (有効期限: ${expiresAt.toLocal()})',
                                style: TextStyle(
                                  color: isLockedByMe
                                      ? Colors.lightGreen
                                      : Colors.red,
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final confirmed =
                                      await confirmLockAcquisition(context);
                                  if (confirmed) {
                                    await _acquireLockOnEnter(force: true);
                                  }
                                },
                                child: Text(
                                  'ロックを${isLockedByMe ? '再' : ''}取得する',
                                ),
                              ),
                            ],
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_event.ownerUid ==
                                    id) // このユーザーがオーナーならラベルを表示
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: Chip(
                                      label: Text(
                                        "オーナー",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.blue,
                                    ),
                                  ),
                                if (_event.ownerUid ==
                                    currentUserId) // 現在のユーザーがオーナーなら削除ボタンを表示
                                  IconButton(
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
                                          showAppSnackBar(
                                            context,
                                            message: '保存しました',
                                            type: SnackBarType.info,
                                          );
                                        } on Exception catch (e) {
                                          showAppSnackBar(
                                            context,
                                            message:
                                                '保存に失敗しました: ${ExceptionUtils.format(e)}',
                                            type: SnackBarType.error,
                                          );
                                        }
                                      }
                                    },
                                  ),
                              ],
                            ),
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
                          isLockedByMe: _isLockedByMe,
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
                          isLockedByMe: _isLockedByMe,
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
                    children: _event.members.map((m) {
                      final amount = paidTotals[m.id] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "${m.name}: ${Utils.formatAmount(amount)}円",
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
                    children: _event.members.map((m) {
                      final amount = memberShareTotals[m.id] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "${m.name}: ${Utils.formatAmount(amount)}円",
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
                    children: _event.members.map((m) {
                      final value = balances[m.id] ?? 0;
                      final color = value > 0
                          ? Colors.green
                          : (value < 0
                                ? Colors.red
                                : Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color);
                      final sign = value >= 0 ? '+' : '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "${m.name}: $sign${Utils.formatAmount(value)}円",
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
                          if (allowPop) Navigator.pop(context, true);
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
                          Navigator.pop(context, true); // 保存せずに戻る
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
