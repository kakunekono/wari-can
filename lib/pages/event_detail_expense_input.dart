import 'package:flutter/material.dart';
import 'package:wari_can/models/event.dart';
import 'package:wari_can/utils/utils.dart';

/// 支出明細の入力ダイアログ。
///
/// 新規追加または既存明細の編集に使用されます。
/// メンバーごとの負担額を均等割または手動で入力できます。
/// 保存時に Map を返し、外部でローカル保存や Firebase 連携を行う設計です。
class ExpenseInputDialog extends StatefulWidget {
  /// メンバー一覧
  final List<Member> members;

  /// 編集対象の支出明細（新規の場合は null）
  final Expense? editExpense;

  const ExpenseInputDialog({
    super.key,
    required this.members,
    this.editExpense,
  });

  @override
  State<ExpenseInputDialog> createState() => _ExpenseInputDialogState();
}

class _ExpenseInputDialogState extends State<ExpenseInputDialog> {
  final _itemController = TextEditingController();
  final _totalController = TextEditingController(text: "0");
  final _payDateController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};

  /// 選択された支払者のID
  String? _payerId;

  /// 分割モード（"equal" または "manual"）
  String _mode = "manual";

  @override
  void initState() {
    super.initState();

    final edit = widget.editExpense;
    _itemController.text = edit?.item ?? "";
    _totalController.text = edit?.amount.toString() ?? "0";
    _payDateController.text = edit?.payDate ?? "";
    _mode = edit?.mode ?? "manual";
    _payerId = edit?.payer;

    final amount = edit?.amount ?? 0;
    final participants = edit?.participants ?? const [];
    final participantCount = participants.length;

    for (final m in widget.members) {
      final share = edit?.shares[m.id];
      final isParticipant = participants.contains(m.id);
      final value =
          share ??
          (isParticipant && participantCount > 0
              ? amount ~/ participantCount
              : 0);
      _controllers[m.id] = TextEditingController(text: value.toString());
    }

    if (_mode == "equal") {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyEqualSplit());
    }
    _itemController.addListener(() => setState(() {}));
    _totalController.addListener(() => setState(() {}));
    _payDateController.addListener(() => setState(() {}));
  }

  /// 合計金額を取得します。
  int get total => int.tryParse(_totalController.text) ?? 0;

  /// 各メンバーの負担額合計（subtotal）を取得します。
  int get subtotal => _controllers.values
      .map((c) => int.tryParse(c.text) ?? 0)
      .fold(0, (a, b) => a + b);

  /// 均等割を適用し、端数は先頭に加算します。
  void _applyEqualSplit() {
    if (widget.members.isEmpty) return;
    final per = (total / widget.members.length).floor();
    final remainder = total - per * widget.members.length;
    setState(() {
      for (int i = 0; i < widget.members.length; i++) {
        final m = widget.members[i];
        _controllers[m.id]!.text = (i < remainder ? per + 1 : per).toString();
      }
    });
  }

  /// 手動入力された負担額の合計を計算し、総額欄に反映します。
  void _updateTotalFromManualInput() {
    if (_mode == "manual") {
      int sum = 0;
      for (final m in widget.members) {
        final value = int.tryParse(_controllers[m.id]!.text) ?? 0;
        sum += value;
      }
      _totalController.text = sum.toString();
    }
    setState(() {});
  }

  /// 保存可能かどうかを判定します。
  bool _canSave() {
    if (subtotal != total) return false;
    if (_payerId == null || _payerId!.isEmpty) return false;
    if (_itemController.text.trim().isEmpty) return false;
    final totalValue = int.tryParse(_totalController.text) ?? 0;
    if (totalValue <= 0) return false;
    return true;
  }

  /// 保存処理を実行し、結果を返します。
  void _handleSave() {
    Navigator.pop(context, {
      'item': _itemController.text.trim(),
      'total': int.tryParse(_totalController.text) ?? 0,
      'payerId': _payerId,
      'payDate': _payDateController.text.trim(),
      'mode': _mode,
      'shares': _controllers.map(
        (id, c) => MapEntry(id, int.tryParse(c.text) ?? 0),
      ),
    });
  }

  @override
  Widget build(BuildContext context) {
    final diff = subtotal - total;

    return AlertDialog(
      title: const Text("支出明細の入力"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _itemController,
              decoration: const InputDecoration(labelText: "項目名"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _totalController,
              decoration: const InputDecoration(labelText: "合計金額"),
              keyboardType: TextInputType.number,
              onChanged: (_) {
                if (_mode == "equal") _applyEqualSplit();
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _payerId,
              items: widget.members
                  .map(
                    (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _payerId = value),
              decoration: const InputDecoration(labelText: "支払者"),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _payDateController,
              readOnly: true,
              decoration: const InputDecoration(labelText: "支払日（任意）"),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  _payDateController.text =
                      "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                }
              },
            ),
            const SizedBox(height: 8),
            const Divider(),
            const Text("各メンバーの負担額"),
            ...widget.members.map((m) {
              return TextField(
                controller: _controllers[m.id],
                decoration: InputDecoration(labelText: m.name),
                keyboardType: TextInputType.number,
                onChanged: (_) => _updateTotalFromManualInput(),
              );
            }),
          ],
        ),
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text("均等"),
                  selected: _mode == "equal",
                  onSelected: (_) {
                    setState(() => _mode = "equal");
                    _applyEqualSplit();
                  },
                ),
                ChoiceChip(
                  label: const Text("手動"),
                  selected: _mode == "manual",
                  onSelected: (_) => setState(() => _mode = "manual"),
                ),
                TextButton(
                  onPressed: _updateTotalFromManualInput,
                  child: const Text("合計金額更新"),
                ),
              ],
            ),
            Text(
              "合計: ${Utils.formatAmount(subtotal)}円 / 総額: ${Utils.formatAmount(total)}円 / 過不足: ${Utils.formatAmount(diff)}円",
              style: TextStyle(
                color: diff == 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("キャンセル"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _canSave() ? _handleSave : null,
                  child: const Text("保存"),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
