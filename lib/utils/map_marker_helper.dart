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

  // ── Stop marker: teardrop pin ───────────────────────────────────────────────

  static Future<BitmapDescriptor> _drawStopPin({required bool waiting}) async {
    const double w = 48;
    const double h = 66;
    const double cx = w / 2;
    const double r = 21.0;
    final color = waiting ? const Color(0xFFE65100) : const Color(0xFF2E7D32);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    final colorPaint = Paint()..color = color;
    final whitePaint = Paint()..color = Colors.white;

    // Drop shadow
    canvas.drawCircle(
      Offset(cx, r + 2),
      r + 1,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Pin circle top
    canvas.drawCircle(Offset(cx, r), r, colorPaint);

    // Pin triangle tail
    final tail = Path()
      ..moveTo(cx - 9, r + 14)
      ..lineTo(cx + 9, r + 14)
      ..lineTo(cx, h - 4)
      ..close();
    canvas.drawPath(tail, colorPaint);

    // White border on circle
    canvas.drawCircle(
      Offset(cx, r),
      r - 1,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Bus-stop sign icon: horizontal plank + pole
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 9, r - 9, 18, 8),
        const Radius.circular(2),
      ),
      whitePaint,
    );
    canvas.drawRect(Rect.fromLTWH(cx - 1.5, r - 1, 3, 15), whitePaint);

    // If waiting, draw a small pulsing-ring indicator
    if (waiting) {
      canvas.drawCircle(
        Offset(cx, r),
        r - 3,
        Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    return _toBitmapDescriptor(recorder, w.toInt(), h.toInt());
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
