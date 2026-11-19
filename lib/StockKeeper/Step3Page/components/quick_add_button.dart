import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

class QuickAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const QuickAddButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        backgroundColor: AppTheme.surfaceColor,
        side: const BorderSide(color: AppTheme.borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}
