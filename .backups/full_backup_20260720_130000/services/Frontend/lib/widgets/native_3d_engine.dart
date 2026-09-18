import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:math' as math;

enum PracticeShape { sphere, cube, torus, pyramid, lotus }

class Native3DEngine extends StatefulWidget {
  final PracticeShape shape;
  final Color color;
  final double size;

  const Native3DEngine({
    super.key,
    required this.shape,
    required this.size,
    this.color = const Color(0xFFFFD700), // gold
  });

  @override
  State<Native3DEngine> createState() => _Native3DEngineState();
}

class _Native3DEngineState extends State<Native3DEngine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<vector.Vector3> _vertices = [];
  List<List<int>> _edges = [];

  @override
  void initState() {
    super.initState();
    _generateGeometry();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void didUpdateWidget(Native3DEngine oldWidget) {
    if (oldWidget.shape != widget.shape) {
      _generateGeometry();
    }
    super.didUpdateWidget(oldWidget);
  }

  void _generateGeometry() {
    _vertices.clear();
    _edges.clear();

    switch (widget.shape) {
      case PracticeShape.cube:
        _generateCube();
        break;
      case PracticeShape.pyramid:
        _generatePyramid();
        break;
      case PracticeShape.sphere:
        _generateSphere();
        break;
      case PracticeShape.torus:
        _generateTorus();
        break;
      case PracticeShape.lotus:
        _generateLotus();
        break;
    }
  }

  void _generateCube() {
    const s = 1.0;
    _vertices = [
      vector.Vector3(-s, -s, -s),
      vector.Vector3(s, -s, -s),
      vector.Vector3(s, s, -s),
      vector.Vector3(-s, s, -s),
      vector.Vector3(-s, -s, s),
      vector.Vector3(s, -s, s),
      vector.Vector3(s, s, s),
      vector.Vector3(-s, s, s),
    ];
    _edges = [
      [0, 1], [1, 2], [2, 3], [3, 0], // back
      [4, 5], [5, 6], [6, 7], [7, 4], // front
      [0, 4], [1, 5], [2, 6], [3, 7] // connecting
    ];
  }

  void _generatePyramid() {
    const s = 1.2;
    _vertices = [
      vector.Vector3(0, -s, 0), // Apex
      vector.Vector3(-s, s, -s), // Base 1
      vector.Vector3(s, s, -s), // Base 2
      vector.Vector3(s, s, s), // Base 3
      vector.Vector3(-s, s, s), // Base 4
    ];
    _edges = [
      [0, 1], [0, 2], [0, 3], [0, 4], // To apex
      [1, 2], [2, 3], [3, 4], [4, 1] // Base
    ];
  }

  void _generateSphere() {
    int lats = 12;
    int longs = 12;

    for (int i = 0; i <= lats; i++) {
      double lat0 = math.pi * (-0.5 + (i - 1) / lats);
      double lat1 = math.pi * (-0.5 + i / lats);

      double z0 = math.sin(lat0);
      double zr0 = math.cos(lat0);
      double z1 = math.sin(lat1);
      double zr1 = math.cos(lat1);

      for (int j = 0; j <= longs; j++) {
        double lng = 2 * math.pi * j / longs;
        double x = math.cos(lng);
        double y = math.sin(lng);

        _vertices.add(vector.Vector3(x * zr0, y * zr0, z0));
        _vertices.add(vector.Vector3(x * zr1, y * zr1, z1));
      }
    }

    for (int i = 0; i < _vertices.length - 1; i++) {
      _edges.add([i, i + 1]);
      if (i + longs < _vertices.length) {
        _edges.add([i, i + longs]);
      }
    }
  }

  void _generateTorus() {
    int rings = 16;
    int sides = 16;
    double r1 = 0.5; // Tube radius
    double r2 = 1.0; // Main radius

    for (int i = 0; i < rings; i++) {
      double theta = i * 2.0 * math.pi / rings;
      for (int j = 0; j < sides; j++) {
        double phi = j * 2.0 * math.pi / sides;
        // Torus parametric eq
        double x = (r2 + r1 * math.cos(theta)) * math.cos(phi);
        double y = (r2 + r1 * math.cos(theta)) * math.sin(phi);
        double z = r1 * math.sin(theta);
        _vertices.add(vector.Vector3(x, y, z));
      }
    }

    for (int i = 0; i < rings; i++) {
      for (int j = 0; j < sides; j++) {
        int current = i * sides + j;
        int nextSide = i * sides + (j + 1) % sides;
        int nextRing = ((i + 1) % rings) * sides + j;

        _edges.add([current, nextSide]);
        _edges.add([current, nextRing]);
      }
    }
  }

  void _generateLotus() {
    // A beautiful spiraling array of points (Fibonacci sphere variant with lines)
    int points = 80;
    double scale = 1.5;
    double phi = math.pi * (3.0 - math.sqrt(5.0)); // golden angle
    for (int i = 0; i < points; i++) {
      double y = 1 - (i / (points - 1)) * 2; // y goes from 1 to -1
      double radius = math.sqrt(1 - y * y);
      double theta = phi * i;
      double x = math.cos(theta) * radius;
      double z = math.sin(theta) * radius;
      _vertices.add(vector.Vector3(x * scale, y * scale, z * scale));
    }
    // Connect nearest layers
    for (int i = 0; i < points - 1; i++) {
      _edges.add([i, i + 1]);
      if (i + 5 < points) _edges.add([i, i + 5]);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return RepaintBoundary(
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _Engine3DPainter(
              vertices: _vertices,
              edges: _edges,
              color: widget.color,
              time: _controller.value * math.pi * 2,
              shape: widget.shape,
            ),
          ),
        );
      },
    );
  }
}

