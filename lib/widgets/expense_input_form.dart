import 'package:flutter/material.dart';

class ExpenseInputForm extends StatelessWidget {
  final TextEditingController itemController;
  final TextEditingController amountController;
  final String? selectedPayer;
  final Map<String, bool> selectedParticipants;
  final List<String> members;
  final void Function(String) onSelectPayer;
  final void Function(String, bool) onSelectParticipant;
  final VoidCallback onAddOrUpdate;
  final bool isEditing;

  const ExpenseInputForm({
    super.key,
    required this.itemController,
    required this.amountController,
    required this.selectedPayer,
    required this.selectedParticipants,
    required this.members,
    required this.onSelectPayer,
    required this.onSelectParticipant,
    required this.onAddOrUpdate,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('明細入力', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: itemController,
          decoration: const InputDecoration(labelText: '項目名'),
        ),
        TextField(
          controller: amountController,
          decoration: const InputDecoration(labelText: '金額'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        const Text('支払者を選択'),
        Wrap(
          spacing: 8,
          children: members
              .map(
                (m) => ChoiceChip(
                  label: Text(m),
                  selected: selectedPayer == m,
                  onSelected: (_) => onSelectPayer(m),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        const Text('参加者を選択'),
        Wrap(
          spacing: 8,
          children: members
              .map(
                (m) => FilterChip(
                  label: Text(m),
                  selected: selectedParticipants[m] ?? false,
                  onSelected: (val) => onSelectParticipant(m, val),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onAddOrUpdate,
          icon: const Icon(Icons.add),
          label: Text(isEditing ? '明細を更新' : '明細を追加'),
        ),
      ],
    );
  }
}
