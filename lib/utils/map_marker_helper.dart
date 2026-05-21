import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Generates canvas-rendered custom map markers so no PNG assets are needed.
/// Results are cached after the first call.
class MapMarkerHelper {
  static BitmapDescriptor? _busMarker;
  static BitmapDescriptor? _busInactiveMarker;
  static BitmapDescriptor? _stopMarker;
  static BitmapDescriptor? _waitingStopMarker;

  // ── Public getters ──────────────────────────────────────────────────────────

  static Future<BitmapDescriptor> getBusMarker() async =>
      _busMarker ??= await _drawBusMarker(active: true);

  static Future<BitmapDescriptor> getBusInactiveMarker() async =>
      _busInactiveMarker ??= await _drawBusMarker(active: false);

  static Future<BitmapDescriptor> getStopMarker() async =>
      _stopMarker ??= await _drawStopPin(waiting: false);

  static Future<BitmapDescriptor> getWaitingStopMarker() async =>
      _waitingStopMarker ??= await _drawStopPin(waiting: true);

  // ── Bus marker: filled circle with a bus silhouette inside ─────────────────

  static Future<BitmapDescriptor> _drawBusMarker({required bool active}) async {
    const double size = 72;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    final bg = active ? const Color(0xFF1565C0) : const Color(0xFF9E9E9E);
    const cx = size / 2;
    const cy = size / 2;
    const r = size / 2 - 3;

    // Drop shadow
    canvas.drawCircle(
      Offset(cx, cy + 3),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Circle background
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = bg);

    // White border
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final white = Paint()..color = Colors.white;
    final bgPaint = Paint()..color = bg;

    // Bus body
    final busRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 22, cy - 14, 44, 26),
      const Radius.circular(5),
    );
    canvas.drawRRect(busRect, white);

    // Left window
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 19, cy - 10, 16, 10),
          const Radius.circular(2)),
      bgPaint,
    );
    // Right window
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + 3, cy - 10, 16, 10),
          const Radius.circular(2)),
      bgPaint,
    );

    // Wheels
    canvas.drawCircle(Offset(cx - 13, cy + 14), 5.5, white);
    canvas.drawCircle(Offset(cx + 13, cy + 14), 5.5, white);

    return _toBitmapDescriptor(recorder, size.toInt(), size.toInt());
  }

  // ── Stop marker: Circular Bus Stop Icon ─────────────────────────────────────

  static Future<BitmapDescriptor> _drawStopPin({required bool waiting}) async {
    const double size = 80.0;
    const double r = size / 2;
    final color = waiting ? const Color(0xFFE65100) : const Color(0xFF2E7D32);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // Shadow
    canvas.drawCircle(
      const Offset(r, r + 2),
      r - 2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Main background circle
    canvas.drawCircle(
      const Offset(r, r),
      r - 4,
      Paint()..color = color,
    );

    // Inner white border
    canvas.drawCircle(
      const Offset(r, r),
      r - 5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Stop sign octagon
    final signRadius = r - 14;
    final center = Offset(r, r);
    final signPath = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (math.pi / 8) + (math.pi / 4) * i;
      final x = center.dx + signRadius * math.cos(angle);
      final y = center.dy + signRadius * math.sin(angle);
      if (i == 0) {
        signPath.moveTo(x, y);
      } else {
        signPath.lineTo(x, y);
      }
    }
    signPath.close();
    canvas.drawPath(signPath, Paint()..color = Colors.white);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'STOP',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(r - textPainter.width / 2, r - textPainter.height / 2),
    );

    // If waiting, draw a dashed outer ring
    if (waiting) {
      canvas.drawCircle(
        const Offset(r, r),
        r - 1,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    return _toBitmapDescriptor(recorder, size.toInt(), size.toInt());
  }

  // ── Helper ──────────────────────────────────────────────────────────────────

  static Future<BitmapDescriptor> _toBitmapDescriptor(
    ui.PictureRecorder recorder,
    int width,
    int height,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    // ignore: deprecated_member_use
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }
}
