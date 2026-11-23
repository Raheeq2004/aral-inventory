import 'package:aral_project/StockKeeper/components/scanner_view.dart';
import 'package:aral_project/StockKeeper/components/step_progress_bar.dart';
import 'package:aral_project/StockKeeper/providers/scan_flow_provider.dart';
import 'package:aral_project/StockKeeper/worker_routing.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback (vibration)
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

/// STEP 1 — scan the product's QR label (W3 in Figma).
///
/// What happens on a scan:
///   QR text → ScanFlowProvider.lookupProduct() → items (indexed search)
///     • 1 row        → saved in the session → (Step 2, next branch)
///     • several rows → "which length?" sheet  (next branch)
///     • no row       → "Product not found"    (next branch)
/// For now the 3 results show a short message, so we can test the camera
/// and the lookup on a real phone first.
class ScanProductPage extends StatefulWidget {
  const ScanProductPage({super.key});

  @override
  State<ScanProductPage> createState() => _ScanProductPageState();
}

class _ScanProductPageState extends State<ScanProductPage> {
  // The camera controller lives here (not in ScannerView) because this
  // page decides when the camera stops (e.g. while another page is open).
  final MobileScannerController _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode], // only QR → faster, fewer mistakes
    detectionSpeed: DetectionSpeed.normal,
  );

  // Ignore the SAME code read again within 2 s: the camera sees a label
  // many times per second, but we want ONE lookup per scan.
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _camera.dispose(); // free the camera when the page closes
    super.dispose();
  }

  Future<void> _onCode(String code) async {
    final flow = context.read<ScanFlowProvider>();
    if (flow.isLooking) return; // still checking the previous scan

    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt).inSeconds < 2) return;
    _lastCode = code;
    _lastAt = now;

    HapticFeedback.selectionClick(); // tiny tick: "I saw it"
    final result = await flow.lookupProduct(code);
    if (!mounted) return; // the page was closed while we waited

    // switch on the enum: Dart checks that EVERY status is handled.
    switch (result.status) {
      case LookupStatus.found:
        HapticFeedback.mediumImpact(); // clear "done" vibration
        final row = result.rows.first;
        _message('Found ${row.code} · ${_len(row.length)} · '
            '${row.quantity} in stock');
      // TODO(next branch): open Step 2 (scan location).
      case LookupStatus.chooseLength:
        _message('${result.code} has ${result.rows.length} lengths: '
            '${result.rows.map((r) => _len(r.length)).join(', ')}');
      // TODO(next branch): show the length picker sheet.
      case LookupStatus.notFound:
        HapticFeedback.heavyImpact();
        _message('${result.code} isn\'t registered.', error: true);
      // TODO(next branch): show the "Product not found" dialog.
      case LookupStatus.offline:
        _message('No connection. Check the internet and scan again.',
            error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar() // don't stack messages
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? AppTheme.errorColor : null,
        ),
      );
  }

  /// 6.0 → "6 m", 6.3 → "6.3 m"
  String _len(double l) =>
      '${l == l.roundToDouble() ? l.toStringAsFixed(0) : l} m';

  @override
  Widget build(BuildContext context) {
    // watch: rebuild when the provider changes (to show "Checking…").
    final busy = context.watch<ScanFlowProvider>().isLooking;

    return WorkerRouting(
      title: 'Scan product',
      child: Column(
        children: [
          // ---- camera (takes all the space left) ----
          // (No "scan method" choice: the team decided on the phone camera
          //  only — no RFID / NFC — so the camera gets the full width.)
          Expanded(
            child: ScannerView(
              controller: _camera,
              hint: 'Point the camera at the QR label on the product',
              onCode: _onCode,
              busy: busy,
            ),
          ),

          // ---- bottom: steps + manual entry ----
          // SafeArea: keep it above the phone's own navigation bar.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(
                children: [
                  const StepProgressBar(currentStep: 1),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => _message(
                      'Manual entry comes in the next step.',
                    ), // TODO(next branch): open the manual code sheet.
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