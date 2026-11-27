import 'package:aral_project/Admin/Models/transaction_types.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

class TransactionTypeDropdown extends StatelessWidget {
  const TransactionTypeDropdown({
    super.key,
    required this.direction,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.label = 'Transaction type',
  });

  final String direction; // 'IN' or 'OUT'
  final String?
  value; // Arabic label (or legacy code/label normalized via typeByCode)
  final ValueChanged<String?>? onChanged;
  final bool enabled;
  final String label;

  String _resolveLabelValue(List<TransactionType> activeTypes) {
    final raw = (value ?? '').trim();
    if (raw.isNotEmpty) {
      // If an existing value is a code (e.g. 'sales_delivery' or 'reversal'), map to its Arabic label.
      final byCode = typeByCode(raw);
      if (byCode != null) return byCode.label;

      // If it already matches an active or retired Arabic label, keep it.
      for (final t in [...activeTypes, ...kRetiredTypes, kReversalType]) {
        if (t.label == raw) return t.label;
      }
    }
    return typeByCode(defaultTypeFor(direction))!.label;
  }

  @override
  Widget build(BuildContext context) {
    final activeTypes = typesFor(direction);
    final resolvedValue = _resolveLabelValue(activeTypes);
    final isReversalLabel = resolvedValue == kReversalType.label;

    final items = <TransactionType>[
      ...activeTypes,
      if (isReversalLabel) kReversalType,
      if (!isReversalLabel &&
          kRetiredTypes.any((t) => t.label == resolvedValue))
        kRetiredTypes.firstWhere((t) => t.label == resolvedValue),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textColorPrimary,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('tx-type-$direction'),
          value: resolvedValue,
          isExpanded: true,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Choose a type for $direction' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceColor,
            prefixIcon: const Icon(Icons.category_outlined),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppTheme.secondaryColor,
                width: 2,
              ),
            ),
          ),
          items: items
              .map(
                (t) => DropdownMenuItem<String>(
                  value: t.label,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(t.label, textDirection: TextDirection.rtl),
                  ),
                ),
              )
              .toList(),
          onChanged: (!enabled || isReversalLabel) ? null : onChanged,
        ),
      ],
    );
  }
}
