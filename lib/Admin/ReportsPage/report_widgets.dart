import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';


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
          shape: const StadiumBorder(), // fully rounded
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

/// The navy button of every sheet ("Show 19 rows", "Apply", "Done"):
/// fully rounded, same height as the Export button.
class ReportButton extends StatelessWidget {
  const ReportButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
        child: Text(label),
      ),
    );
  }
}

/// The "+46 more" / "Show fewer" pill of the family chips.
/// Normal = light blue (opens). [strong] = solid navy, full strength, so
/// the way back out of a long list is impossible to miss.
class ExpandPill extends StatelessWidget {
  const ExpandPill({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.strong = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final bg = strong ? AppTheme.primaryColor : AppTheme.primaryContainer;
    final fg = strong ? Colors.white : AppTheme.onPrimaryContainer;
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: strong ? 12 : 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: strong ? 14 : 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: strong ? 20 : 18, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
