import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:wari_can/models/expense.dart';
import 'package:wari_can/models/menber.dart';
import 'package:wari_can/utils/utils.dart';

/// 支出明細の入力ダイアログ。
///
/// 新規追加または既存明細の編集に使用されます。
/// 負担額を均等割または手動で入力できます。
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
  // --- コントローラ・状態変数 ---
  final _itemController = TextEditingController();
  final _totalController = TextEditingController(text: "0");
  final _payDateController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _excludedMemberIds = {};

  /// 選択された支払者のID
  String? _payerId;

  /// 分割モード（"equal" または "manual"）
  SplitMode _mode = SplitMode.manual;

  /// 各コントローラに対応する FocusNode（全選択機能用）
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();

    // 1. 初期データのセット（編集時は既存値、新規時はデフォルト値）
    final edit = widget.editExpense;
    _itemController.text = edit?.item ?? "";
    _totalController.text = edit?.amount.toString() ?? "0";
    _payDateController.text = edit?.payDate ?? "";
    _mode = edit?.mode ?? SplitMode.manual;
    _payerId = edit?.payer;

    final amount = edit?.amount ?? 0;
    final participants = edit?.participants ?? const [];
    final participantCount = participants.length;

    // 2. メンバーごとの負担額入力フィールドとFocusNodeの初期化
    for (final m in widget.members) {
      final share = edit?.shares[m.id];

      // 均等割りモードで保存されたデータにおいて、金額が0（またはnull）の場合は除外リストに入れる
      if (edit != null && _mode == SplitMode.equal) {
        if (share == null || share == 0) {
          _excludedMemberIds.add(m.id);
        }
      }

      final isParticipant = participants.contains(m.id);

      // 初期金額の計算（既存データがあれば優先、なければ均等割の暫定値をセット）
      final value =
          share ??
          (isParticipant && participantCount > 0
              ? amount ~/ participantCount
              : 0);

      _controllers[m.id] = TextEditingController(text: value.toString());

      // FocusNodeの設定：フォーカスが当たった時にテキストを全選択する
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          _selectAllText(m.id);
        }
      });
      _focusNodes[m.id] = node;
    }

    // 均等割モードの場合、初期表示直後に計算を適用
    if (_mode == SplitMode.equal) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyEqualSplit());
    }

    // リアルタイムバリデーションのためにリスナーを登録
    _itemController.addListener(() => setState(() {}));
    _totalController.addListener(() => setState(() {}));
    _payDateController.addListener(() => setState(() {}));
  }

  /// テキスト全選択処理
  void _selectAllText(String memberId) {
    final controller = _controllers[memberId];
    if (controller != null && controller.text.isNotEmpty) {
      Future.microtask(() {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      });
    }
  }

  @override
  void dispose() {
    // メモリリーク防止のため全リソースを解放
    _itemController.dispose();
    _totalController.dispose();
    _payDateController.dispose();
    for (var c in _controllers.values) {
      c.dispose();
    }
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// 入力された総額（パース済み）
  int get total => int.tryParse(_totalController.text) ?? 0;

  /// 各メンバーの負担額の合計（subtotal）
  int get subtotal => _controllers.values
      .map((c) => int.tryParse(c.text) ?? 0)
      .fold(0, (a, b) => a + b);

  /// 均等割の計算と適用
  /// 割り切れない端数はリストの先頭メンバーから順に1円ずつ配分して調整
  void _applyEqualSplit() {
    // 参加しているメンバー（除外リストに入っていない人）だけを抽出
    final participants = widget.members
        .where((m) => !_excludedMemberIds.contains(m.id))
        .toList();

    if (participants.isEmpty) return;

    // 参加人数で割る
    final per = (total / participants.length).floor();
    final remainder = total - per * participants.length;

    setState(() {
      for (int i = 0; i < widget.members.length; i++) {
        final m = widget.members[i];

        if (_excludedMemberIds.contains(m.id)) {
          // 除外されている人は一律0円
          _controllers[m.id]!.text = "0";
        } else {
          // 参加者の中でのインデックスを取得して端数調整
          final pIndex = participants.indexOf(m);
          _controllers[m.id]!.text = (pIndex < remainder ? per + 1 : per)
              .toString();
        }
      }
    });
  }

  /// 手動入力モード時、負担額の変化を総額に連動させる
  void _updateTotalFromManualInput() {
    if (_mode == SplitMode.manual) {
      int sum = 0;
      for (final m in widget.members) {
        final value = int.tryParse(_controllers[m.id]!.text) ?? 0;
        sum += value;
      }
      _totalController.text = sum.toString();
    }
    setState(() {});
  }

  /// 保存可否判定（バリデーション）
  bool _canSave() {
    if (subtotal != total) return false; // 合計不一致
    if (_payerId == null || _payerId!.isEmpty) return false; // 支払者未選択
    if (_itemController.text.trim().isEmpty) return false; // 項目名未入力
    final totalValue = int.tryParse(_totalController.text) ?? 0;
    if (totalValue <= 0) return false; // 0円以下
    return true;
  }

  /// 保存実行
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

  /// 文字列の計算式を評価して数値に変換する
  void _calculateField(
    TextEditingController controller, {
    bool isTotal = false,
  }) {
    try {
      // 全角の「＋」などを半角に置換（日本のユーザー向け）
      String input = controller.text
          .replaceAll('＋', '+')
          .replaceAll('－', '-')
          .replaceAll('×', '*')
          .replaceAll('÷', '/');

      ShuntingYardParser p = ShuntingYardParser();
      Expression exp = p.parse(input);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);

      setState(() {
        // 小数点以下を切り捨てて整数に
        controller.text = eval.toInt().toString();

        // 合計金額を計算した場合は各個人に反映、個人の場合は総額に反映
        if (isTotal) {
          if (_mode == SplitMode.equal) _applyEqualSplit();
        } else {
          if (_mode == SplitMode.manual) _updateTotalFromManualInput();
        }
      });
    } catch (e) {
      // 計算できない形式（文字が含まれるなど）の場合は何もしない、または通知
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("計算式が正しくありません")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final diff = subtotal - total;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- タイトルエリア ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "支出明細の入力",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),

          // --- メイン入力エリア ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  TextField(
                    controller: _itemController,
                    decoration: const InputDecoration(labelText: "項目名"),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _totalController,
                    decoration: InputDecoration(
                      labelText: "合計金額",
                      // --- 追加: 計算ボタン ---
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calculate),
                        onPressed: () =>
                            _calculateField(_totalController, isTotal: true),
                      ),
                    ),
                    keyboardType: TextInputType.text, // 数式を打てるようtextに変更
                    onChanged: (_) {
                      if (_mode == SplitMode.equal) _applyEqualSplit();
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _payerId,
                    items: widget.members
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.name),
                          ),
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
                  const SizedBox(height: 16),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "負担額",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  // 各メンバーの負担額入力
                  ...widget.members.map((m) {
                    final isExcluded = _excludedMemberIds.contains(m.id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          // 均等割りモードのときだけチェックボックスを表示
                          if (_mode == SplitMode.equal)
                            Checkbox(
                              value: !isExcluded,
                              onChanged: (bool? checked) {
                                // 【修正】
                                // 現在チェックが入っている人数を計算
                                final participantCount = widget.members
                                    .where(
                                      (m) => !_excludedMemberIds.contains(m.id),
                                    )
                                    .length;

                                // もし最後の1人で、かつチェックを外そうとした（checked == false）場合は何もしない
                                if (participantCount <= 1 && checked == false) {
                                  return;
                                }

                                setState(() {
                                  if (checked == true) {
                                    _excludedMemberIds.remove(m.id);
                                  } else {
                                    _excludedMemberIds.add(m.id);
                                  }
                                  _applyEqualSplit();
                                });
                              },
                            ),
                          Expanded(
                            child: TextField(
                              controller: _controllers[m.id],
                              focusNode: _focusNodes[m.id],
                              decoration: InputDecoration(
                                labelText: m.name,
                                prefixText: "¥ ",
                                filled: _mode == SplitMode.equal,
                                fillColor: isExcluded
                                    ? Colors.grey.withOpacity(0.1)
                                    : null,
                                // --- 追加: 手動モードの時だけ計算ボタンを表示 ---
                                suffixIcon: _mode == SplitMode.manual
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.calculate,
                                          size: 20,
                                        ),
                                        onPressed: () => _calculateField(
                                          _controllers[m.id]!,
                                        ),
                                      )
                                    : null,
                              ),
                              keyboardType: TextInputType.visiblePassword,
                              // 1. 手動モードなら常に true (編集可能)
                              // 2. 均等モードなら常に false (編集不可)
                              enabled: _mode == SplitMode.manual,
                              style: TextStyle(
                                // 均等割りで除外されている時だけ文字をグレーにする
                                color: (_mode == SplitMode.equal && isExcluded)
                                    ? Colors.grey
                                    : null,
                              ),
                              onChanged: (_) {
                                if (_mode == SplitMode.manual) {
                                  _updateTotalFromManualInput();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // --- 操作・計算結果エリア ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("均等"),
                          selected: _mode == SplitMode.equal,
                          onSelected: (_) {
                            setState(() => _mode = SplitMode.equal);
                            _applyEqualSplit();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("手動"),
                          selected: _mode == SplitMode.manual,
                          onSelected: (_) =>
                              setState(() => _mode = SplitMode.manual),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "合計: ${Utils.formatAmount(subtotal)} / 総額: ${Utils.formatAmount(total)}",
                          ),
                          Text(
                            "過不足: ${Utils.formatAmount(diff)}",
                            style: TextStyle(
                              color: diff == 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
