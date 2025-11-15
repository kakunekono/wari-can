import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event.dart';
import '../utils/event_json_utils.dart';
import '../utils/utils.dart';
import 'event_detail_logic.dart';
import 'event_detail_member.dart';
import 'event_detail_expense.dart';

/// イベントの詳細ページ。
///
/// メンバーの追加・編集・削除、支出明細の登録・編集・削除、
/// 精算結果の表示、イベントの共有などを行う画面です。
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

  /// イベント詳細画面のUIを構築します。
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
        final confirmed = await onWillPopConfirmSave(context, _event);
        if (confirmed) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_event.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () async {
                final text = buildShareText(_event);
                await Share.share(text);
              },
            ),
            IconButton(
              icon: const Icon(Icons.code),
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
              Text('イベントID: ${_event.id}'),
              const SizedBox(height: 8),
              Text('メンバー数: ${_event.members.length}人'),
              Text('支出件数: ${_event.details.length}件'),
              const Divider(height: 32),

              buildMemberSection(
                context,
                _event,
                _memberController,
                onUpdate: _updateEvent,
              ),
              const Divider(),
              buildExpenseSection(context, _event, onUpdate: _updateEvent),
              const Divider(),

              const Text(
                '各メンバーの支払合計金額',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...paidTotals.entries.map(
                (e) => Text(
                  "${Utils.memberName(e.key, _event.members)}: ${Utils.formatAmount(e.value)}円",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const Divider(),

              const Text(
                '各メンバーの負担合計金額',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...memberShareTotals.entries.map(
                (e) => Text(
                  "${Utils.memberName(e.key, _event.members)}: ${Utils.formatAmount(e.value)}円",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const Divider(),

              const Text(
                'メンバーごとの支払合計精算金額',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...balances.entries.map((e) {
                final color = e.value > 0
                    ? Colors.green
                    : (e.value < 0
                          ? Colors.red
                          : Theme.of(context).textTheme.bodyMedium?.color);
                final sign = e.value >= 0 ? '+' : '';
                return Text(
                  "${Utils.memberName(e.key, _event.members)}: $sign${Utils.formatAmount(e.value)}円",
                  style: TextStyle(color: color),
                );
              }),
              const Divider(),

              const Text(
                '精算結果',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...settlements.map((s) => Text(s)),

              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("戻る"),
                  onPressed: () async {
                    final allowPop = await onWillPopConfirmSave(
                      context,
                      _event,
                    );
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

  /// イベントの状態を更新し、setStateと保存を行います。
  void _updateEvent(Event updated) async {
    setState(() {
      _event = updated;
    });
    await saveEvent(context, _event);
  }
}
