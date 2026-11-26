import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';
// mobile_scanner = camera preview + QR reading in one widget.
// On Android it uses Google ML Kit (an on-device AI model), on iPhone
// Apple's Vision framework. Both work offline.
import 'package:mobile_scanner/mobile_scanner.dart';

/// Starts [controller] again, SAFELY, after another page used the camera.
/// Returns true if the camera is running at the end.
///
/// THE PROBLEM it solves: when the keeper goes back from Step 2, Step 2
/// closes its own camera — but releasing a camera takes a moment (it
/// happens in the background). If Step 1 calls start() at that exact
/// moment, the camera is still busy → start fails → "The camera couldn't
/// start" stays on screen forever.
///
/// THE FIX: wait a little and try again, up to [attempts] times, each
/// wait a bit longer (300 ms, 600 ms, 900 ms, 1200 ms).
/// If it still fails, the PAGE replaces the controller with a brand-new
/// one (see `_freshCamera()` in Steps 1 and 2).
Future<bool> startCameraSafely(
  MobileScannerController controller, {
  int attempts = 4,
}) async {
  // value = the live camera state (running? error? torch?…)
  bool ok() => controller.value.isRunning && controller.value.error == null;

  for (var i = 1; i <= attempts; i++) {
    // Future.delayed = "wait this long, then continue" (doesn't freeze the UI)
    await Future.delayed(Duration(milliseconds: 300 * i));
    try {
      if (ok()) return true; // already running → nothing to do
      await controller.start();
      if (ok()) return true; // started → stop trying
    } catch (e) {
      // still busy → the loop waits a bit longer and tries again
      debugPrint('Camera start attempt $i failed: $e');
    }
  }
  return ok();
}

/// The black camera area of Steps 1 and 2 (W3 / W4 in Figma):
///   • hint text on top ("Point the camera at the QR label…")
///   • white corner frame + moving orange scan line
///   • torch ⚡ and zoom 🔍 buttons
///   • a small "Checking…" chip while the code is being looked up
///
/// The PAGE owns the [controller] (it needs it to stop/start the camera
/// when it opens another page). This widget only shows it.
class ScannerView extends StatefulWidget {
  const ScannerView({
    super.key,
    required this.controller,
    required this.hint,
    required this.onCode,
    required this.onRetry,
    this.busy = false,
  });

  final MobileScannerController controller;
  final String hint; // text above the frame
  final ValueChanged<String> onCode; // called with the QR's text
  final bool busy; // true → show "Checking…"

  /// Called by the "Try again" button of the camera-error screen.
  /// The page gives a function that creates a FRESH camera controller.
  final Future<void> Function() onRetry;

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

// `SingleTickerProviderStateMixin` gives this State a "ticker" (a clock
// that ticks every frame) — needed by the AnimationController below.
class _ScannerViewState extends State<ScannerView>
    with SingleTickerProviderStateMixin {
  // Moves the orange line up and down inside the frame, forever.
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true); // cascade: create it AND start it

  @override
  void dispose() {
    _line.dispose(); // stop the clock when the widget is removed
    super.dispose();
  }

  /// Called by mobile_scanner every time it reads one or more codes.
  /// BarcodeCapture.barcodes = all codes seen in that camera frame.
  void _onDetect(BarcodeCapture capture) {
    // firstOrNull: the first item, or null if the list is empty.
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.trim().isEmpty) return;
    widget.onCode(value);
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder tells us how big this area is on THIS phone, so the
    // frame is always centred and sized to fit (small or big screens).
    return LayoutBuilder(
      builder: (context, box) {
        final size = (box.biggest.shortestSide * 0.68).clamp(180.0, 300.0);
        final frame = Rect.fromCenter(
          center: Offset(box.maxWidth / 2, box.maxHeight / 2),
          width: size,
          height: size,
        );

        // Stack = widgets on top of each other (camera at the bottom).
        return Stack(
          children: [
            // ---- 1) the camera ----
            Positioned.fill(
              child: MobileScanner(
                // ObjectKey(controller): when the page swaps in a NEW
                // controller, Flutter builds a NEW MobileScanner for it
                // (instead of keeping the old, broken one) → it starts fresh.
                key: ObjectKey(widget.controller),
                controller: widget.controller,
                onDetect: _onDetect,
                // scanWindow: read ONLY codes inside the frame → faster,
                // and it never reads the label NEXT to the right one.
                scanWindow: frame,
                // Shown instead of the camera if something goes wrong
                // (most often: the camera permission was refused).
                // "Try again" → start the SAME controller again.
                errorBuilder: (context, error) =>
                    _CameraError(error: error, onRetry: widget.onRetry),
              ),
            ),

            // ---- 2) hint text above the frame ----
            Positioned(
              left: 24,
              right: 24,
              top: (frame.top - 64).clamp(12.0, double.infinity),
              child: Text(
                widget.hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  // A soft shadow keeps white text readable on a bright scene.
                  shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ),
            ),

            // ---- 3) the white corners ----
            Positioned.fromRect(
              rect: frame,
              child: const CustomPaint(painter: _CornerPainter()),
            ),

            // ---- 4) the moving orange line ----
            // AnimatedBuilder rebuilds ONLY this line on every tick
            // (not the whole page) → smooth and cheap.
            AnimatedBuilder(
              animation: _line,
              builder: (context, _) => Positioned(
                left: frame.left + 18,
                width: frame.width - 36,
                top: frame.top + 14 + _line.value * (frame.height - 28),
                child: Container(height: 2.5, color: AppTheme.secondaryColor),
              ),
            ),

            // ---- 5) "Checking…" while we ask Firebase ----
            if (widget.busy)
              Positioned(
                top: frame.bottom + 14,
                left: 0,
                right: 0,
                child: const Center(child: _CheckingChip()),
              ),

            // ---- 6) torch + zoom buttons under the frame ----
            Positioned(
              top: frame.bottom + (widget.busy ? 58 : 20),
              left: 0,
              right: 0,
              child: _CameraButtons(controller: widget.controller),
            ),
          ],
        );
      },
    );
  }
}

