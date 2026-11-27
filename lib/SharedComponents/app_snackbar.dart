import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  SnackBarAction? action,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : null,
        behavior: action != null ? SnackBarBehavior.floating : null,
        action: action,
      ),
    );
}
