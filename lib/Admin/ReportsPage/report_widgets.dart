import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

/// The rounded "pill" used for every choice in the sheets and the picker.
/// Selected = peach fill, bold text (no check mark, like the design).
class ReportChip extends StatelessWidget {
  const ReportChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppTheme.secondaryContainer,
      backgroundColor: AppTheme.surfaceColor,
      shape: const StadiumBorder(),
      side: BorderSide(
        color: selected
            ? AppTheme.secondaryColor.withValues(alpha: 0.35)
            : AppTheme.borderColor,
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected
            ? AppTheme.onSecondaryContainer
            : AppTheme.textColorPrimary,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// The big navy button. While [busy] it shows a spinner (and ignores taps).
class ExportButton extends StatelessWidget {
  const ExportButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        // busy: keep the navy colour, but do nothing when tapped
        onPressed: busy ? () {} : (enabled ? onPressed : null),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download_rounded, size: 20),
        label: Text(busy ? 'Exporting…' : label),
      ),
    );
  }
}
