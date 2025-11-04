import 'package:flutter/material.dart';

class SettlementSummary extends StatelessWidget {
  final Map<String, double> paymentTotals;
  final List<String> settlementResults;

  const SettlementSummary({
    super.key,
    required this.paymentTotals,
    required this.settlementResults,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('各自の支払合計', style: TextStyle(fontWeight: FontWeight.bold)),
        ...paymentTotals.entries.map((e) => Text('${e.key} は合計 ${e.value.toInt()}円 支払')),
        const Divider(),
        const Text('精算結果', style: TextStyle(fontWeight: FontWeight.bold)),
        ...settlementResults.map((s) => Text(s)),
        const Divider(),
      ],
    );
  }
}
