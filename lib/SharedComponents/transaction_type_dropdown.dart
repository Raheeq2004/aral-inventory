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
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final activeTypes = typesFor(direction);
    final selectedInActive = activeTypes.any((t) => t.code == value);
    final resolvedValue = selectedInActive
        ? value
        : (value != null &&
                  (value == kReversalType.code || isRetiredType(value!))
              ? value
              : defaultTypeFor(direction));

    final items = <TransactionType>[
      ...activeTypes,
      if (resolvedValue == kReversalType.code) kReversalType,
      if (resolvedValue != null &&
          resolvedValue != kReversalType.code &&
          isRetiredType(resolvedValue) &&
          typeByCode(resolvedValue) != null)
        typeByCode(resolvedValue)!,
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
        Directionality(
          textDirection: TextDirection.rtl,
          child: DropdownButtonFormField<String>(
            key: ValueKey('$direction-$resolvedValue'),
            value: resolvedValue,
            isExpanded: true,
            validator: (v) => v == null ? 'Choose a type for $direction' : null,
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
                    value: t.code,
                    child: Text(t.label),
                  ),
                )
                .toList(),
            onChanged: (!enabled || resolvedValue == kReversalType.code)
                ? null
                : onChanged,
          ),
        ),
      ],
    );
  }
}
