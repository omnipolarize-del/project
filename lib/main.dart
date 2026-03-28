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
          primary: Colors.cyan,
          secondary: const Color(0xFFFF00FF),
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
  bool _isPanelExpanded = false;
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

  double densityV = 2.0;
  double densityH = 2.0;
  double densityD = 2.0;
  double densityDiag = 2.0;

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
      // Pick random densities between 0.5 and 5.0
      densityV = 0.5 + rand.nextDouble() * 4.5;
      densityH = 0.5 + rand.nextDouble() * 4.5;
      densityD = 0.5 + rand.nextDouble() * 4.5;
      densityDiag = 0.5 + rand.nextDouble() * 4.5;
      _regenerateGrid();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Sublayer 1: Deep space grid canvas & Touch handling
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
                    fov = (_baseFov / details.scale).clamp(60.0, 180.0);
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
                  yaw: yaw,
                  pitch: pitch,
                  fov: fov,
                ),
                child: Container(),
              ),
            ),
          ),
          
          // Panel Expand Hint overlay (fade in when hidden)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            bottom: _isPanelExpanded ? -50 : 20,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isPanelExpanded ? 0.0 : 1.0,
                child: const Column(
                  children: [
                    Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70, size: 30),
                    Text('Swipe up for controls', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),

          // Sublayer 2: Interactive orientation trackball (Gnomon)
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
          
          // Floating Info Button
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

          // Sublayer 3: Draggable Control Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCirc,
            bottom: _isPanelExpanded ? 0 : -320,
            left: 0,
            right: 0,
            height: 380, // strict height for smooth animation
            child: _buildControlPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! > 10 && _isPanelExpanded) {
          setState(() => _isPanelExpanded = false);
          HapticFeedback.lightImpact();
        } else if (details.primaryDelta! < -10 && !_isPanelExpanded) {
          setState(() => _isPanelExpanded = true);
          HapticFeedback.lightImpact();
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xD012121A), // Frosted glass darker modern minimal
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30), 
            topRight: Radius.circular(30),
          ),
          boxShadow: [BoxShadow(color: Color(0xAA000000), blurRadius: 40, offset: Offset(0, -5))],
        ),
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
        child: Column(
          children: [
            // Draggable indicator handle
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(5))),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

          // Switches row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildToggle(Icons.waves, Colors.cyan, showV, (v) => setState(() => showV = v)),
              _buildToggle(Icons.waves, const Color(0xFFFF00FF), showH, (v) => setState(() => showH = v)),
              _buildToggle(Icons.waves, Colors.yellow, showD, (v) => setState(() => showD = v)),
              _buildToggle(Icons.waves, Colors.limeAccent, showDiag, (v) => setState(() => showDiag = v)),
            ],
          ),
          const SizedBox(height: 15),

          // Sliders
          _buildDensitySlider('Vertical grid', Colors.cyan, densityV, (v) => densityV = v),
          _buildDensitySlider('Horizontal grid', const Color(0xFFFF00FF), densityH, (v) => densityH = v),
          _buildDensitySlider('Depth grid', Colors.yellow, densityD, (v) => densityD = v),
          _buildDensitySlider('Diagonal grid', Colors.limeAccent, densityDiag, (v) => densityDiag = v),

          Divider(color: Colors.white.withValues(alpha: 0.1)),
          
          // FOV Slider
          Row(
            children: [
              const Icon(Icons.remove_red_eye_outlined, size: 20, color: Colors.white70),
              const SizedBox(width: 15),
              Expanded(
                child: Slider(
                  value: fov,
                  min: 60,
                  max: 180,
                  activeColor: Colors.white,
                  onChanged: (v) => setState(() => fov = v),
                ),
              ),
              SizedBox(width: 40, child: Text('${fov.toInt()}°', style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),

          const SizedBox(height: 5),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: randomizeDensities,
                icon: const Icon(Icons.shuffle, color: Colors.white70),
                label: const Text('Randomize', style: TextStyle(color: Colors.white70)),
              ),
              OutlinedButton.icon(
                onPressed: resetView,
                icon: const Icon(Icons.center_focus_strong, color: Colors.white),
                label: const Text('Reset View', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30)),
              ),
            ],
          ),
          const SizedBox(height: 5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(IconData icon, Color color, bool value, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value ? color.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(color: value ? color : Colors.white24, width: 2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: value ? color : Colors.white54, size: 28),
      ),
    );
  }

  Widget _buildDensitySlider(String title, Color color, double value, Function(double) updateValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 15),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
              child: Slider(
                value: value,
                min: 0.1,
                max: 10.0,
                activeColor: color,
                inactiveColor: color.withValues(alpha: 0.2),
                onChangeEnd: (v) { updateValue(v); _regenerateGrid(); setState((){}); },
                onChanged: (v) { setState(() => updateValue(v)); },
              ),
            ),
          ),
          SizedBox(width: 35, child: Text(value.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
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
                  "By mapping the visual sphere (the true shape of human peripheral vision) "
                  "directly to a 2D plane through an Azimuthal Equidistant projection, straight 3D parallel "
                  "lines correctly bow outwards exactly as they appear at the extreme limits of the eye.\n\n"
                  "This app renders four infinite classical families of parallel lines. At 180° FOV, "
                  "observe how lines perfectly envelope the hemispherical boundary without breaking.",
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
    int tSteps = 200;
    double tMin = -50.0;
    double tMax = 50.0;
    double tStep = (tMax - tMin) / tSteps;

    if (type == 0) { // Vertical (parallel to world Y)
      for (double x = -maxBoxBoundary; x <= maxBoxBoundary; x += density) {
        for (double z = -maxBoxBoundary; z <= maxBoxBoundary; z += density) {
          var list = Float32List((tSteps + 1) * 3);
          for(int i = 0; i <= tSteps; i++) {
            list[i*3] = x;
            list[i*3+1] = tMin + i * tStep;
            list[i*3+2] = z;
          }
          lines.add(list);
        }
      }
    } else if (type == 1) { // Horizontal (parallel to world X)
      for (double y = -maxBoxBoundary; y <= maxBoxBoundary; y += density) {
        for (double z = -maxBoxBoundary; z <= maxBoxBoundary; z += density) {
          var list = Float32List((tSteps + 1) * 3);
          for(int i = 0; i <= tSteps; i++) {
            list[i*3] = tMin + i * tStep;
            list[i*3+1] = y;
            list[i*3+2] = z;
          }
          lines.add(list);
        }
      }
    } else if (type == 2) { // Depth (parallel to world Z)
      for (double x = -maxBoxBoundary; x <= maxBoxBoundary; x += density) {
        for (double y = -maxBoxBoundary; y <= maxBoxBoundary; y += density) {
          var list = Float32List((tSteps + 1) * 3);
          for(int i = 0; i <= tSteps; i++) {
            list[i*3] = x;
            list[i*3+1] = y;
            list[i*3+2] = tMin + i * tStep;
          }
          lines.add(list);
        }
      }
    } else if (type == 3) { // Diagonal 45° families inside XZ planes
      double diagSpacing = density * math.sqrt2;
      double diagBound = math.min(50.0 * math.sqrt2, diagSpacing * 20.0);
      double diagTMin = -50.0 * math.sqrt2;
      double diagTStep = ( 100.0 * math.sqrt2 ) / tSteps;
      double invSqrt2 = 1.0 / math.sqrt2;

      // First diagonal group: direction (1, 0, 1) normalized
      for (double m = -diagBound; m <= diagBound; m += diagSpacing) {
        for (double y = -maxBoxBoundary; y <= maxBoxBoundary; y += density) {
          var list = Float32List((tSteps + 1) * 3);
          for(int i = 0; i <= tSteps; i++) {
            double t = diagTMin + i * diagTStep;
            list[i*3] = m + t * invSqrt2;
            list[i*3+1] = y;
            list[i*3+2] = t * invSqrt2;
          }
          lines.add(list);
        }
      }
      // Second diagonal group: direction (1, 0, -1) normalized
      for (double m = -diagBound; m <= diagBound; m += diagSpacing) {
        for (double y = -maxBoxBoundary; y <= maxBoxBoundary; y += density) {
          var list = Float32List((tSteps + 1) * 3);
          for(int i = 0; i <= tSteps; i++) {
            double t = diagTMin + i * diagTStep;
            list[i*3] = m + t * invSqrt2;
            list[i*3+1] = y;
            list[i*3+2] = -t * invSqrt2;
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
  final bool showV, showH, showD, showDiag;
  final double yaw, pitch, fov;

  CurvilinearPainter({
    required this.linesV,
    required this.linesH,
    required this.linesD,
    required this.linesDiag,
    required this.showV,
    required this.showH,
    required this.showD,
    required this.showDiag,
    required this.yaw,
    required this.pitch,
    required this.fov,
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

    if (showV) _drawFamily(canvas, linesV, Colors.cyan, center, radius, maxTheta, vDir, right, trueUp);
    if (showH) _drawFamily(canvas, linesH, const Color(0xFFFF00FF), center, radius, maxTheta, vDir, right, trueUp);
    if (showD) _drawFamily(canvas, linesD, Colors.yellow, center, radius, maxTheta, vDir, right, trueUp);
    if (showDiag) _drawFamily(canvas, linesDiag, Colors.limeAccent, center, radius, maxTheta, vDir, right, trueUp);
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
      double lastCosT = 0;
      
      // We leap by 3 (X,Y,Z structure)
      for (int i = 0; i < pts.length; i += 3) {
        double px = pts[i];
        double py = pts[i+1];
        double pz = pts[i+2];

        double distSq = px*px + py*py + pz*pz;
        if (distSq < 0.0001) continue; // Safety against origin singularity
        double dist = math.sqrt(distSq);

        // Cosine of angle to camera direction dictates visibility (z-clipping)
        // > 0 is visible. <= 0 means point is traversing the infinite bounds behind the eye.
        double cosT = (px*vX + py*vY + pz*vZ) / dist;

        if (cosT > 0.0) {
          // --- Main Core Projection --- Flocon & Barre logic applied here
          double theta = math.acos(cosT.clamp(-1.0, 1.0));
          
          double prX = (px*rX + py*rY + pz*rZ) / dist;
          double prY = (px*uX + py*uY + pz*uZ) / dist;
          double sinT = math.sqrt(prX*prX + prY*prY);
          
          double r = theta * rScale;
          double outX = cx + (sinT > 0.0001 ? r * (prX / sinT) : 0);
          double outY = cy - (sinT > 0.0001 ? r * (prY / sinT) : 0); // Y flipped for canvas

          if (!pathStarted) {
            // INTERPOLATION CRUCIAL FIX: Exact point clipping bridging entering the hemisphere
            if (i > 0 && lastCosT <= 0.0) { 
              double tInterp = lastCosT / (lastCosT - cosT);
              double edgePx = lastPx + (px - lastPx) * tInterp;
              double edgePy = lastPy + (py - lastPy) * tInterp;
              double edgePz = lastPz + (pz - lastPz) * tInterp;

              double eDist = math.sqrt(edgePx*edgePx + edgePy*edgePy + edgePz*edgePz);
              double ePrX = (edgePx*rX + edgePy*rY + edgePz*rZ) / eDist;
              double ePrY = (edgePx*uX + edgePy*uY + edgePz*uZ) / eDist;
              double eSinT = math.sqrt(ePrX*ePrX + ePrY*ePrY);
              
              double eR = (math.pi / 2.0) * rScale; // Bound entirely on the 180deg hemisphere limit edge
              double eOutX = cx + (eSinT > 0.0001 ? eR * (ePrX / eSinT) : 0);
              double eOutY = cy - (eSinT > 0.0001 ? eR * (ePrY / eSinT) : 0);
              path.moveTo(eOutX, eOutY);
            } else {
              path.moveTo(outX, outY);
            }
            pathStarted = true;
          }
          path.lineTo(outX, outY);
        } else {
          // Point is outside hemisphere.
          if (pathStarted) {
            // INTERPOLATION CRUCIAL FIX: Smooth edge-bridge cleanly tracking line exiting out of bounds.
            double tInterp = lastCosT / (lastCosT - cosT);
            double edgePx = lastPx + (px - lastPx) * tInterp;
            double edgePy = lastPy + (py - lastPy) * tInterp;
            double edgePz = lastPz + (pz - lastPz) * tInterp;

            double eDist = math.sqrt(edgePx*edgePx + edgePy*edgePy + edgePz*edgePz);
            double ePrX = (edgePx*rX + edgePy*rY + edgePz*rZ) / eDist;
            double ePrY = (edgePx*uX + edgePy*uY + edgePz*uZ) / eDist;
            double eSinT = math.sqrt(ePrX*ePrX + ePrY*ePrY);
            
            double eR = (math.pi / 2.0) * rScale;
            double eOutX = cx + (eSinT > 0.0001 ? eR * (ePrX / eSinT) : 0);
            double eOutY = cy - (eSinT > 0.0001 ? eR * (ePrY / eSinT) : 0);
            path.lineTo(eOutX, eOutY);
            pathStarted = false;
          }
        }
        
        lastPx = px; lastPy = py; lastPz = pz;
        lastCosT = cosT;
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
           oldDelegate.linesV != linesV;
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
      {'val': vm.Vector3(0, 1, 0), 'color': Colors.cyan},       // Y/Vertical
      {'val': vm.Vector3(1, 0, 0), 'color': const Color(0xFFFF00FF)},    // X/Horizontal
      {'val': vm.Vector3(0, 0, 1), 'color': Colors.yellow},     // Z/Depth
    ];
    axes.sort((a, b) => (a['val'] as vm.Vector3).dot(vDir).compareTo((b['val'] as vm.Vector3).dot(vDir)));
    for (var a in axes) drawAxis(a['val'], a['color']);
  }

  @override
  bool shouldRepaint(covariant GnomonPainter oldDelegate) => oldDelegate.yaw != yaw || oldDelegate.pitch != pitch;
}
