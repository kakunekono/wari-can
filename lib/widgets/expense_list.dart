import 'package:flutter/material.dart';
import '../models/expense_item.dart';

class ExpenseList extends StatelessWidget {
  final List<String> members;
  final List<ExpenseItem> details;
  final void Function(int) onEdit;
  final void Function(int) onDelete;

  const ExpenseList({
    super.key,
    required this.members,
    required this.details,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: members.map((member) {
        final paidDetails = details.where((d) => d.payer == member).toList();
        if (paidDetails.isEmpty) return const SizedBox.shrink();

        paidDetails.sort((a, b) {
          final itemCompare = a.item.compareTo(b.item);
          if (itemCompare != 0) return itemCompare;
          final aP = a.participants.isNotEmpty ? a.participants.first : '';
          final bP = b.participants.isNotEmpty ? b.participants.first : '';
          return aP.compareTo(bP);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(member, style: const TextStyle(fontWeight: FontWeight.bold)),
            ...paidDetails.map(
              (d) => Card(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: ListTile(
                  title: Text('${d.item} (${d.amount}円)'),
                  subtitle: Text('参加者: ${d.participants.join(', ')}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => onEdit(details.indexOf(d)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => onDelete(details.indexOf(d)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
          ],
        );
      }).toList(),
    );
  }
}
