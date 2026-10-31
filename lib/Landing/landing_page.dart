Claude


















Landing page · DART
// =====================================================================
// ARAL Inventory – Landing page (Figma screen "W0 · Landing")
// =====================================================================
//
// What this screen does:
//   1. Shows floating decorative shapes in the background (animated).
//   2. Shows the logo, the app name and the slogan in the middle.
//   3. Shows a "Sign in" button at the bottom.
//      (If the user is already logged in, it shows a spinner + "Signing you in…"
//       instead – Figma screen "W0b".)
//
// All positions and sizes come from the Figma design (a 360 x 800 screen)
// and are scaled to the real phone size, so it looks the same on every phone.
// =====================================================================
 
// ---------------------------------------------------------------------
// IMPORTS: bring code from other files / packages into this file.
// ---------------------------------------------------------------------
 
// 'dart:math' is Dart's built-in math library. We need sin() and pi for the
// floating movement. "as math" gives it a short name, so we write math.sin().
import 'dart:math' as math;
 
// Flutter's Material widgets (Scaffold, Text, Container, FilledButton…).
import 'package:flutter/material.dart';
 
// Joud's AdminRouting screen: where "Sign in" goes FOR NOW
// (until we build the Login page).
import 'package:aral_project/Admin/admin_routing.dart';
 
// Joud's theme file. We use AppTheme.primaryColor (deep navy) so our page
// matches the rest of the app. "package:aral_project/..." = a path starting
// from the lib/ folder of our project (aral_project is the name in pubspec.yaml).
import 'package:aral_project/Theme/theme.dart';
 
// ---------------------------------------------------------------------
// COLORS used only on this page (the soft decoration colors).
// `const` = the value is fixed and known BEFORE the app runs,
// so Dart creates it once and reuses it (faster, less memory).
// Color(0xFFF6F1EA): 0xFF = fully opaque, F6F1EA = the hex color.
// ---------------------------------------------------------------------
const kLandingBackground = Color(0xFFF6F1EA); // warm off-white page background
const kTextSecondary = Color(0xFF4A5260);     // grey for the slogan + footer
const kSand = Color(0xFFF3E3CC);              // logo icon color + sand shapes
const kBronze = Color(0xFF9A6B2F);            // spinner color
const kBronzeLight = Color(0xFFE6D3B5);       // "tape" bars + boxes
const kBlueLight = Color(0xFFD6E3F7);         // big circle + small bar
const kBlueLighter = Color(0xFFDCE7F5);       // rounded square
const kQrBlue = Color(0xFFC9D8EE);            // the small QR piece
const kPin = Color(0xFFE2C59E);               // the location pin icon
 
// =====================================================================
// 1) THE PAGE ITSELF
// =====================================================================
 
/// StatelessWidget: this page has NO data that changes by itself.
/// (The animation lives in a separate widget below, which IS stateful.)
class LandingPage extends StatelessWidget {
  // Constructor.
  // `super.key`        → passes the key up to the parent class (StatelessWidget).
  // `this.isCheckingLogin = false` → a NAMED, OPTIONAL parameter with a default
  //                      value. If nobody passes it, it is false.
  const LandingPage({super.key, this.isCheckingLogin = false});
 
  /// true  → show the spinner + "Signing you in…" (user already logged in, W0b)
  /// false → show the "Sign in" button (W0)
  /// `final` = set once in the constructor, never changes after.
  final bool isCheckingLogin;
 
