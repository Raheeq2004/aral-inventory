import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

/// "Can't scan? Enter code manually" (W3b product / W4b location).
/// ONE sheet for both steps: only the texts and the icon change.
///
/// Returns the typed code (trimmed, upper-case), or null on Cancel.
///
/// Usage:
///   final code = await showManualCodeSheet(
///     context,
///     title: 'Enter product code',
///     description: 'Type the code printed under the QR label.',
///     label: 'Product code',
///     icon: Icons.qr_code_2,
///     hint: '2MFMF-BT128',
///   );
Future<String?> showManualCodeSheet(
  BuildContext context, {
  required String title,
  required String description,
  required String label,
  required IconData icon,
  required String hint,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    // isScrollControlled: the sheet can move up with the keyboard.
    isScrollControlled: true,
    builder: (context) => _ManualCodeSheet(
      title: title,
      description: description,
      label: label,
      icon: icon,
      hint: hint,
    ),
  );
}

class _ManualCodeSheet extends StatefulWidget {
  const _ManualCodeSheet({
    required this.title,
    required this.description,
    required this.label,
    required this.icon,
    required this.hint,
  });

  final String title;
  final String description;
  final String label;
  final IconData icon;
  final String hint;

  @override
  State<_ManualCodeSheet> createState() => _ManualCodeSheetState();
}

class _ManualCodeSheetState extends State<_ManualCodeSheet> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a code');
      return; // stay open until there's something to look up
    }
    Navigator.pop(context, code); // → result of showManualCodeSheet
  }

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom = the keyboard's height. Adding it as padding
    // pushes the sheet up so the keyboard never covers the field.
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.description,
            style: const TextStyle(color: AppTheme.textColorSecondary),
          ),
          const SizedBox(height: 16),
          Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            autofocus: true, // keyboard opens straight away
            textCapitalization: TextCapitalization.characters, // CAPITALS
            textInputAction: TextInputAction.done, // "Done" key on keyboard
            onSubmitted: (_) => _confirm(), // pressing "Done" = Confirm
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              prefixIcon: Icon(widget.icon),
              hintText: widget.hint,
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context), // null = cancelled
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}