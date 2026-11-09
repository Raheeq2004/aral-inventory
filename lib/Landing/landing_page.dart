// =====================================================================
// ARAL Inventory – Splash screen (Figma screen "W0 · Splash")
// =====================================================================
//
// What this screen does:
//   1. Shows floating decorative shapes in the background (animated).
//   2. Shows the sunrise-orange logo, the app name and the slogan.
//   3. Shows a spinner + "Preparing your workspace…".
//   4. After ~3 seconds it moves BY ITSELF to the next screen
//      (no button). Later, when Login exists, it will decide:
//        not logged in → Login, worker → Scan, admin → Dashboard.
//
// All positions/sizes come from the Figma design (a 360 x 800 screen)
// and are scaled to the real phone size, so it looks the same everywhere.
//
// (The file/class are still called landing_page / LandingPage so
//  main.dart doesn't need to change.)
// =====================================================================

// 'dart:math' = Dart's math library (sin, pi) for the floating wave.
// "as math" gives it a short prefix: math.sin(), math.pi
import 'dart:math' as math;

import 'package:flutter/material.dart';

// Where we go after the splash (for now, until the Login page exists).
import 'package:aral_project/Admin/admin_routing.dart';

// Joud's theme: we reuse the navy + burnt orange colors from there.
import 'package:aral_project/Theme/theme.dart';

// ---------------------------------------------------------------------
// Colors used only on this page (soft decoration colors).
// `const` = fixed value known before the app runs → created once, reused.
// ---------------------------------------------------------------------
const kLandingBackground = Color(0xFFF6F1EA); // warm off-white background
const kTextSecondary = Color(0xFF4A5260);     // grey for slogan + status text
const kPeach = Color(0xFFFCE1D0);             // peach boxes/circles (theme secondaryContainer)
const kPeachDeep = Color(0xFFF6D3BD);         // "tape" bars + boxes (Figma decorBronze)
const kBlueLight = Color(0xFFD6E3F7);         // big circle + small bar
const kBlueLighter = Color(0xFFDCE7F5);       // rounded squares
const kQrBlue = Color(0xFFC9D8EE);            // the small QR piece
const kPin = Color(0xFFE8976A);               // the location pin (Figma decorPin)

// Logo gradient colors (sunrise orange: light → burnt orange → deep)
const kLogoLight = Color(0xFFF7A35C);
const kLogoMid = Color(0xFFE06A2B);
const kLogoDeep = Color(0xFFB0461A);

// How long the splash stays on screen before moving on.
// 3 s = enough time to see the logo, the shapes floating and the spinner.
const kSplashDuration = Duration(seconds: 3);

// =====================================================================
// 1) THE SPLASH PAGE
// =====================================================================

