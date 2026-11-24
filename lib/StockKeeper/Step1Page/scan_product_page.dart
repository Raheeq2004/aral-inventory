import 'package:aral_project/StockKeeper/Step2Page/scan_location_page.dart';
import 'package:aral_project/StockKeeper/components/length_picker_sheet.dart';
import 'package:aral_project/StockKeeper/components/manual_code_sheet.dart';
import 'package:aral_project/StockKeeper/components/not_found_dialog.dart';
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
///   QR text (or typed code) → ScanFlowProvider.lookupProduct()
///     • 1 row        → saved in the session → open Step 2
///     • several rows → "Which length?" sheet → open Step 2
///     • no row       → "Product not found" dialog (W3c)
///     • offline      → red message
class ScanProductPage extends StatefulWidget {
  const ScanProductPage({super.key});

  @override
  State<ScanProductPage> createState() => _ScanProductPageState();
}

class _ScanProductPageState extends State<ScanProductPage> {
  // The camera controller lives here because this page decides when the
  // camera stops (while Step 2 is open) and starts again (when back).
  final MobileScannerController _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode], // only QR → faster, fewer mistakes
    detectionSpeed: DetectionSpeed.normal,
  );

  // Ignore the SAME code read again within 2 s: the camera sees a label
  // many times per second, but we want ONE lookup per scan.
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  // true while a sheet / dialog / Step 2 is open → camera reads are ignored,
  // so nothing happens "behind" what the keeper is looking at.
  bool _paused = false;

  @override
  void dispose() {
    _camera.dispose(); // free the camera when the page closes
    super.dispose();
  }

  // ---------------------------------------------------------------
  // A code arrives from the CAMERA
  // ---------------------------------------------------------------
  Future<void> _onScan(String code) async {
    if (_paused || context.read<ScanFlowProvider>().isLooking) return;

    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt).inSeconds < 2) return;
    _lastCode = code;
    _lastAt = now;

    HapticFeedback.selectionClick(); // tiny tick: "I saw it"
    await _lookup(code);
  }

  // ---------------------------------------------------------------
  // The same lookup for a SCANNED or a TYPED code
  // ---------------------------------------------------------------
  Future<void> _lookup(String code) async {
    final flow = context.read<ScanFlowProvider>();
    _paused = true; // no new scans until this one is handled
    try {
      final result = await flow.lookupProduct(code);
      if (!mounted) return; // the page was closed while we waited

      // switch on the enum: Dart checks that EVERY status is handled.
      switch (result.status) {
        case LookupStatus.found:
          HapticFeedback.mediumImpact(); // clear "done" vibration
          await _goToStep2();

        case LookupStatus.chooseLength:
          // Several lengths → the keeper picks one (null = closed the sheet)
          final row = await showLengthPicker(context, result.code, result.rows);
          if (row == null || !mounted) return;
          flow.selectItem(row);
          HapticFeedback.mediumImpact();
          await _goToStep2();

        case LookupStatus.notFound:
          HapticFeedback.heavyImpact();
          final action = await showNotFoundDialog(
            context,
            title: 'Product not found',
            message: ScanFlowProvider.looksLikeLocation(result.code)
                // a SHELF label was scanned on the product step
                ? '${result.code} is a location label. '
                      'Scan the label on the product first.'
                : 'The code ${result.code} isn\'t registered in the system. '
                      'Check the label or ask your admin to add it.',
          );
          if (action == NotFoundAction.enterManually && mounted) {
            _paused = false; // _enterManually pauses again itself
            await _enterManually();
          }

        case LookupStatus.offline:
          _message(
            'No connection. Check the internet and scan again.',
            error: true,
          );
      }
    } finally {
      _paused = false;
      _lastCode = null; // the same label can be scanned again right away
    }
  }

  // ---------------------------------------------------------------
  // "Can't scan? Enter code manually" (W3b)
  // ---------------------------------------------------------------
  Future<void> _enterManually() async {
    _paused = true;
    final code = await showManualCodeSheet(
      context,
      title: 'Enter product code',
      description: 'Type the code printed under the QR label on the product.',
      label: 'Product code',
      icon: Icons.qr_code_2,
      hint: '2MFMF-BT128',
    );
    _paused = false;
    if (code != null && mounted) await _lookup(code);
  }

  // ---------------------------------------------------------------
  // Open Step 2 (scan location)
  // ---------------------------------------------------------------
  Future<void> _goToStep2() async {
    // Stop OUR camera: Step 2 opens its own. Two pages using the camera at
    // once can fail on some phones (and wastes battery).
    await _camera.stop();
    if (!mounted) return;
    // push() returns a Future that completes when Step 2 is CLOSED
    // (back arrow, or after the transaction is saved).
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanLocationPage()),
    );
    // Back on Step 1 → start the camera again for the next product.
    if (mounted) await _camera.start();
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
              onCode: _onScan,
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
                    onPressed: busy ? null : _enterManually,
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