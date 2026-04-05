import 'dart:convert';
import 'dart:ui';

enum WritingTool { brushPen, ballpoint, pencil }

enum InputMode { penPreferred, penOnly, touchAndMouse }

class StrokePoint {
  const StrokePoint(this.x, this.y);

  final double x;
  final double y;

  Offset scale(Size size) => Offset(size.width * x / 100, size.height * y / 100);

  factory StrokePoint.fromList(List<dynamic> values) {
    return StrokePoint(
      (values[0] as num).toDouble(),
      (values[1] as num).toDouble(),
    );
  }

  List<double> toList() => [x, y];
}

class StrokeSegment {
  const StrokeSegment({
    required this.points,
    required this.note,
    required this.notePosition,
  });

  final List<StrokePoint> points;
  final String note;
  final StrokePoint notePosition;

  factory StrokeSegment.fromMap(Map<String, dynamic> map) {
    return StrokeSegment(
      points: (map['points'] as List<dynamic>)
          .map((point) => StrokePoint.fromList(point as List<dynamic>))
          .toList(),
      note: map['note'] as String? ?? '',
      notePosition: StrokePoint.fromList(map['notePos'] as List<dynamic>),
    );
  }

  Map<String, dynamic> toMap() => {
        'points': points.map((point) => point.toList()).toList(),
        'note': note,
        'notePos': notePosition.toList(),
      };
}

class CharacterModel {
  const CharacterModel({
    required this.id,
    required this.glyph,
    required this.reading,
    required this.meaning,
    required this.strokes,
  });

  final String id;
  final String glyph;
  final String reading;
  final String meaning;
  final List<StrokeSegment> strokes;

  factory CharacterModel.fromMap(Map<String, dynamic> map) {
    return CharacterModel(
      id: map['id'] as String,
      glyph: map['glyph'] as String,
      reading: map['reading'] as String? ?? '',
      meaning: map['meaning'] as String? ?? '',
      strokes: (map['strokes'] as List<dynamic>)
          .map((stroke) => StrokeSegment.fromMap(stroke as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'glyph': glyph,
        'reading': reading,
        'meaning': meaning,
        'strokes': strokes.map((stroke) => stroke.toMap()).toList(),
      };

  static List<CharacterModel> listFromJson(String source) {
    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .map((entry) => CharacterModel.fromMap(entry as Map<String, dynamic>))
        .toList();
  }
}

class SavedCharacter {
  const SavedCharacter({
    required this.id,
    required this.characterId,
    required this.memo,
  });

  final String id;
  final String characterId;
  final String memo;
}

class DrawSample {
  const DrawSample({
    required this.point,
    required this.pressure,
  });

  final Offset point;
  final double pressure;
}

class DrawStroke {
  const DrawStroke({
    required this.samples,
  });

  final List<DrawSample> samples;
}

class ToolStyle {
  const ToolStyle({
    required this.label,
    required this.color,
    required this.modelWidth,
    required this.baseWidth,
    required this.pressureBoost,
    required this.opacity,
    required this.description,
  });

  final String label;
  final Color color;
  final double modelWidth;
  final double baseWidth;
  final double pressureBoost;
  final double opacity;
  final String description;

  static ToolStyle fromTool(WritingTool tool) {
    switch (tool) {
      case WritingTool.brushPen:
        return const ToolStyle(
          label: '筆ペン',
          color: Color(0xFF241913),
          modelWidth: 8.8,
          baseWidth: 4.2,
          pressureBoost: 8.0,
          opacity: 0.94,
          description: '筆圧で太さが変わる、はらいが見やすい表示です。',
        );
      case WritingTool.ballpoint:
        return const ToolStyle(
          label: 'ボールペン',
          color: Color(0xFF173C70),
          modelWidth: 6.2,
          baseWidth: 3.2,
          pressureBoost: 2.0,
          opacity: 0.96,
          description: '均一で読みやすい線です。止めやはねの位置確認に向いています。',
        );
      case WritingTool.pencil:
        return const ToolStyle(
          label: 'えんぴつ',
          color: Color(0xFF5F5951),
          modelWidth: 5.6,
          baseWidth: 2.4,
          pressureBoost: 3.2,
          opacity: 0.78,
          description: '少しやわらかい線で、下書きのように練習できます。',
        );
    }
  }
}