/// STATEFUL now (before it was Stateless), because the page must DO
/// something by itself after it appears: wait 3 seconds, then navigate.
/// Things that happen over time / on start belong in a State class.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  // initState() runs ONCE, when the page is first created.
  // Perfect place to start the timer.
  // Rule: super.initState() FIRST.
  @override
  void initState() {
    super.initState();

    // Future.delayed = "run this function after this much time".
    // It returns a Future (a value that arrives later); we don't need
    // to await it, we just let it call _goNext when the time is up (3 s).
    Future.delayed(kSplashDuration, _goNext);
  }

  /// Decides where to go after the splash.
  void _goNext() {
    // `mounted` = is this page still on screen?
    // If the user closed the app during the 3 seconds, the page is gone,
    // and using its context would crash → so we check first.
    if (!mounted) return;

    // TODO (when Firebase Auth + Login page exist):
    //   final user = FirebaseAuth.instance.currentUser;
    //   if (user == null)            → go to LoginPage
    //   else read users/<uid>/role:
    //        role == 'admin'         → go to AdminRouting
    //        role == 'worker'        → go to the worker Scan page

    // pushReplacement = REPLACE the splash with the next screen, so the
    // phone's back button can't return to the splash.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminRouting()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Text styles from the theme (looks UP the tree to MaterialApp's theme).
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: kLandingBackground,

      // Stack = layers on top of each other:
      //   layer 1 (bottom): animated shapes
      //   layer 2 (top):    logo, texts, spinner
      body: Stack(
        children: [
          // Positioned.fill = stretch to cover the whole screen.
          const Positioned.fill(child: FloatingShapesBackground()),

          // SafeArea = keep content away from the status bar / gesture bar.
          SafeArea(
            child: Center(
              child: Column(
                children: [
                  // Spacer = flexible empty space. 3 above : 4 below puts the
                  // logo a little ABOVE the center, like the Figma design.
                  const Spacer(flex: 3),

                  const _SunriseLogo(),
                  const SizedBox(height: 20),

                  // App name. copyWith = keep the theme style, change a few things.
                  // `?.` = only call copyWith if the style isn't null (null safety).
                  Text(
                    'ARAL Inventory',
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Scan. Store. Track.',
                    style: textTheme.bodyLarge?.copyWith(color: kTextSecondary),
                  ),

                  const SizedBox(height: 32),

                  // ---- Spinner + status text (replaces the Sign in button) ----
                  // SizedBox fixes the spinner's size (28 x 28).
                  // Our own slower spinner (see _SlowSpinner below).
                  const _SlowSpinner(),
                  const SizedBox(height: 12),
                  const Text(
                    'Preparing your workspace…',
                    style: TextStyle(fontSize: 13, color: kTextSecondary),
                  ),

                  const Spacer(flex: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// 1b) A SLOWER SPINNER
// =====================================================================
//
// Flutter's CircularProgressIndicator spins at a FIXED speed (we can't
// change it). So we build our own: a FIXED orange arc (value: 0.28 = 28%
// of a circle) and we ROTATE it ourselves with an AnimationController.
// We choose the speed: one full turn every 2.5 s (calm, not hectic).
class _SlowSpinner extends StatefulWidget {
  const _SlowSpinner();

  @override
  State<_SlowSpinner> createState() => _SlowSpinnerState();
}

// SingleTickerProviderStateMixin = like TickerProviderStateMixin, but for
// exactly ONE AnimationController (lighter).
class _SlowSpinnerState extends State<_SlowSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500), // one turn every 2.5 s ← bigger = slower
  )..repeat();

  @override
  void dispose() {
    _turn.dispose(); // always stop controllers when leaving
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RotationTransition rotates its child using the controller's value:
    // 0.0 → 1.0 = 0° → 360°.
    return RotationTransition(
      turns: _turn,
      child: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          value: 0.28, // a fixed arc (not the built-in fast animation)
          strokeWidth: 3,
          strokeCap: StrokeCap.round, // rounded arc ends
          color: AppTheme.secondaryColor, // burnt orange
          backgroundColor: Color(0x1FC2531C), // faint orange track (12%)
        ),
      ),
    );
  }
}

// =====================================================================
// 2) THE SUNRISE LOGO (gradient + shine + glow)
// =====================================================================

/// A small reusable StatelessWidget: nothing changes inside it.
/// The leading `_` makes it PRIVATE to this file.
class _SunriseLogo extends StatelessWidget {
  const _SunriseLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      // BoxDecoration = how the box looks (gradient, corners, shadow).
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),

        // LinearGradient = smooth blend between colors along a line.
        // begin top-left → end bottom-right: light where "the sun hits",
        // darker at the bottom → the tile looks 3D.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kLogoLight, kLogoMid, kLogoDeep],
          stops: [0.0, 0.45, 1.0], // where each color sits (0 = start, 1 = end)
        ),

        // BoxShadow = the soft warm glow UNDER the logo, so it "floats".
        // offset moves it down; blurRadius softens it; negative spread
        // makes it a bit smaller than the box.
        boxShadow: [
          BoxShadow(
            color: kLogoDeep.withValues(alpha: 0.45),
            offset: const Offset(0, 12),
            blurRadius: 24,
            spreadRadius: -8,
          ),
        ],
      ),

      // ClipRRect = cut everything inside to the rounded corners,
      // so the shine doesn't stick out of the tile.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The "shine": a soft white oval at the top (like a reflection).
            Positioned(
              top: -30,
              left: -14,
              child: Container(
                width: 124,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle, // stretched circle = oval
                  // (BoxShape.circle with width ≠ height draws an oval
                  //  inside the box)
                ),
              ),
            ),
            // The QR icon, white on orange.
            const Icon(Icons.qr_code_scanner, size: 52, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 3) THE DATA FOR ONE DECORATIVE SHAPE (plain Dart class, not a widget)
// =====================================================================

