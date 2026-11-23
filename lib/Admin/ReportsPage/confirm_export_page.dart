import 'package:aral_project/Admin/ReportsPage/report_widgets.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

/// "Confirm export" page (screen 11). It is only used when
/// `kPreviewPlacement == PreviewPlacement.confirmPage` (see reports_page.dart).
///
/// It does not know anything about filters or transactions: it shows the
/// [preview] it is given and calls [onExport] when the button is tapped.
class ConfirmExportPage extends StatefulWidget {
  const ConfirmExportPage({
    super.key,
    required this.preview,
    required this.buttonLabel,
    required this.onExport,
  });

  final Widget preview;
  final String buttonLabel;

  /// Gets the context of THIS page (the "saved · OPEN" message uses it).
  final Future<void> Function(BuildContext context) onExport;

  @override
  State<ConfirmExportPage> createState() => _ConfirmExportPageState();
}

class _ConfirmExportPageState extends State<ConfirmExportPage> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onExport(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Confirm export')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Check the file before you save it.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppTheme.textColorSecondary),
          ),
          const SizedBox(height: 12),
          widget.preview,
          const SizedBox(height: 16),
          ExportButton(
            label: widget.buttonLabel,
            enabled: true,
            busy: _busy,
            onPressed: _run,
          ),
        ],
      ),
    );
  }
}
