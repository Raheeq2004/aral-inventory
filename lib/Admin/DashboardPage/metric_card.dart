import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final IconData icon;
  final String count;
  final String label;

  const MetricCard({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      // Automatically uses the card theme settings (background, border radius, border color) from AppTheme
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                // KPI icons use the navy family (primaryContainer + primary), not the
                // orange accent: orange stays for small highlights only.
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: theme.textTheme.displaySmall?.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