/// A CLASS is a blueprint; each shape is one OBJECT made from it.
/// Values are in "design pixels" (Figma screen = 360 x 800).
class ShapeSpec {
  // `required` = must be given; `= value` = optional with a default.
  const ShapeSpec({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.color,
    this.radius = 8,      // corner roundness
    this.angle = 0,       // rotation in degrees
    this.stripe = false,  // white "tape" line in the middle (box look)
    this.isCircle = false,
    this.child,           // optional custom content (QR piece, pin icon)
    this.floatY = 6,      // how far it moves up/down (px)
    this.floatX = 0,      // how far it moves left/right (px)
    this.speed = 1.0,     // 1.0 = one full float cycle per 6 s
    this.phase = 0.0,     // 0..1 start offset, so shapes don't move together
    this.opacity = 1.0,   // the new middle shapes are a bit lighter (0.85)
  });

  final double left, top, width, height, radius, angle;
  final double floatY, floatX, speed, phase, opacity;
  final Color color;
  final bool stripe, isCircle;
  final Widget? child; // `?` = nullable: a widget OR null
}

/// The 12 shapes of the design (9 original + 3 new middle ones).
/// floatY = small up/down movement (calm, like the original design).
const _shapes = <ShapeSpec>[
  // ---- top ----
  ShapeSpec(left: 32, top: 74, width: 101, height: 72, color: kPeach, angle: -14, stripe: true, floatY: 8, phase: 0.0),
  ShapeSpec(left: 216, top: 48, width: 92, height: 92, color: kBlueLight, isCircle: true, floatY: 6, speed: 0.8, phase: 0.3),
  ShapeSpec(left: 161, top: 189, width: 130, height: 20, color: kPeachDeep, radius: 10, angle: -8, floatX: 6, floatY: 3, phase: 0.6),
  ShapeSpec(left: 43, top: 224, width: 52, height: 52, color: Colors.transparent, angle: 12, floatY: 5, speed: 1.2, phase: 0.15, child: _QrCluster()),
  ShapeSpec(left: 291, top: 240, width: 84, height: 84, color: kBlueLighter, radius: 17, angle: 20, floatY: 7, phase: 0.45),
  ShapeSpec(left: 288, top: 154, width: 40, height: 40, color: Colors.transparent, angle: 10, floatY: 9, speed: 1.3, phase: 0.8,
      child: Icon(Icons.location_on_outlined, size: 40, color: kPin)),

  // ---- NEW: middle (at the screen edges, never behind the logo/text) ----
  ShapeSpec(left: 18, top: 322, width: 34, height: 34, color: kPeachDeep, isCircle: true, floatY: 5, speed: 1.1, phase: 0.35, opacity: 0.85),
  ShapeSpec(left: 302, top: 420, width: 40, height: 40, color: kBlueLighter, radius: 10, angle: -14, floatY: 6, speed: 0.9, phase: 0.65, opacity: 0.85),
  ShapeSpec(left: 14, top: 500, width: 64, height: 13, color: kPeachDeep, radius: 7, angle: 10, floatX: 5, floatY: 2, phase: 0.9, opacity: 0.85),

  // ---- bottom ----
  ShapeSpec(left: -20, top: 576, width: 112, height: 81, color: kPeachDeep, angle: 16, stripe: true, floatY: 7, speed: 0.9, phase: 0.5),
  ShapeSpec(left: 259, top: 563, width: 63, height: 63, color: kPeach, isCircle: true, floatY: 6, speed: 1.1, phase: 0.2),
  ShapeSpec(left: 133, top: 621, width: 101, height: 17, color: kBlueLight, radius: 9, angle: 6, floatX: 5, floatY: 3, phase: 0.7),
];

// =====================================================================
// 4) THE ANIMATED BACKGROUND (StatefulWidget)
// =====================================================================

/// STATEFUL because it owns AnimationControllers (objects that keep
/// changing over time).
class FloatingShapesBackground extends StatefulWidget {
  const FloatingShapesBackground({super.key});

  @override
  State<FloatingShapesBackground> createState() =>
      _FloatingShapesBackgroundState();
}

