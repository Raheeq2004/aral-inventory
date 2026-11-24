import 'package:aral_project/StockKeeper/Step3Page/components/summary_info_cards.dart';
import 'package:aral_project/StockKeeper/Step3Page/quantity_page.dart';
import 'package:aral_project/StockKeeper/components/manual_code_sheet.dart';
import 'package:aral_project/StockKeeper/components/not_found_dialog.dart';
import 'package:aral_project/StockKeeper/components/scanner_view.dart';
import 'package:aral_project/StockKeeper/components/step_progress_bar.dart';
import 'package:aral_project/StockKeeper/models/scan_labels.dart';
import 'package:aral_project/StockKeeper/providers/scan_flow_provider.dart';
import 'package:aral_project/StockKeeper/worker_routing.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

/// STEP 2 — scan the QR on the rack / shelf (W4 in Figma).
///
/// Same camera as Step 1, plus the green "✓ PRODUCT" card underneath so the
/// keeper sees WHICH product they are placing / taking.
///
///   QR text (or typed code) → ScanFlowProvider.lookupLocation()
///     • found     → saved in the session → open Step 3 (Quantity)
///     • not found → "Location not found" dialog (W4c)
///     • offline   → red message
class ScanLocationPage extends StatefulWidget {
  const ScanLocationPage({super.key});

  @override
  State<ScanLocationPage> createState() => _ScanLocationPageState();
}

class _ScanLocationPageState extends State<ScanLocationPage> {
  final MobileScannerController _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _paused = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onScan(String code) async {
    if (_paused || context.read<ScanFlowProvider>().isLooking) return;

    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt).inSeconds < 2) return;
    _lastCode = code;
    _lastAt = now;

    HapticFeedback.selectionClick();
    await _lookup(code);
  }

  Future<void> _lookup(String code) async {
    final flow = context.read<ScanFlowProvider>();
    _paused = true;
    try {
      final status = await flow.lookupLocation(code);
      if (!mounted) return;

      switch (status) {
        case LocationStatus.found:
          HapticFeedback.mediumImpact();
          await _goToStep3();

        case LocationStatus.notFound:
          HapticFeedback.heavyImpact();
          final clean = code.trim().toUpperCase();
          final action = await showNotFoundDialog(
            context,
            title: 'Location not found',
            message: ScanFlowProvider.looksLikeLocation(clean)
                ? 'The code $clean isn\'t registered in the system. '
                      'Check the shelf label or ask your admin to add it.'
                // wrong shape → most likely a PRODUCT label scanned here
                : '$clean isn\'t a location code. '
                      'Scan the label on the rack or shelf.',
          );
          if (action == NotFoundAction.enterManually && mounted) {
            _paused = false;
            await _enterManually();
          }

        case LocationStatus.offline:
          _message(
            'No connection. Check the internet and scan again.',
            error: true,
          );
      }
    } finally {
      _paused = false;
      _lastCode = null;
    }
  }

  Future<void> _enterManually() async {
    _paused = true;
    final code = await showManualCodeSheet(
      context,
      title: 'Enter location code',
      description: 'Type the code printed on the rack or shelf label.',
      label: 'Location code',
      icon: Icons.location_on_outlined,
      hint: 'WH1-B3-02',
    );
    _paused = false;
    if (code != null && mounted) await _lookup(code);
  }

  /// Opens Joud's Quantity page (Step 3). It reads the product and the
  /// location from the SAME ScanFlowProvider session.
  Future<void> _goToStep3() async {
    await _camera.stop();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const WorkerRouting(title: 'Quantity', child: QuantityPage()),
      ),
    );
    if (mounted) await _camera.start();
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? AppTheme.errorColor : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<ScanFlowProvider>();
    final item = flow.session.item; // chosen in Step 1

    return WorkerRouting(
      title: 'Scan location',
      child: Column(
        children: [
          Expanded(
            child: ScannerView(
              controller: _camera,
              hint: 'Now scan the QR on the rack or shelf',
              onCode: _onScan,
              busy: flow.isLooking,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(
                children: [
                  const StepProgressBar(currentStep: 2),
                  const SizedBox(height: 12),
                  // The product from Step 1 (Joud's card, reused).
                  // `if (item != null)`: safety — normally always set here.
                  if (item != null)
                    SummaryInfoCard(
                      icon: Icons.qr_code_2_rounded,
                      categoryLabel: 'PRODUCT',
                      title: item.code,
                      subtitle: productSubtitle(item),
                    ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: flow.isLooking ? null : _enterManually,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Can\'t scan? Enter code manually'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}