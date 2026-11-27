import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.message,
    this.title = 'You\'re offline',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningContainer,
        border: Border.all(color: AppTheme.warningBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off, size: 20, color: AppTheme.warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