/// `with TickerProviderStateMixin` = a MIXIN that adds a "ticker"
/// (a clock that ticks every frame). AnimationControllers need it
/// (`vsync: this`). It also pauses animations when the screen is hidden.
class _FloatingShapesBackgroundState extends State<FloatingShapesBackground>
    with TickerProviderStateMixin {
  // AnimationController = produces a value 0.0 → 1.0 over a duration.
  // `late` = created the first time it's used (it needs `this` for vsync).
  // `..repeat()` = CASCADE: create it, call repeat() on it, keep the controller.

  // 1) Float: loops forever, one slow cycle every 6 s (calm movement).
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // 2) Intro: plays ONCE (1.4 s) when the page opens → shapes gently
  //    fade in one after another (no "pop" in the user's face).
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  // ACCESSIBILITY: if the user turned on "Remove animations" in the phone
  // settings, we keep the shapes still.
  // didChangeDependencies() runs after initState and whenever things the
  // widget depends on (like MediaQuery) change — the right place to read it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _float.stop();      // no floating
      _intro.value = 1.0; // show shapes immediately, no pop-in
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  // dispose() runs when the widget leaves the screen: STOP the controllers,
  // or they keep ticking in the background (memory leak).
  // Rule: clean up our things first, super.dispose() LAST.
  @override
  void dispose() {
    _float.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder tells us the real available size (the phone screen).
    return LayoutBuilder(
      builder: (context, size) {
        // Scale factors from the 360 x 800 Figma design to the real phone.
        final k = size.maxWidth / 360;   // sizes + left positions
        final ky = size.maxHeight / 800; // top positions

        // AnimatedBuilder rebuilds ONLY this part on every tick (60x / s),
        // not the logo/texts above → efficient.
        return AnimatedBuilder(
          animation: Listenable.merge([_float, _intro]),
          builder: (context, _) {
            final t = _float.value; // 0 → 1, repeating
            return Stack(
              clipBehavior: Clip.hardEdge, // cut shapes outside the screen
              children: [
                // collection for: one widget per shape in the list
                for (var i = 0; i < _shapes.length; i++)
                  _buildShape(_shapes[i], i, t, k, ky),
              ],
            );
          },
        );
      },
    );
  }

  /// Builds ONE shape at its current animated position.
  Widget _buildShape(ShapeSpec s, int index, double t, double k, double ky) {
    // ---- 1) Floating: a sine wave (smooth -1 → 1 → -1) ----
    final wave = 2 * math.pi * (t * s.speed + s.phase);
    final dx = math.sin(wave) * s.floatX;
    final dy = math.sin(wave) * s.floatY;

    // ---- 2) Intro: each shape starts a little after the previous one ----
    final start = (index * 0.04).clamp(0.0, 0.5);
    // easeOutCubic = starts moving, then slows down softly at the end,
    // with NO overshoot → a smooth, calm appearance.
    final introT = Curves.easeOutCubic.transform(
      ((_intro.value - start) / (1 - start)).clamp(0.0, 1.0),
    );

    // ---- 3) The shape itself ----
    Widget shape = Container(
      width: s.width * k,
      height: s.height * k,
      // ternary: condition ? ifTrue : ifFalse
      decoration: s.child != null
          ? null
          : BoxDecoration(
              color: s.color,
              shape: s.isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius:
                  s.isCircle ? null : BorderRadius.circular(s.radius * k),
            ),
      // `??` = if the left side is null, use the right side.
      child: s.child ??
          (s.stripe
              ? Align(
                  // FractionallySizedBox = size as a FRACTION of the parent
                  // (16% wide, full height) → vertical "tape" line.
                  child: FractionallySizedBox(
                    widthFactor: 0.16,
                    heightFactor: 1,
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                )
              : null),
    );
    // FittedBox scales custom children (QR / pin) to the shape's size.
    if (s.child != null) shape = FittedBox(child: shape);

    // ---- 4) Place it + fade + scale + rotate ----
    return Positioned(
      left: s.left * k + dx,
      top: s.top * ky + dy,
      child: Opacity(
        // intro fade × the shape's own opacity (0.85 for the middle ones)
        opacity: introT * s.opacity,
        child: Transform.scale(
          scale: 0.94 + 0.06 * introT, // tiny grow 94% → 100% (subtle, not a pop)
          child: Transform.rotate(
            angle: s.angle * math.pi / 180, // degrees → radians
            child: shape,
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// 5) THE SMALL QR PIECE (3 x 3 grid of rounded squares)
// =====================================================================

class _QrCluster extends StatelessWidget {
  const _QrCluster();

  // `static const` = belongs to the CLASS, created once. 1 = filled, 0 = empty.
  static const _pattern = [1, 0, 1, 1, 1, 0, 0, 1, 1];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      // GridView.count = a grid with a fixed number of columns.
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        physics: const NeverScrollableScrollPhysics(), // decoration: no scrolling
        padding: EdgeInsets.zero,
        children: [
          for (final on in _pattern)
            Container(
              decoration: BoxDecoration(
                color: on == 1 ? kQrBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}