import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

/// The 2 buttons of the "not found" dialog.
enum NotFoundAction { enterManually, scanAgain }

/// "Product not found" (W3c) / "Location not found" (W4c).
/// ONE dialog for both: only the title and message change.
///
/// Returns what the keeper tapped. Tapping outside = scan again.
Future<NotFoundAction> showNotFoundDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final action = await showDialog<NotFoundAction>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.error, color: AppTheme.errorColor, size: 32),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      // spaceBetween: one button on the left, the other on the right
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, NotFoundAction.enterManually),
          child: const Text('Enter manually'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, NotFoundAction.scanAgain),
          icon: const Icon(Icons.qr_code_scanner, size: 18),
          label: const Text('Scan again'),
        ),
      ],
    ),
  );
  // `??` → if the dialog was closed by tapping outside, it returns null;
  // we treat that as "scan again".
  return action ?? NotFoundAction.scanAgain;
}