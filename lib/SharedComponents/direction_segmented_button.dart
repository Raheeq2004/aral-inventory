import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

class DirectionSegmentedButton extends StatelessWidget {
  final String value; // 'IN' or 'OUT'
  final ValueChanged<String>? onChanged; // null disables the control

  const DirectionSegmentedButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isIn = value == 'IN';

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(52)),
          shape: WidgetStateProperty.all(const StadiumBorder()),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isIn
                  ? AppTheme.successColor.withValues(alpha: 0.16)
                  : AppTheme.errorColor.withValues(alpha: 0.14);
            }
            return AppTheme.surfaceColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isIn ? AppTheme.successColor : AppTheme.errorColor;
            }
            return AppTheme.textColorPrimary;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppTheme.borderColor),
          ),
        ),
        segments: const [
          ButtonSegment(
            value: 'IN',
            icon: Icon(Icons.arrow_downward_rounded, size: 18),
            label: Text(
              'IN · Store',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ButtonSegment(
            value: 'OUT',
            icon: Icon(Icons.arrow_upward_rounded, size: 18),
            label: Text(
              'OUT · Withdraw',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        selected: {value},
        onSelectionChanged: onChanged == null
            ? null
            : (selection) => onChanged!(selection.first),
      ),
    );
  }
}
