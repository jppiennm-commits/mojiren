import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

void main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln(
      'Usage: dart run tool/build_kanji_assets.dart <kanjivg_dir> <kanjidic2.xml> <output.json> [glyphs.txt]',
    );
    exit(64);
  }

  final kanjiVgDir = Directory(args[0]);
  final kanjiDicFile = File(args[1]);
  final outputFile = File(args[2]);
  final allowedGlyphs = args.length >= 4 ? _readGlyphFilter(File(args[3])) : null;

  if (!kanjiVgDir.existsSync()) {
    stderr.writeln('KanjiVG directory not found: ${kanjiVgDir.path}');
    exit(66);
  }
  if (!kanjiDicFile.existsSync()) {
    stderr.writeln('KANJIDIC2 XML not found: ${kanjiDicFile.path}');
    exit(66);
  }

  final dictionary = _loadKanjiDic(kanjiDicFile, allowedGlyphs);
  final records = <Map<String, dynamic>>[];

  for (final entry in dictionary.entries) {
    final glyph = entry.key;
    final svgName = glyph.runes.first.toRadixString(16).padLeft(5, '0');
    final svgFile = File('${kanjiVgDir.path}${Platform.pathSeparator}$svgName.svg');
    if (!svgFile.existsSync()) {
      continue;
    }

    final strokes = _parseKanjiVg(svgFile);
    if (strokes.isEmpty) {
      continue;
    }

    records.add({
      'id': svgName,
      'glyph': glyph,
      'reading': entry.value['reading'],
      'meaning': entry.value['meaning'],
      'strokes': strokes,
    });
  }

  outputFile.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  outputFile.writeAsStringSync(encoder.convert(records));
  stdout.writeln('Wrote ${records.length} kanji records to ${outputFile.path}');
}

Set<String>? _readGlyphFilter(File file) {
  if (!file.existsSync()) {
    return null;
  }
  return file
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toSet();
}

Map<String, Map<String, String>> _loadKanjiDic(File file, Set<String>? allowedGlyphs) {
  final document = XmlDocument.parse(file.readAsStringSync());
  final result = <String, Map<String, String>>{};

  for (final character in document.findAllElements('character')) {
    final literal = character.getElement('literal')?.innerText.trim();
    if (literal == null || literal.isEmpty) {
      continue;
    }
    if (allowedGlyphs != null && !allowedGlyphs.contains(literal)) {
      continue;
    }

    final readings = character
        .findAllElements('reading')
        .where((node) => node.getAttribute('r_type') == 'ja_on' || node.getAttribute('r_type') == 'ja_kun')
        .map((node) => node.innerText.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(3)
        .join(' / ');

    final meanings = character
        .findAllElements('meaning')
        .where((node) => node.getAttribute('m_lang') == null)
        .map((node) => node.innerText.trim())
        .where((value) => value.isNotEmpty)
        .take(2)
        .join(' / ');

    result[literal] = {
      'reading': readings,
      'meaning': meanings,
    };
  }

  return result;
}

List<Map<String, dynamic>> _parseKanjiVg(File svgFile) {
  final document = XmlDocument.parse(svgFile.readAsStringSync());
  final strokePaths = document
      .findAllElements('path')
      .where((path) => (path.getAttribute('id') ?? '').contains('s'))
      .toList();

  final result = <Map<String, dynamic>>[];

  for (final path in strokePaths) {
    final d = path.getAttribute('d');
    if (d == null || d.isEmpty) {
      continue;
    }
    final points = _extractPoints(d);
    if (points.length < 2) {
      continue;
    }
    result.add({
      'points': points,
      'note': '',
      'notePos': points.first,
    });
  }

  return result;
}

List<List<double>> _extractPoints(String d) {
  final matches = RegExp(r'(-?\d+(?:\.\d+)?)').allMatches(d).map((m) => double.parse(m.group(0)!)).toList();
  final points = <List<double>>[];
  for (var i = 0; i + 1 < matches.length; i += 2) {
    final x = (matches[i] / 109).clamp(0, 1) * 100;
    final y = (matches[i + 1] / 109).clamp(0, 1) * 100;
    points.add([double.parse(x.toStringAsFixed(2)), double.parse(y.toStringAsFixed(2))]);
  }
  return points;
}