class _Engine3DPainter extends CustomPainter {
  final List<vector.Vector3> vertices;
  final List<List<int>> edges;
  final Color color;
  final double time;
  final PracticeShape shape;

  _Engine3DPainter({
    required this.vertices,
    required this.edges,
    required this.color,
    required this.time,
    required this.shape,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double scale = size.width / 4;
    double cx = size.width / 2;
    double cy = size.height / 2;

    // Build the transformation matrix
    vector.Matrix4 transform = vector.Matrix4.identity();

    // Auto-rotation based on shape type
    if (shape == PracticeShape.cube) {
      transform.rotateY(time * 0.8);
      transform.rotateX(time * 0.5);
    } else if (shape == PracticeShape.pyramid) {
      transform.rotateY(time);
      transform.rotateX(math.sin(time) * 0.3); // Gentle tip
    } else if (shape == PracticeShape.torus) {
      transform.rotateX(time * 0.6);
      transform.rotateZ(time * 0.4);
    } else if (shape == PracticeShape.sphere) {
      transform.rotateY(time);
      transform.rotateZ(time * 0.3);
    } else if (shape == PracticeShape.lotus) {
      transform.rotateY(time * 1.5); // Fast spiral
      // Breathing effect for lotus
      scale *= 1.0 + math.sin(time * 4) * 0.15;
    }

    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Multi-layered glowing core effect (Neural Kintsugi aesthetic)
    final glowPaintInner = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
      ..style = PaintingStyle.stroke;

    final glowPaintOuter = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16.0)
      ..style = PaintingStyle.stroke;

    final projected = <Offset>[];
    for (var v in vertices) {
      vector.Vector3 transformed = transform.transform3(vector.Vector3.copy(v));

      // Calculate simple perspective projection
      double distance = 3.0; // Camera distance
      double z = transformed.z + distance;
      double fov = 400.0; // Field of view equivalent

      double projX = (transformed.x * fov) / z;
      double projY = (transformed.y * fov) / z;

      projected
          .add(Offset(cx + projX * (scale / 100), cy + projY * (scale / 100)));
    }

    // Sort edges by Z-depth for correct basic drawing order (back to front) if needed,
    // but wireframes look fine drawn straight.

    for (var edge in edges) {
      if (edge[0] < projected.length && edge[1] < projected.length) {
        Offset p1 = projected[edge[0]];
        Offset p2 = projected[edge[1]];

        // Render layers of glow for premium glass/neon 3D feel
        canvas.drawLine(p1, p2, glowPaintOuter);
        canvas.drawLine(p1, p2, glowPaintInner);
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Engine3DPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.shape != shape;
  }
}
