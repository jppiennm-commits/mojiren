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
      ..color = const Color(0x55CB6238)
      ..strokeWidth = 2.2;
    final leaderPaint = Paint()
      ..color = const Color(0x99CB6238)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;

    for (final ratio in [0.25, 0.75]) {
      canvas.drawLine(Offset(size.width * ratio, 0), Offset(size.width * ratio, size.height), gridPaint);
      canvas.drawLine(Offset(0, size.height * ratio), Offset(size.width, size.height * ratio), gridPaint);
    }
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), guidePaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), guidePaint);

    final center = Offset(size.width / 2, size.height / 2);
    const arm = 18.0;
    canvas.drawLine(center.translate(-arm, 0), center.translate(arm, 0), leaderPaint);
    canvas.drawLine(center.translate(0, -arm), center.translate(0, arm), leaderPaint);

    final edgeArm = size.width * 0.08;
    canvas.drawLine(
      Offset(size.width / 2 - edgeArm, 10),
      Offset(size.width / 2 + edgeArm, 10),
      leaderPaint,
    );
    canvas.drawLine(
      Offset(size.width / 2 - edgeArm, size.height - 10),
      Offset(size.width / 2 + edgeArm, size.height - 10),
      leaderPaint,
    );
    canvas.drawLine(
      Offset(10, size.height / 2 - edgeArm),
      Offset(10, size.height / 2 + edgeArm),
      leaderPaint,
    );
    canvas.drawLine(
      Offset(size.width - 10, size.height / 2 - edgeArm),
      Offset(size.width - 10, size.height / 2 + edgeArm),
      leaderPaint,
    );
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
    this.showNotes = true,
    this.showStrokeNumbers = true,
    this.showReferenceGlyph = true,
  });

  final CharacterModel character;
  final int shownStrokeCount;
  final ToolStyle style;
  final bool showNotes;
  final bool showStrokeNumbers;
  final bool showReferenceGlyph;

  @override
  void paint(Canvas canvas, Size size) {
    BoardPainter.paintBase(canvas, size);
    if (showReferenceGlyph) {
      _drawReferenceGlyph(canvas, size);
    }

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
      if (showStrokeNumbers) {
        canvas.drawCircle(start, 9, Paint()..color = const Color(0xFFCB6238));
        _drawCenteredText(canvas, '${i + 1}', start.translate(0, -18));
      }
      if (showNotes && stroke.note.isNotEmpty) {
        _drawNote(canvas, stroke.note, stroke.notePosition.scale(size), visible);
      }
    }
  }

  void _drawCenteredText(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9C401E),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  void _drawReferenceGlyph(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: character.glyph,
        style: TextStyle(
          color: const Color(0xFF5A4635).withValues(alpha: character.hasStrokeModel ? 0.12 : 0.32),
          fontSize: size.width * 0.6,
          height: 1,
          fontFamily: 'YuKyokasho',
          fontFamilyFallback: const [
            'STKaiti',
            'Kaiti SC',
            'Hiragino Mincho ProN',
            'Yu Mincho',
            'serif',
          ],
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width * 0.9);
    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2 - size.height * 0.03),
    );
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
        oldDelegate.style != style ||
        oldDelegate.showNotes != showNotes ||
        oldDelegate.showStrokeNumbers != showStrokeNumbers ||
        oldDelegate.showReferenceGlyph != showReferenceGlyph;
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
      _drawGhostGlyph(canvas, size);
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

  void _drawGhostGlyph(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: character.glyph,
        style: TextStyle(
          color: style.color.withValues(alpha: character.hasStrokeModel ? 0.08 : 0.2),
          fontSize: size.width * 0.58,
          height: 1,
          fontFamily: 'YuKyokasho',
          fontFamilyFallback: const [
            'STKaiti',
            'Kaiti SC',
            'Hiragino Mincho ProN',
            'Yu Mincho',
            'serif',
          ],
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width * 0.9);
    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2 - size.height * 0.03),
    );
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
