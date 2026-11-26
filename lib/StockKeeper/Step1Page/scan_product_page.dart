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
///   QR text `ITM-<id>` (or typed id / code) → ScanFlowProvider.lookupProduct()
///     • 1 row        → saved in the session → open Step 2
///                      (always the case for an ITM label)
///     • several rows → "Which length?" sheet → open Step 2
///                      (only for a typed item code / old label)
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
  // NOT final: if the camera gets stuck, _freshCamera() swaps in a new one.
  MobileScannerController _camera = _newCamera();

  /// Creates a camera controller with OUR settings. `static` → it doesn't
  /// need the page object, so it can be used in the field above.
  static MobileScannerController _newCamera() => MobileScannerController(
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
  /// [typed] = true when the code was typed in "Enter manually"
  /// (then a plain number like "1201" is accepted as an item id).
  Future<void> _lookup(String code, {bool typed = false}) async {
    final flow = context.read<ScanFlowProvider>();
    _paused = true; // no new scans until this one is handled
    // true → keep [_lastCode] after this lookup, so the 2-second rule
    // ignores the SAME label: a short message (no dialog) would otherwise
    // repeat many times a second while the label is still in front.
    var keepLastCode = false;
    try {
      final result = await flow.lookupProduct(code, typed: typed);
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
            message: _notFoundMessage(result.code, typed: typed),
          );
          if (action == NotFoundAction.enterManually && mounted) {
            _paused = false; // _enterManually pauses again itself
            await _enterManually();
          }

        case LookupStatus.notOurLabel:
          keepLastCode = true;
          // A QR that isn't an ITM-… product label (supplier barcode, old
          // test label…). Short red message, the camera keeps scanning.
          HapticFeedback.heavyImpact();
          _message(
            'This isn\'t an ARAL product label. '
            'Scan the ITM label on the product.',
            error: true,
          );

        case LookupStatus.offline:
          keepLastCode = true;
          _message(
            'No connection. Check the internet and scan again.',
            error: true,
          );

        case LookupStatus.failed:
          keepLastCode = true;
          // Online, but Firebase failed / was too slow (the real error is
          // printed in the debug console).
          _message('Something went wrong. Try again.', error: true);
      }
    } finally {
      _paused = false;
      // normally: the same label can be scanned again right away
      if (!keepLastCode) _lastCode = null;
    }
  }

  /// The text of the "Product not found" dialog — says WHAT was scanned,
  /// so the keeper knows what to do next.
  String _notFoundMessage(String code, {required bool typed}) {
    // a SHELF label was scanned on the product step
    if (ScanFlowProvider.looksLikeLocation(code)) {
      return '$code is a location label. Scan the label on the product first.';
    }
    // a product label (or a typed number) whose id doesn't exist
    if (ScanFlowProvider.productIdFrom(code, allowBareNumber: typed) != null) {
      return 'Item $code isn\'t registered in the system. '
          'Check the label or ask your admin.';
    }
    return 'The code $code isn\'t registered in the system. '
        'Check the label or ask your admin to add it.';
  }

  // ---------------------------------------------------------------
  // "Can't scan? Enter code manually" (W3b)
  // ---------------------------------------------------------------
  Future<void> _enterManually() async {
    _paused = true;
    final code = await showManualCodeSheet(
      context,
      title: 'Enter product',
      // Both work: the number under the QR (exact row) OR the item code
      // (then "Which length?" if the code has several lengths).
      description:
          'Type the number under the QR label (ITM-1201 or just 1201), '
          'or the item code.',
      label: 'Item number or code',
      icon: Icons.qr_code_2,
      hint: 'ITM-1201',
    );
    _paused = false;
    // typed: true → a plain "1201" counts as an item id
    if (code != null && mounted) await _lookup(code, typed: true);
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
    // (Safely: Step 2 may still be releasing ITS camera at this moment.)
    if (mounted) await _resumeCamera();
  }

  // ---------------------------------------------------------------
  // Camera recovery (coming back from another page / "Try again")
  // ---------------------------------------------------------------

  /// Start the camera again after another page used it. First tries the
  /// SAME controller a few times; if it's still stuck → a fresh one.
  Future<void> _resumeCamera() async {
    final ok = await startCameraSafely(_camera);
    if (!ok && mounted) await _freshCamera();
  }

  /// Replaces the stuck controller with a brand-new one.
  /// setState → build() runs again → ScannerView gets the new controller
  /// → a new MobileScanner (ObjectKey) starts it automatically.
  /// The old one is then disposed (frees the camera hardware).
  Future<void> _freshCamera() async {
    final old = _camera;
    setState(() => _camera = _newCamera());
    await old.dispose();
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
              onRetry: _freshCamera, // "Try again" on the camera-error screen
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