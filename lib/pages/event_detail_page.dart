import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event.dart';
import '../utils/event_json_utils.dart';
import '../utils/utils.dart';
import '../logic/event_detail_logic.dart';
import 'event_detail_member.dart';
import 'event_detail_expense.dart';

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

class _EventDetailPageState extends State<EventDetailPage> {
  /// 編集対象のイベントデータ
  late Event _event;

  /// メンバー追加用のテキストコントローラ
  final TextEditingController _memberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  @override
  void dispose() {
    _memberController.dispose();
    super.dispose();
  }

  /// イベントの状態を更新し、setStateと保存を行います。
  void _updateEvent(Event updated) async {
    setState(() {
      _event = updated;
    });
    await saveEvent(context, _event); // ローカル保存 + Firebase同期（必要なら）
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
        constraints: const BoxConstraints(
          maxWidth: 400, // 必要に応じて調整
        ),
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min, // ← これが重要！
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

  /// 戻るときに保存確認を行う
  Future<bool> _confirmSaveBeforePop() async {
    final confirmed = await onWillPopConfirmSave(context, _event);
    return confirmed;
  }

  SliverPersistentHeader _buildStickyHeader(String title) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyHeaderDelegate(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        maxWidth: 400, // 横幅制限（任意）
                        maxHeight: 300, // 高さ制限（必要に応じて調整）
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
        floatingActionButton: FloatingActionButton(
          onPressed: () => addExpense(context, _event, onUpdate: _updateEvent),
          child: const Icon(Icons.add),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'イベント名: ${_event.name}',
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
              const Divider(height: 32),

              ExpansionTile(
                title: const Text('👥 メンバー一覧'),
                initiallyExpanded: true,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: buildMemberSection(
                      context,
                      _event,
                      _memberController,
                      onUpdate: _updateEvent,
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
                collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: buildExpenseSection(
                      context,
                      _event,
                      onUpdate: _updateEvent,
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
                collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
                children: paidTotals.entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "${Utils.memberName(e.key, _event.members)}: ${Utils.formatAmount(e.value)}円",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const Divider(),

              ExpansionTile(
                title: const Text('💸 各メンバーの負担合計金額'),
                initiallyExpanded: true,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
                children: memberShareTotals.entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "${Utils.memberName(e.key, _event.members)}: ${Utils.formatAmount(e.value)}円",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const Divider(),

              ExpansionTile(
                title: const Text('📊 メンバーごとの精算差額'),
                initiallyExpanded: true,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
                children: balances.entries.map((e) {
                  final color = e.value > 0
                      ? Colors.green
                      : (e.value < 0
                            ? Colors.red
                            : Theme.of(context).textTheme.bodyMedium?.color);
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
                collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
                children: settlements
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(s),
                        ),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("戻る"),
                  onPressed: () async {
                    final allowPop = await _confirmSaveBeforePop();
                    if (allowPop) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyHeaderDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