  // @override = we REPLACE the build() method inherited from StatelessWidget.
  // build() describes what the screen looks like. Flutter calls it whenever
  // it needs to draw this widget.
  // `context` = this widget's place in the widget tree (used for Theme.of,
  // Navigator…).
  @override
  Widget build(BuildContext context) {
    // Save the text styles in a variable so we don't repeat Theme.of(context).
    // Theme.of(context) looks UP the tree and finds the theme Joud set in
    // MaterialApp (AppTheme.lightTheme).
    final textTheme = Theme.of(context).textTheme;
 
    // Scaffold = the basic page structure (background, body, app bar…).
    // We don't use an AppBar here: the landing page is full-screen.
    return Scaffold(
      backgroundColor: kLandingBackground,
 
      // Stack = puts widgets ON TOP of each other (like layers).
      //   Layer 1 (bottom): the animated shapes
      //   Layer 2 (top):    the logo, texts and button
      body: Stack(
        children: [
          // ---- Layer 1: background ----
          // Positioned.fill = stretch this child to cover the whole Stack.
          const Positioned.fill(child: FloatingShapesBackground()),
 
          // ---- Layer 2: content ----
          // SafeArea = keeps the content away from the phone's status bar
          // (clock, battery) and the bottom gesture bar.
          SafeArea(
            child: Padding(
              // EdgeInsets.fromLTRB = padding Left, Top, Right, Bottom.
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
 
              // Column = puts its children vertically, one under the other.
              child: Column(
                children: [
                  // Spacer = flexible empty space. flex: 3 above and flex: 4
                  // below means the free space is split 3 : 4, which places
                  // the logo a little ABOVE the center (like the Figma design).
                  const Spacer(flex: 3),
 
                  // ---- The logo box ----
                  // Container + BoxDecoration = a box with color and rounded corners.
                  // (color goes INSIDE BoxDecoration, never on the Container too.)
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor, // navy from Joud's theme
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      size: 52,
                      color: kSand,
                    ),
                  ),
 
                  // SizedBox with only a height = a fixed vertical gap.
                  const SizedBox(height: 16),
 
                  // ---- App name ----
                  // copyWith = keep the theme's headlineMedium style but change
                  // only the color and the weight.
                  // `?.` = "only call copyWith if headlineMedium is not null"
                  // (null safety).
                  Text(
                    'ARAL Inventory',
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
 
                  // ---- Slogan ----
                  Text(
                    'Scan. Store. Track.',
                    style: textTheme.bodyLarge?.copyWith(color: kTextSecondary),
                  ),
 
                  const Spacer(flex: 4),
 
                  // ---- Bottom part: spinner OR button ----
                  // "collection if" inside a children list:
                  //   if (condition) ...[widgets] else ...[other widgets]
                  // `...` (spread) = add SEVERAL widgets under one condition.
                  if (isCheckingLogin) ...[
                    // Auto sign-in (W0b): a spinning loader + a short message.
                    const CircularProgressIndicator(color: kBronze),
                    const SizedBox(height: 12),
                    const Text(
                      'Signing you in…',
                      style: TextStyle(color: kTextSecondary),
                    ),
                  ] else ...[
                    // Normal case (W0): the Sign in button.
                    // SizedBox makes the button full-width and 52 px tall.
                    SizedBox(
                      width: double.infinity, // as wide as possible
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        // onPressed = the function that runs when tapped.
                        // We pass a FUNCTION (() => …), not its result,
                        // so it runs only on tap.
                        onPressed: () => _goToNextScreen(context),
                        icon: const Icon(Icons.lock),
                        label: const Text('Sign in'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Arab Aluminum Industry Co. · v1.0',
                      style: TextStyle(fontSize: 12, color: kTextSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
 
  /// What happens when "Sign in" is tapped.
  ///
  /// NAVIGATION: screens are a STACK (like plates).
  ///   - Navigator.push            → put a new screen ON TOP (back returns here).
  ///   - Navigator.pushReplacement → REPLACE this screen with the new one,
  ///     so the phone's back button does NOT come back to the landing page.
  ///     That is what we want after signing in.
  ///
  /// MaterialPageRoute = one screen in the stack, with the normal slide animation.
  /// builder: (_) => … = a function that BUILDS the new screen when needed.
  ///   `_` = "I don't need this parameter" (it's a context we don't use).
  ///
  /// The name starts with `_` → PRIVATE: only usable inside this file.
  void _goToNextScreen(BuildContext context) {
    // TODO: when the Login page is ready, go to it instead:
    //   Navigator.push(context,
    //       MaterialPageRoute(builder: (_) => const LoginPage()));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminRouting()),
    );
  }
}
 
// =====================================================================
// 2) THE DATA FOR ONE DECORATIVE SHAPE (a plain Dart class, NOT a widget)
// =====================================================================
 
/// A CLASS is a blueprint. Each shape on the screen is one OBJECT made
/// from this blueprint, with its own position, size, color and movement.
/// Values are in "design pixels" (the Figma screen is 360 wide, 800 tall).
class ShapeSpec {
  // Named parameters:
  //   `required` → must be given.
  //   `= value`  → optional, with a default.
  const ShapeSpec({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.color,
    this.radius = 8,       // corner roundness
    this.angle = 0,        // rotation in degrees
    this.stripe = false,   // white "tape" line in the middle (box look)
    this.isCircle = false,
    this.child,            // optional custom content (QR piece, pin icon)
    this.floatY = 6,       // how far it moves up/down (px)
    this.floatX = 0,       // how far it moves left/right (px)
    this.speed = 1.0,      // 1.0 = one full float cycle every 6 seconds
    this.phase = 0.0,      // 0..1 start offset, so shapes don't move together
  });
 
  // `final` fields: an object's values never change after it is created.
  final double left, top, width, height, radius, angle, floatY, floatX, speed, phase;
  final Color color;
  final bool stripe, isCircle;
 
  // `Widget?` = NULLABLE: it can hold a widget OR be null (no child).
  final Widget? child;
}
 
/// The 9 shapes of the design, as a LIST of ShapeSpec objects.
/// `<ShapeSpec>[ … ]` = a List that can only hold ShapeSpec objects.
/// `const` = the whole list is fixed and built before the app runs.
/// The name starts with `_` → private to this file.
const _shapes = <ShapeSpec>[
  // top-left sand box with tape
  ShapeSpec(left: 32, top: 74, width: 101, height: 72, color: kSand, angle: -14, stripe: true, floatY: 8, phase: 0.0),
  // big blue circle (top-right)
  ShapeSpec(left: 216, top: 48, width: 92, height: 92, color: kBlueLight, isCircle: true, floatY: 6, speed: 0.8, phase: 0.3),
  // bronze bar (moves left/right a little)
  ShapeSpec(left: 161, top: 189, width: 130, height: 20, color: kBronzeLight, radius: 10, angle: -8, floatX: 6, floatY: 3, phase: 0.6),
  // small QR piece
  ShapeSpec(left: 43, top: 224, width: 52, height: 52, color: Colors.transparent, angle: 12, floatY: 5, speed: 1.2, phase: 0.15, child: _QrCluster()),
  // rounded blue square (half outside the right edge)
  ShapeSpec(left: 291, top: 240, width: 84, height: 84, color: kBlueLighter, radius: 17, angle: 20, floatY: 7, phase: 0.45),
  // location pin
  ShapeSpec(left: 288, top: 154, width: 40, height: 40, color: Colors.transparent, angle: 10, floatY: 9, speed: 1.3, phase: 0.8,
      child: Icon(Icons.location_on_outlined, size: 40, color: kPin)),
  // bottom-left bronze box with tape (half outside the left edge)
  ShapeSpec(left: -20, top: 576, width: 112, height: 81, color: kBronzeLight, angle: 16, stripe: true, floatY: 7, speed: 0.9, phase: 0.5),
  // small sand circle (bottom-right)
  ShapeSpec(left: 259, top: 563, width: 63, height: 63, color: kSand, isCircle: true, floatY: 6, speed: 1.1, phase: 0.2),
  // small blue bar (bottom)
  ShapeSpec(left: 133, top: 621, width: 101, height: 17, color: kBlueLight, radius: 9, angle: 6, floatX: 5, floatY: 3, phase: 0.7),
];
 
// =====================================================================
// 3) THE ANIMATED BACKGROUND (a StatefulWidget)
// =====================================================================
 
/// Why STATEFUL? Because it owns AnimationControllers: objects that keep
/// running and changing over time. A StatefulWidget is TWO classes:
///   - this class (the widget, which is immutable), and
///   - its State class (below), which holds the changing things.
class FloatingShapesBackground extends StatefulWidget {
  const FloatingShapesBackground({super.key});
 
  // createState() creates the State object that Flutter keeps alive
  // while this widget is on screen.
  @override
  State<FloatingShapesBackground> createState() =>
      _FloatingShapesBackgroundState();
}
 
/// `with TickerProviderStateMixin` = a MIXIN (extra abilities added to a class).
/// It gives this State a "ticker": a clock that ticks every frame
/// (about 60 times per second). AnimationControllers need it (`vsync: this`),
/// and it also pauses the animation when the screen is not visible
/// (saves battery).
class _FloatingShapesBackgroundState extends State<FloatingShapesBackground>
    with TickerProviderStateMixin {
  // AnimationController = produces a value from 0.0 to 1.0 over a duration.
  //
  // `late` = "this will be created later, the first time it is used"
  // (we need `this` for vsync, which isn't available before the object exists).
  //
  // `..` = CASCADE operator: create the controller, call .repeat() on it,
  // and still store the CONTROLLER (not the result of repeat()) in the variable.
 
  // 1) Float controller: loops forever (0 → 1, 0 → 1, …) every 6 seconds.
  //    Drives the gentle up/down movement.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
 
  // 2) Intro controller: plays ONCE (0 → 1 in 0.8 s) when the page opens.
  //    Drives the "shapes pop in" effect.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();
 
  // dispose() runs when this widget is removed from the screen.
  // We MUST stop and free the controllers, or they keep ticking
  // in the background (memory leak).
  // Rule: clean up OUR things first, then call super.dispose() LAST.
  @override
  void dispose() {
    _float.dispose();
    _intro.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    // LayoutBuilder tells us how much space we have (the real phone size).
    // `size.maxWidth` / `size.maxHeight` = the available width and height.
    return LayoutBuilder(
      builder: (context, size) {
        // Scale factors: Figma is 360 x 800. On a 412-wide phone,
        // k = 412 / 360 = 1.14, so every shape becomes 14% bigger.
        final k = size.maxWidth / 360;   // horizontal scale (sizes + left)
        final ky = size.maxHeight / 800; // vertical scale (top positions)
 
        // AnimatedBuilder rebuilds ONLY its builder on every animation tick,
        // not the whole page. That's efficient: the logo and button above
        // do NOT rebuild 60 times a second.
        // Listenable.merge = listen to BOTH controllers at once.
        return AnimatedBuilder(
          animation: Listenable.merge([_float, _intro]),
          builder: (context, _) {
            final t = _float.value; // current float value: 0 → 1, repeating
 
            return Stack(
              // Clip.hardEdge = cut off shapes that go outside the screen
              // (two shapes are half outside on purpose).
              clipBehavior: Clip.hardEdge,
              children: [
                // "collection for": build one widget for every shape in the
                // list. `i` is the index (0, 1, 2…), used to delay each
                // shape's intro.
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
  ///   s  = the shape's data
  ///   index = its position in the list (for the staggered intro)
  ///   t  = float progress (0..1)
  ///   k, ky = scale factors
  Widget _buildShape(ShapeSpec s, int index, double t, double k, double ky) {
    // ---- 1) Floating movement: a sine wave ----
    // sin() goes smoothly -1 → 0 → 1 → 0 → -1, which is perfect for floating.
    // 2π = one full wave. Each shape has its own speed and phase,
    // so they don't all move together.
    final wave = 2 * math.pi * (t * s.speed + s.phase);
    final dx = math.sin(wave) * s.floatX; // left/right offset in px
    final dy = math.sin(wave) * s.floatY; // up/down offset in px
 
    // ---- 2) Intro: each shape starts slightly after the previous one ----
    // shape 0 starts at 0%, shape 1 at 6%, shape 2 at 12%… (max 60%).
    // .clamp(a, b) = keep the value between a and b.
    final start = (index * 0.06).clamp(0.0, 0.6);
 
    // Convert the intro controller's value into THIS shape's own 0..1 progress,
    // then apply a curve. easeOutBack = moves fast, slightly OVERSHOOTS,
    // and settles, which gives a small "pop" feeling.
    final introT = Curves.easeOutBack.transform(
      ((_intro.value - start) / (1 - start)).clamp(0.0, 1.0),
    );
 
    // ---- 3) The shape itself ----
    Widget shape = Container(
      width: s.width * k,
      height: s.height * k,
      // Ternary operator: condition ? valueIfTrue : valueIfFalse
      // If the shape has a custom child (QR / pin), no colored box behind it.
      decoration: s.child != null
          ? null
          : BoxDecoration(
              color: s.color,
              shape: s.isCircle ? BoxShape.circle : BoxShape.rectangle,
              // A circle can't have a borderRadius, so null for circles.
              borderRadius:
                  s.isCircle ? null : BorderRadius.circular(s.radius * k),
            ),
      // `??` = "if the left side is null, use the right side".
      // So: use the custom child if there is one; otherwise maybe a tape stripe.
      child: s.child ??
          (s.stripe
              ? Align(
                  alignment: Alignment.center,
                  // FractionallySizedBox = size as a FRACTION of the parent:
                  // 16% of the box width, full height, giving a vertical tape line.
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
 
    // FittedBox scales the custom child (QR / pin) to fit the shape's size.
    if (s.child != null) shape = FittedBox(child: shape);
 
    // ---- 4) Place it, and apply fade + scale + rotation ----
    // Positioned = an exact position inside a Stack (left / top in px).
    return Positioned(
      left: s.left * k + dx,
      top: s.top * ky + dy,
      child: Opacity(
        // fade in: 0 = invisible → 1 = fully visible
        // (clamp, because easeOutBack can go slightly above 1)
        opacity: introT.clamp(0.0, 1.0),
        child: Transform.scale(
          // grow from 60% → 100% size during the intro
          scale: 0.6 + 0.4 * introT,
          child: Transform.rotate(
            // Transform.rotate uses RADIANS: degrees × π / 180
            angle: s.angle * math.pi / 180,
            child: shape,
          ),
        ),
      ),
    );
  }
}
 
// =====================================================================
// 4) THE SMALL QR PIECE (a 3 x 3 grid of rounded squares)
// =====================================================================
 
/// A small reusable StatelessWidget: nothing changes inside it.
class _QrCluster extends StatelessWidget {
  const _QrCluster();
 
  // `static const` = belongs to the CLASS (shared, created once),
  // not to each object. 1 = filled square, 0 = empty.
  static const _pattern = [1, 0, 1, 1, 1, 0, 0, 1, 1];
 
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      // GridView.count = a grid with a fixed number of columns.
      child: GridView.count(
        crossAxisCount: 3,       // 3 columns → 9 items = 3 rows
        mainAxisSpacing: 4,      // vertical gap
        crossAxisSpacing: 4,     // horizontal gap
        // The grid must NOT scroll (it's decoration).
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          // collection for: one small square per pattern value
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
 
Claude finished the response
