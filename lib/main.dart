import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

void main() {
  runApp(const CurviGridApp());
}

class CurviGridApp extends StatelessWidget {
  const CurviGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CurviGrid',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF050510), // Deep space black
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF00FF),
          surface: Color(0xFF1E1E28),
        ),
      ),
      home: const CurviGridHomePage(),
    );
  }
}

class CurviGridHomePage extends StatefulWidget {
  const CurviGridHomePage({super.key});

  @override
  State<CurviGridHomePage> createState() => _CurviGridHomePageState();
}

class _CurviGridHomePageState extends State<CurviGridHomePage> {
  // --- View State ---
  double yaw = 0.0;
  double pitch = 0.0;
  double _baseYaw = 0.0;
  double _basePitch = 0.0;
  
  double fov = 180.0; // field of view in degrees
  double _baseFov = 180.0;

  // --- Grid Parameters ---
  bool showV = true;     // Vertical (Y)
  bool showH = true;     // Horizontal (X)
  bool showD = true;     // Depth (Z)
  bool showDiag = true;  // Diagonal (45deg in XZ)
  bool showP = false;    // Points (Vanishing Poles)

  double densityV = 4.0;
  double densityH = 4.0;
  double densityD = 4.0;
  double densityDiag = 4.0;

  bool showEquator = true;
  bool showMeridian = false;
  bool showHorizon = false;

  // Cache object that pre-generates and holds the raw 3D lines
  late GridGeometryLayer layerManager;

  @override
  void initState() {
    super.initState();
    layerManager = GridGeometryLayer();
    _regenerateGrid();
  }

  void _regenerateGrid() {
    // We execute line generation synchronously; the math optimizations 
    // keep it well within bounds to prevent UI thread freezing.
    layerManager.generate(densityV, densityH, densityD, densityDiag);
  }

  void resetView() {
    HapticFeedback.selectionClick();
    setState(() {
      yaw = 0.0;
      pitch = 0.0;
      fov = 180.0;
    });
  }