/// Torch ⚡ and zoom 🔍 buttons.
///
/// MobileScannerController is a `ValueNotifier<MobileScannerState>`: its
/// `value` holds the live camera state (torch on/off, zoom…).
/// ValueListenableBuilder rebuilds the buttons when that state changes.
class _CameraButtons extends StatelessWidget {
  const _CameraButtons({required this.controller});
  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final torchOn = state.torchState == TorchState.on;
        final hasTorch = state.torchState != TorchState.unavailable;
        final zoomed = state.zoomScale > 0.05; // 0 = no zoom, 1 = max

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasTorch)
              _RoundButton(
                icon: torchOn ? Icons.flash_on : Icons.flash_off,
                active: torchOn,
                tooltip: torchOn ? 'Turn torch off' : 'Turn torch on',
                onTap: controller.toggleTorch, // good for dark corners
              ),
            const SizedBox(width: 16),
            _RoundButton(
              icon: zoomed ? Icons.zoom_out : Icons.zoom_in,
              active: zoomed,
              tooltip: zoomed ? 'Zoom out' : 'Zoom in',
              // Halfway zoom: for labels high up on a rack.
              onTap: () => controller.setZoomScale(zoomed ? 0 : 0.5),
            ),
          ],
        );
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        // active (torch on / zoomed) → white circle, else a DARK circle
        // (dark stays visible on bright labels and white screens too)
        color: active ? Colors.white : Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              icon,
              color: active ? AppTheme.primaryColor : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckingChip extends StatelessWidget {
  const _CheckingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 8),
          Text('Checking…', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

/// Shown instead of the camera when it can't start.
/// Has a "Try again" button, so the keeper is never stuck (before, the
/// only way out was closing the whole app).
class _CameraError extends StatefulWidget {
  const _CameraError({required this.error, required this.onRetry});
  final MobileScannerException error;
  final Future<void> Function() onRetry; // a function that returns a Future

  @override
  State<_CameraError> createState() => _CameraErrorState();
}

class _CameraErrorState extends State<_CameraError> {
  bool _retrying = false; // true → show a spinner instead of the button

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await widget.onRetry();
    // If the camera started, this whole widget disappears (the camera
    // shows instead), so only touch the state if it's still on screen.
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final denied =
        widget.error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: const Color(0xFF0B0F14),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied ? Icons.no_photography_outlined : Icons.error_outline,
                color: Colors.white70,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                denied
                    ? 'Camera access is off.\nAllow it in the phone settings, '
                          'or enter the code manually below.'
                    : 'The camera couldn\'t start.\nEnter the code manually below.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 16),
              _retrying
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                      // white button: visible on the black background
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the 4 white rounded corners of the scan frame.
/// CustomPainter = we draw lines ourselves on a "canvas".
class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const len = 34.0; // length of each corner arm
    const r = 14.0; // corner roundness
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width, h = size.height;
    // Each Path = one corner: a straight arm, a curve, another arm.
    final corners = [
      Path() // top-left
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(len, 0),
      Path() // top-right
        ..moveTo(w - len, 0)
        ..lineTo(w - r, 0)
        ..quadraticBezierTo(w, 0, w, r)
        ..lineTo(w, len),
      Path() // bottom-right
        ..moveTo(w, h - len)
        ..lineTo(w, h - r)
        ..quadraticBezierTo(w, h, w - r, h)
        ..lineTo(w - len, h),
      Path() // bottom-left
        ..moveTo(len, h)
        ..lineTo(r, h)
        ..quadraticBezierTo(0, h, 0, h - r)
        ..lineTo(0, h - len),
    ];
    for (final c in corners) {
      canvas.drawPath(c, paint);
    }
  }

  // The corners never change → never repaint (saves work).
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}