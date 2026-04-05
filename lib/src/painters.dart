import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

class BoardPainter {
  static void paintBase(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFFEFB), Color(0xFFFFF5E8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    final border = Paint()
      ..color = const Color(0x22664F34)
      ..style = PaintingStyle.stroke;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(26));

    canvas.drawRRect(rect, background);
    canvas.drawRRect(rect, border);

    final gridPaint = Paint()
      ..color = const Color(0x2A7E633E)
      ..strokeWidth = 1;
    final guidePaint = Paint()
      ..color = const Color(0x33CB6238)
      ..strokeWidth = 1.2;

    for (final ratio in [0.25, 0.75]) {
      canvas.drawLine(Offset(size.width * ratio, 0), Offset(size.width * ratio, size.height), gridPaint);
      canvas.drawLine(Offset(0, size.height * ratio), Offset(size.width, size.height * ratio), gridPaint);
    }
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), guidePaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), guidePaint);
  }

  static Path pathFor(List<StrokePoint> points, Size size) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final point = points[i].scale(size);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }
}

class ModelPainter extends CustomPainter {
  const ModelPainter({
    required this.character,
    required this.shownStrokeCount,
    required this.style,
  });

  final CharacterModel character;
  final int shownStrokeCount;
  final ToolStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    BoardPainter.paintBase(canvas, size);

    for (var i = 0; i < character.strokes.length; i++) {
      final stroke = character.strokes[i];
      final path = BoardPainter.pathFor(stroke.points, size);
      final visible = i < shownStrokeCount;
      final paint = Paint()
        ..color = style.color.withValues(alpha: visible ? style.opacity : 0.12)
        ..strokeWidth = style.modelWidth * size.width / 420
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);

      final start = stroke.points.first.scale(size);
      canvas.drawCircle(start, 9, Paint()..color = const Color(0xFFCB6238));
      _drawCenteredText(canvas, '${i + 1}', start.translate(0, -18));
      _drawNote(canvas, stroke.note, stroke.notePosition.scale(size), visible);
    }
  }

  void _drawCenteredText(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: const TextSpan(style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9C401E))).copyWith(text: text),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  void _drawNote(Canvas canvas, String note, Offset offset, bool visible) {
    final painter = TextPainter(
      text: TextSpan(
        text: note,
        style: TextStyle(
          color: const Color(0xFF78401F).withValues(alpha: visible ? 1 : 0.25),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offset.dx - 4, offset.dy - 10, painter.width + 8, painter.height + 6),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFFFFF8EF).withValues(alpha: visible ? 0.96 : 0.3));
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFCB6238).withValues(alpha: visible ? 0.35 : 0.12),
    );
    painter.paint(canvas, Offset(offset.dx, offset.dy - 7));
  }

  @override
  bool shouldRepaint(covariant ModelPainter oldDelegate) {
    return oldDelegate.character != character ||
        oldDelegate.shownStrokeCount != shownStrokeCount ||
        oldDelegate.style != style;
  }
}

class PracticePainter extends CustomPainter {
  const PracticePainter({
    required this.character,
    required this.showGhost,
    required this.style,
    required this.strokes,
    required this.activeStroke,
  });

  final CharacterModel character;
  final bool showGhost;
  final ToolStyle style;
  final List<DrawStroke> strokes;
  final List<DrawSample> activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    BoardPainter.paintBase(canvas, size);

    if (showGhost) {
      final ghostPaint = Paint()
        ..color = style.color.withValues(alpha: 0.14)
        ..strokeWidth = math.max(2, style.modelWidth * size.width / 420)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final stroke in character.strokes) {
        canvas.drawPath(BoardPainter.pathFor(stroke.points, size), ghostPaint);
      }
    }

    for (final stroke in strokes) {
      _drawPressureStroke(canvas, stroke.samples);
    }
    if (activeStroke.isNotEmpty) {
      _drawPressureStroke(canvas, activeStroke);
    }
  }

  void _drawPressureStroke(Canvas canvas, List<DrawSample> samples) {
    for (var i = 1; i < samples.length; i++) {
      final previous = samples[i - 1];
      final current = samples[i];
      final paint = Paint()
        ..color = style.color.withValues(alpha: style.opacity)
        ..strokeWidth = style.baseWidth + style.pressureBoost * current.pressure
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawLine(previous.point, current.point, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PracticePainter oldDelegate) {
    return oldDelegate.character != character ||
        oldDelegate.showGhost != showGhost ||
        oldDelegate.style != style ||
        oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke;
  }
}