  void randomizeDensities() {
    HapticFeedback.selectionClick();
    final rand = math.Random();
    setState(() {
      // Pick random densities between 1.0 and 8.0
      densityV = 1.0 + rand.nextDouble() * 7.0;
      densityH = 1.0 + rand.nextDouble() * 7.0;
      densityD = 1.0 + rand.nextDouble() * 7.0;
      densityDiag = 1.0 + rand.nextDouble() * 7.0;
      _regenerateGrid();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sublayer 3: Permanent Control Sidebar
          Container(
            width: 300,
            child: _buildControlPanel(),
          ),
          
          // Sublayer 1: Deep space grid canvas & Touch handling
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onScaleStart: (details) {
                      _baseFov = fov;
                      _baseYaw = yaw;
                      _basePitch = pitch;
                    },
                    onScaleUpdate: (details) {
                      setState(() {
                        // Pan gesture
                        if (details.pointerCount == 1 || details.scale == 1.0) {
                          yaw = _baseYaw - details.focalPointDelta.dx * 0.005;
                          pitch = _basePitch + details.focalPointDelta.dy * 0.005;
                          pitch = pitch.clamp(-math.pi / 2 + 0.01, math.pi / 2 - 0.01);
                        } 
                        // Pinch to zoom (FOV manipulation)
                        else {
                          fov = (_baseFov / details.scale).clamp(10.0, 360.0);
                        }
                      });
                    },
                    onDoubleTap: resetView,
                    child: CustomPaint(
                      painter: CurvilinearPainter(
                        linesV: layerManager.linesV,
                        linesH: layerManager.linesH,
                        linesD: layerManager.linesD,
                        linesDiag: layerManager.linesDiag,
                        showV: showV,
                        showH: showH,
                        showD: showD,
                        showDiag: showDiag,
                        showP: showP,
                        yaw: yaw,
                        pitch: pitch,
                        fov: fov,
                        showEquator: showEquator,
                        showMeridian: showMeridian,
                        showHorizon: showHorizon,
                      ),
                      child: Container(),
                    ),
                  ),
                ),
                
                // Gnomon
                Positioned(
                  top: 40,
                  right: 20,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        yaw -= details.delta.dx * 0.01;
                        pitch += details.delta.dy * 0.01;
                        pitch = pitch.clamp(-math.pi / 2 + 0.01, math.pi / 2 - 0.01);
                      });
                    },
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: CustomPaint(
                        painter: GnomonPainter(yaw: yaw, pitch: pitch),
                      ),
                    ),
                  ),
                ),
                
                // Info Button
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    icon: const Icon(Icons.menu_book_rounded, color: Colors.white70),
                    onPressed: () { 
                      HapticFeedback.lightImpact();
                      _showInfoScreen(context);
                    },
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xD012121A),
        border: Border(right: BorderSide(color: Colors.white10)),
        boxShadow: [BoxShadow(color: Color(0xAA000000), blurRadius: 40, offset: Offset(5, 0))],
      ),
      padding: const EdgeInsets.fromLTRB(15, 60, 15, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONTROLS', style: TextStyle(letterSpacing: 4, fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildMasterToggle(),
          const Divider(color: Colors.white10, height: 30),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildFamilyControl('Vertical', const Color(0xFF40E9FF), showV, densityV, (v) => setState(() => showV = v), (v) => densityV = v),
                  _buildFamilyControl('Horizontal', const Color(0xFFFF40FF), showH, densityH, (v) => setState(() => showH = v), (v) => densityH = v),
                  _buildFamilyControl('Depth', const Color(0xFFFFE040), showD, densityD, (v) => setState(() => showD = v), (v) => densityD = v),
                  _buildFamilyControl('Diagonal', const Color(0xFF40FF70), showDiag, densityDiag, (v) => setState(() => showDiag = v), (v) => densityDiag = v),
                  const Divider(color: Colors.white10, height: 30),
                  _buildToggleRow('Vanishing Points', Icons.lens, Colors.white70, showP, (v) => setState(() => showP = v)),

                  const SizedBox(height: 25),
                  const Text('REFERENCE CIRCLES', style: TextStyle(letterSpacing: 2, fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildToggleRow('Equator (BOLD)', Icons.circle_outlined, Colors.white, showEquator, (v) => setState(() => showEquator = v)),
                  _buildToggleRow('Prime Meridian', Icons.unfold_more, Colors.white70, showMeridian, (v) => setState(() => showMeridian = v)),
                  _buildToggleRow('Horizon', Icons.unfold_less, Colors.white70, showHorizon, (v) => setState(() => showHorizon = v)),

                  const SizedBox(height: 30),
                  _buildFOVControl(),
                  const SizedBox(height: 30),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterToggle() {
    bool allOn = showV && showH && showD && showDiag;
    return InkWell(
      onTap: () {
        setState(() {
          bool target = !allOn;
          showV = showH = showD = showDiag = target;
        });
        HapticFeedback.mediumImpact();
      },
      child: Row(
        children: [
          Icon(allOn ? Icons.visibility : Icons.visibility_off, color: Colors.white70, size: 20),
          const SizedBox(width: 15),
          const Expanded(child: Text('ALL GRIDS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Switch(
            value: allOn,
            onChanged: (v) {
              setState(() {
                showV = showH = showD = showDiag = v;
              });
            },
            activeColor: const Color(0xFF00E5FF),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyControl(String title, Color color, bool isVisible, double density, Function(bool) toggle, Function(double) updateDensity) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 4, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showDensityInputDialog(title, density, (v) {
                    setState(() {
                      updateDensity(v);
                      _regenerateGrid();
                    });
                  }),
                  child: Row(
                    children: [
                      Text(title, style: TextStyle(color: isVisible ? Colors.white : Colors.white38, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text(
                        '(${density.toStringAsFixed(1)})',
                        style: TextStyle(color: isVisible ? color.withValues(alpha: 0.8) : Colors.white24, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isVisible,
                  onChanged: (v) => setState(() => toggle(v)),
                  activeColor: color,
                ),
              ),
            ],
          ),
          if (isVisible)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: density,
                min: 0.1,
                max: 10.0,
                activeColor: color,
                inactiveColor: color.withValues(alpha: 0.1),
                onChangeEnd: (v) { updateDensity(v); _regenerateGrid(); setState((){}); },
                onChanged: (v) { setState(() => updateDensity(v)); },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, IconData icon, Color color, bool value, Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: value ? color : Colors.white24, size: 20),
            const SizedBox(width: 15),
            Expanded(child: Text(title, style: TextStyle(color: value ? Colors.white : Colors.white38))),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: (v) => onChanged(v),
                activeColor: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFOVControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FIELD OF VIEW (CONE ANGLE)', style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(Icons.remove_red_eye_outlined, size: 16, color: Colors.white38),
            Expanded(
              child: Slider(
                value: fov,
                min: 10,
                max: 360,
                activeColor: fov > 180 ? const Color(0xFF00E5FF) : Colors.white60,
                onChanged: (v) => setState(() => fov = v),
              ),
            ),
            Text('${fov.toInt()}°', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        if (fov > 180) 
          const Padding(
            padding: EdgeInsets.only(left: 30),
            child: Text('FULL-SPHERE MODE ACTIVE', style: TextStyle(fontSize: 9, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: randomizeDensities,
            style: TextButton.styleFrom(foregroundColor: Colors.white54),
            child: const Text('RANDOMIZE'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: resetView,
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white10), foregroundColor: Colors.white),
            child: const Text('RESET'),
          ),
        ),
      ],
    );
  }

  void _showDensityInputDialog(String title, double current, Function(double) onSubmitted) {
    final controller = TextEditingController(text: current.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: Text('Input $title Spacing', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Value (0.1 - 20.0)',
            labelStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () {
              double? val = double.tryParse(controller.text);
              if (val != null && val >= 0.1 && val <= 20.0) {
                onSubmitted(val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('APPLY', style: TextStyle(color: Color(0xFF00E5FF))),
          ),
        ],
      ),
    );
  }

  void _showInfoScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xD012121A),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.explore, size: 50, color: Colors.cyan),
                const SizedBox(height: 20),
                const Text('Curvilinear Perspective', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 15),
                const Text(
                  "Flocon & Barre's Curvilinear Perspective (1968) solves the distortion problems "
                  "found in standard linear perspective at high field-of-views.\n\n"
                  "This application expands the geometry to a Full-Sphere 360° projection. "
                  "Imagine a visual cone expanding from a point: at 180°, it covers the front hemisphere. "
                  "Beyond 180°, it 'unzips' the space behind you, eventually packing the entire 360° "
                  "universe into this circular disk. The center is your direct line of sight; "
                  "the edge of the circle is the point exactly behind you.",
                  style: TextStyle(color: Colors.white70, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                  child: const Text('Close'),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(ctx).pop();
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CORE MATHEMATICS & GEOMETRY 
// ============================================================================

/// Handles pre-computing the 3D grid line parametric trajectories into raw
/// Float32Lists to bypass continuous object allocation during frame updates.
class GridGeometryLayer {
  List<Float32List> linesV = [];
  List<Float32List> linesH = [];
  List<Float32List> linesD = [];
  List<Float32List> linesDiag = [];

  void generate(double dV, double dH, double dD, double dDiag) {
    linesV = _generateLines(dV, 0);
    linesH = _generateLines(dH, 1);
    linesD = _generateLines(dD, 2);
    linesDiag = _generateLines(dDiag, 3);
  }

  List<Float32List> _generateLines(double density, int type) {
    List<Float32List> lines = [];
    
    // Performance optimization: prevent 10.0x zoom-ins from overloading RAM 
    // restrict calculation radius linearly relative to spacing so we always yield 
    // roughly the same amount of lines but tightly clustered near eye.
    double maxBoxBoundary = math.min(50.0, density * 20.0); 
    
    // We sample straight 3D parameterized tracks.
    // Length: -50 to 50 world units. 200 points to keep bezier paths butter smooth.
    // Length: infinite mapping using tangent. 300 points for heavy detail at horizon.
    int tSteps = 300;
    double tRange = 1.0;
    double tStep = (2.0 * tRange) / tSteps;

    double projectT(double s) {
      // Maps [-1, 1] to effectively [-500, 500] with high density near viewer
      return 15.0 * math.tan(s * (math.pi / 2.05));
    }

    if (type == 0) { // Vertical (parallel to world Y)
      int halfCount = (maxBoxBoundary / density).floor();
      for (int i = -halfCount; i <= halfCount; i++) {
        double x = i * density;
        for (int j = -halfCount; j <= halfCount; j++) {
          double z = j * density;
          var list = Float32List((tSteps + 1) * 3);
          for(int k = 0; k <= tSteps; k++) {
            double ty = projectT(-tRange + k * tStep);
            list[k*3] = x;
            list[k*3+1] = ty;
            list[k*3+2] = z;
          }
          lines.add(list);
        }
      }
    } else if (type == 1) { // Horizontal (parallel to world X)
      int halfCount = (maxBoxBoundary / density).floor();
      for (int i = -halfCount; i <= halfCount; i++) {
        double y = i * density;
        for (int j = -halfCount; j <= halfCount; j++) {
          double z = j * density;
          var list = Float32List((tSteps + 1) * 3);
          for(int k = 0; k <= tSteps; k++) {
            double tx = projectT(-tRange + k * tStep);
            list[k*3] = tx;
            list[k*3+1] = y;
            list[k*3+2] = z;
          }
          lines.add(list);
        }
      }
    } else if (type == 2) { // Depth (parallel to world Z)
      int halfCount = (maxBoxBoundary / density).floor();
      for (int i = -halfCount; i <= halfCount; i++) {
        double x = i * density;
        for (int j = -halfCount; j <= halfCount; j++) {
          double y = j * density;
          var list = Float32List((tSteps + 1) * 3);
          for(int k = 0; k <= tSteps; k++) {
            double tz = projectT(-tRange + k * tStep);
            list[k*3] = x;
            list[k*3+1] = y;
            list[k*3+2] = tz;
          }
          lines.add(list);
        }
      }
    } else if (type == 3) { // Diagonal 45° families inside XZ planes
      double diagSpacing = density * math.sqrt2;
      double diagBound = math.min(50.0 * math.sqrt2, diagSpacing * 20.0);
      double invSqrt2 = 1.0 / math.sqrt2;

      int halfCountDiag = (diagBound / diagSpacing).floor();
      int halfCountY = (maxBoxBoundary / density).floor();

      // First diagonal group: direction (1, 0, 1) normalized
      for (int i = -halfCountDiag; i <= halfCountDiag; i++) {
        double m = i * diagSpacing;
        for (int j = -halfCountY; j <= halfCountY; j++) {
          double y = j * density;
          var list = Float32List((tSteps + 1) * 3);
          for(int k = 0; k <= tSteps; k++) {
            double t = projectT(-tRange + k * tStep); // Removed math.sqrt2 extra factor here to keep t consistent
            list[k*3] = m + t * invSqrt2;
            list[k*3+1] = y;
            list[k*3+2] = t * invSqrt2;
          }
          lines.add(list);
        }
      }
      // Second diagonal group: direction (1, 0, -1) normalized
      for (int i = -halfCountDiag; i <= halfCountDiag; i++) {
        double m = i * diagSpacing;
        for (int j = -halfCountY; j <= halfCountY; j++) {
          double y = j * density;
          var list = Float32List((tSteps + 1) * 3);
          for(int k = 0; k <= tSteps; k++) {
            double t = projectT(-tRange + k * tStep);
            list[k*3] = m + t * invSqrt2;
            list[k*3+1] = y;
            list[k*3+2] = -t * invSqrt2;
          }
          lines.add(list);
        }
      }
    }
    return lines;
  }
}

/// Renders the complex 2D curvilinear projections of the pre-computed 3D families.
class CurvilinearPainter extends CustomPainter {
  final List<Float32List> linesV, linesH, linesD, linesDiag;
  final bool showV, showH, showD, showDiag, showP;
  final double yaw, pitch, fov;
  final bool showEquator, showMeridian, showHorizon;

  CurvilinearPainter({
    required this.linesV,
    required this.linesH,
    required this.linesD,
    required this.linesDiag,
    required this.showV,
    required this.showH,
    required this.showD,
    required this.showDiag,
    required this.showP,
    required this.yaw,
    required this.pitch,
    required this.fov,
    required this.showEquator,
    required this.showMeridian,
    required this.showHorizon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Offset center = Offset(size.width / 2, size.height / 2);
    // Base radius is bounded by whichever screen edge is smallest
    double radius = math.min(size.width, size.height) / 2.0;

    // --- Create 3D Orthonormal Right-Handed Viewer Basis ---
    vm.Vector3 vDir = vm.Vector3(
      math.sin(yaw) * math.cos(pitch),
      math.sin(pitch),
      math.cos(yaw) * math.cos(pitch)
    ).normalized();
    
    vm.Vector3 worldUp = vm.Vector3(0, 1, 0);
    vm.Vector3 right = worldUp.cross(vDir);
    if (right.length2 < 0.001) right = vm.Vector3(1, 0, 0); // singularity handling at zenith/nadir
    else right.normalize();
    vm.Vector3 trueUp = vDir.cross(right).normalized();

    // Map Max Theta boundaries (hemispherical limits inside the view frustum)
    double maxTheta = (fov / 2.0) * (math.pi / 180.0);

    if (showV) _drawFamily(canvas, linesV, const Color(0xFF40E9FF), center, radius, maxTheta, vDir, right, trueUp);
    if (showH) _drawFamily(canvas, linesH, const Color(0xFFFF40FF), center, radius, maxTheta, vDir, right, trueUp);
    if (showD) _drawFamily(canvas, linesD, const Color(0xFFFFE040), center, radius, maxTheta, vDir, right, trueUp);
    if (showDiag) _drawFamily(canvas, linesDiag, const Color(0xFF40FF70), center, radius, maxTheta, vDir, right, trueUp);

    _drawReferenceCircles(canvas, center, radius, maxTheta, vDir, right, trueUp);

    if (showP) {
      // Directions for primary axes and diagonal family
      _drawVanishingPoints(canvas, [vm.Vector3(0, 1, 0), vm.Vector3(0, -1, 0)], const Color(0xFF40E9FF), center, radius, maxTheta, vDir, right, trueUp);
      _drawVanishingPoints(canvas, [vm.Vector3(1, 0, 0), vm.Vector3(-1, 0, 0)], const Color(0xFFFF40FF), center, radius, maxTheta, vDir, right, trueUp);
      _drawVanishingPoints(canvas, [vm.Vector3(0, 0, 1), vm.Vector3(0, 0, -1)], const Color(0xFFFFE040), center, radius, maxTheta, vDir, right, trueUp);
      
      double invSqrt2 = 1.0 / math.sqrt2;
      _drawVanishingPoints(canvas, [
        vm.Vector3(invSqrt2, 0, invSqrt2), vm.Vector3(-invSqrt2, 0, -invSqrt2),
        vm.Vector3(invSqrt2, 0, -invSqrt2), vm.Vector3(-invSqrt2, 0, invSqrt2),
      ], const Color(0xFF40FF70), center, radius, maxTheta, vDir, right, trueUp);
    }
  }

  void _drawReferenceCircles(Canvas canvas, Offset center, double radius, double maxTheta, vm.Vector3 vDir, vm.Vector3 right, vm.Vector3 trueUp) {
    // Equator: Plane perpendicular to gaze (divides Front/Back) 
    if (showEquator) {
      _drawGreatCircle(canvas, vDir, right, trueUp, right, trueUp, center, radius, maxTheta, Colors.white, 3.0);
    }
    // Prime Meridian: Vertical plane through gaze (divides Left/Right)
    if (showMeridian) {
      _drawGreatCircle(canvas, right, vDir, trueUp, right, trueUp, center, radius, maxTheta, Colors.white70, 1.5);
    }
    // Horizon: Horizontal plane through gaze (divides Up/Down)
    if (showHorizon) {
      _drawGreatCircle(canvas, trueUp, vDir, right, right, trueUp, center, radius, maxTheta, Colors.white70, 1.5);
    }
  }

  void _drawGreatCircle(Canvas canvas, vm.Vector3 normal, vm.Vector3 e1, vm.Vector3 e2, vm.Vector3 right, vm.Vector3 trueUp, Offset center, double radius, double maxTheta, Color color, double strokeWidth) {
    Path path = Path();
    double rScale = radius / maxTheta;
    bool started = false;
    
    // We sample 120 points for a smooth great circle
    const int segments = 120;
    for (int i = 0; i <= segments; i++) {
       double angle = (i / segments) * 2 * math.pi;
       vm.Vector3 p = (e1 * math.cos(angle)) + (e2 * math.sin(angle));

       // Use the current gaze direction to determine if point is within FOV
       vm.Vector3 currentGaze = vm.Vector3(
         math.sin(yaw) * math.cos(pitch),
         math.sin(pitch),
         math.cos(yaw) * math.cos(pitch)
       ).normalized();
       
       double cosT = p.dot(currentGaze); 
       double theta = math.acos(cosT.clamp(-1.0, 1.0));
       if (theta <= maxTheta + 0.001) {
          // Re-project based on the passed basis vectors
          double prX = p.dot(right);
          double prY = p.dot(trueUp);
          double sinT = math.sqrt(prX*prX + prY*prY);
          
          double r = theta * rScale;
          double factor = (sinT > 0.000001) ? (r / sinT) : 0;
          double outX = center.dx + prX * factor;
          double outY = center.dy - prY * factor;
          
          if (!started) {
            path.moveTo(outX, outY);
            started = true;
          } else {
            path.lineTo(outX, outY);
          }
       } else {
          started = false; 
       }
    }

    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true);
  }

  void _drawVanishingPoints(
      Canvas canvas, List<vm.Vector3> directions, Color color, Offset center, 
      double radius, double maxTheta, 
      vm.Vector3 vDir, vm.Vector3 right, vm.Vector3 trueUp) {
    
    double rScale = radius / maxTheta;
    double cx = center.dx, cy = center.dy;
    
    Paint pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
      
    Paint glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);

    for (var dir in directions) {
      double cosT = dir.dot(vDir);
      // Removed Front-Hemisphere clipping (cosT > 0). 
      // Points with cosT < 0 are behind the camera (theta > 90deg).
      double theta = math.acos(cosT.clamp(-1.0, 1.0));
      
      // Boundary clip: Check if point is inside the user's defined cone (fov/2)
      if (theta > maxTheta + 0.05) continue; 

      double prX = dir.dot(right);
      double prY = dir.dot(trueUp);
      double sinT = math.sqrt(prX*prX + prY*prY);
      
      double r = theta * rScale;
      // At the exact poles, sinT is 0. But for azimuthal projection, we maintain direction stability.
      double factor = (sinT > 0.000001) ? (r / sinT) : 0;
      double outX = cx + prX * factor;
      double outY = cy - prY * factor;

      canvas.drawCircle(Offset(outX, outY), 10, glowPaint);
      canvas.drawCircle(Offset(outX, outY), 4, pointPaint);
      canvas.drawCircle(Offset(outX, outY), 5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1);
    }
  }

  void _drawFamily(
      Canvas canvas, List<Float32List> lines, Color color, Offset center, 
      double radius, double maxTheta, 
      vm.Vector3 vDir, vm.Vector3 right, vm.Vector3 trueUp) {
    
    Path path = Path();
    
    // Caching structural math data
    double rScale = radius / maxTheta;
    double vX = vDir.x, vY = vDir.y, vZ = vDir.z;
    double rX = right.x, rY = right.y, rZ = right.z;
    double uX = trueUp.x, uY = trueUp.y, uZ = trueUp.z;
    double cx = center.dx, cy = center.dy;

    for (int l = 0; l < lines.length; l++) {
      Float32List pts = lines[l];
      bool pathStarted = false;
      
      double lastPx = 0, lastPy = 0, lastPz = 0;
      double lastTheta = 0;
      
      // We leap by 3 (X,Y,Z structure)
      for (int i = 0; i < pts.length; i += 3) {
        double px = pts[i];
        double py = pts[i+1];
        double pz = pts[i+2];

        double distSq = px*px + py*py + pz*pz;
        if (distSq < 0.0001) continue; // Safety against origin singularity
        double dist = math.sqrt(distSq);

        // Cosine to determine angle from gaze
        double cosT = (px*vX + py*vY + pz*vZ) / dist;
        double theta = math.acos(cosT.clamp(-1.0, 1.0));

        if (theta <= maxTheta) {
          double prX = (px*rX + py*rY + pz*rZ) / dist;
          double prY = (px*uX + py*uY + pz*uZ) / dist;
          double sinT = math.sqrt(prX*prX + prY*prY);
          
          double r = theta * rScale;
          double factor = (sinT > 0.000001) ? (r / sinT) : 0;
          double outX = cx + prX * factor;
          double outY = cy - prY * factor;

          if (!pathStarted) {
            // INTERPOLATION FIX: Crossing FOV boundary
            if (i > 0 && lastTheta > maxTheta) { 
              double tInterp = (maxTheta - lastTheta) / (theta - lastTheta);
              double edgePx = lastPx + (px - lastPx) * tInterp;
              double edgePy = lastPy + (py - lastPy) * tInterp;
              double edgePz = lastPz + (pz - lastPz) * tInterp;

              double eDist = math.sqrt(edgePx*edgePx + edgePy*edgePy + edgePz*edgePz);
              double ePrX = (edgePx*rX + edgePy*rY + edgePz*rZ) / eDist;
              double ePrY = (edgePx*uX + edgePy*uY + edgePz*uZ) / eDist;
              double eSinT = math.sqrt(ePrX*ePrX + ePrY*ePrY);
              
              double eR = radius; // Bound on the frame edge
              double eFactor = (eSinT > 0.000001) ? (eR / eSinT) : 0;
              double eOutX = cx + ePrX * eFactor;
              double eOutY = cy - ePrY * eFactor;
              path.moveTo(eOutX, eOutY);
            } else {
              path.moveTo(outX, outY);
            }
            pathStarted = true;
          }
          path.lineTo(outX, outY);
        } else {
          // Outside current FOV boundary
          if (pathStarted) {
            double tInterp = (maxTheta - lastTheta) / (theta - lastTheta);
            double edgePx = lastPx + (px - lastPx) * tInterp;
            double edgePy = lastPy + (py - lastPy) * tInterp;
            double edgePz = lastPz + (pz - lastPz) * tInterp;

            double eDist = math.sqrt(edgePx*edgePx + edgePy*edgePy + edgePz*edgePz);
            double ePrX = (edgePx*rX + edgePy*rY + edgePz*rZ) / eDist;
            double ePrY = (edgePx*uX + edgePy*uY + edgePz*uZ) / eDist;
            double eSinT = math.sqrt(ePrX*ePrX + ePrY*ePrY);
            
            double eR = radius;
            double eFactor = (eSinT > 0.000001) ? (eR / eSinT) : 0;
            double eOutX = cx + ePrX * eFactor;
            double eOutY = cy - ePrY * eFactor;
            path.lineTo(eOutX, eOutY);
            pathStarted = false;
          }
        }
        
        lastPx = px; lastPy = py; lastPz = pz;
        lastTheta = theta;
      }
    }

    // Double-Painting allows simulating luminous volumetric CRT-like curves efficiently.
    Paint corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = color
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.0)
      ..color = color.withValues(alpha: 0.5)
      ..isAntiAlias = true;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant CurvilinearPainter oldDelegate) {
    return oldDelegate.yaw != yaw || oldDelegate.pitch != pitch || oldDelegate.fov != fov ||
           oldDelegate.showV != showV || oldDelegate.showH != showH ||
           oldDelegate.showD != showD || oldDelegate.showDiag != showDiag ||
           oldDelegate.showP != showP || oldDelegate.linesV != linesV;
  }
}

/// Small Interactive View Compass
class GnomonPainter extends CustomPainter {
  final double yaw;
  final double pitch;

  GnomonPainter({required this.yaw, required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = size.width / 2 * 0.8;

    // Simulate same orientation behavior as the main camera viewport 
    vm.Vector3 vDir = vm.Vector3(
      math.sin(yaw) * math.cos(pitch),
      math.sin(pitch),
      math.cos(yaw) * math.cos(pitch)
    ).normalized();
    
    vm.Vector3 worldUp = vm.Vector3(0, 1, 0);
    vm.Vector3 right = worldUp.cross(vDir);
    if (right.length2 < 0.001) right = vm.Vector3(1, 0, 0);
    else right.normalize();
    vm.Vector3 trueUp = vDir.cross(right).normalized();

    // Dark globe background
    canvas.drawCircle(center, radius, Paint()..color = Colors.black45..style = PaintingStyle.fill);
    canvas.drawCircle(center, radius, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1);

    void drawAxis(vm.Vector3 axis, Color color) {
      double prX = axis.dot(right);
      double prY = axis.dot(trueUp);
      double prZ = axis.dot(vDir);

      // Simple orthographic back-face culling simulation purely for UI aesthetics
      if (prZ < 0) return; 

      Offset end = center + Offset(prX * radius, -prY * radius);
      canvas.drawLine(center, end, Paint()..color = color..strokeWidth = 2.5);
      canvas.drawCircle(end, 4.0, Paint()..color = color); // Dot node 
    }
    
    // Z-Sort axes map so facing lines overlay correctly
    List<Map<String, dynamic>> axes = [
      {'val': vm.Vector3(0, 1, 0), 'color': const Color(0xFF00E5FF)},       // Y/Vertical
      {'val': vm.Vector3(1, 0, 0), 'color': const Color(0xFFFF00FF)},    // X/Horizontal
      {'val': vm.Vector3(0, 0, 1), 'color': const Color(0xFFFFD600)},     // Z/Depth
    ];
    axes.sort((a, b) => (a['val'] as vm.Vector3).dot(vDir).compareTo((b['val'] as vm.Vector3).dot(vDir)));
    for (var a in axes) drawAxis(a['val'], a['color']);
  }

  @override
  bool shouldRepaint(covariant GnomonPainter oldDelegate) => oldDelegate.yaw != yaw || oldDelegate.pitch != pitch;
}
