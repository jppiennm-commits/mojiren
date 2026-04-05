import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'data.dart';
import 'models.dart';
import 'painters.dart';

class KakijunLabApp extends StatelessWidget {
  const KakijunLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'もじれん',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC25F38)),
        scaffoldBackgroundColor: const Color(0xFFF7EEDC),
      ),
      home: const StrokePracticeHome(),
    );
  }
}

class StrokePracticeHome extends StatelessWidget {
  const StrokePracticeHome({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CharacterModel>>(
      future: const CharacterRepository().loadCharacters(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('漢字データの読み込みに失敗しました: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return StrokePracticeScreen(characters: snapshot.data!);
      },
    );
  }
}

class StrokePracticeScreen extends StatefulWidget {
  const StrokePracticeScreen({super.key, required this.characters});

  final List<CharacterModel> characters;

  @override
  State<StrokePracticeScreen> createState() => _StrokePracticeScreenState();
}

class _StrokePracticeScreenState extends State<StrokePracticeScreen> {
  late CharacterModel selectedCharacter;
  late String registerCharacterId;
  WritingTool selectedTool = WritingTool.brushPen;
  InputMode inputMode = InputMode.penPreferred;
  bool showGhostModel = true;
  int shownStrokeCount = 0;
  Timer? playbackTimer;
  final List<SavedCharacter> savedCharacters = [];
  final List<DrawStroke> drawnStrokes = [];
  final TextEditingController memoController = TextEditingController();
  List<DrawSample> activeSamples = [];
  String inputStatus = '入力待ち';

  ToolStyle get toolStyle => ToolStyle.fromTool(selectedTool);

  @override
  void initState() {
    super.initState();
    selectedCharacter = widget.characters.first;
    registerCharacterId = widget.characters.first.id;
  }

  @override
  void dispose() {
    playbackTimer?.cancel();
    memoController.dispose();
    super.dispose();
  }

  CharacterModel findCharacter(String id) {
    return widget.characters.firstWhere((character) => character.id == id);
  }

  void selectCharacter(CharacterModel character) {
    playbackTimer?.cancel();
    setState(() {
      selectedCharacter = character;
      shownStrokeCount = 0;
      activeSamples = [];
      drawnStrokes.clear();
      inputStatus = '入力待ち';
    });
  }

  void playModel() {
    playbackTimer?.cancel();
    setState(() => shownStrokeCount = 0);
    revealNextStroke();
    playbackTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (mounted) {
        revealNextStroke();
      }
    });
  }

  void revealNextStroke() {
    if (shownStrokeCount >= selectedCharacter.strokes.length) {
      playbackTimer?.cancel();
      return;
    }
    setState(() => shownStrokeCount += 1);
  }

  void addSavedCharacter() {
    setState(() {
      savedCharacters.insert(
        0,
        SavedCharacter(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          characterId: registerCharacterId,
          memo: memoController.text.trim(),
        ),
      );
      memoController.clear();
    });
  }

  bool acceptsPointer(PointerDeviceKind kind) {
    switch (inputMode) {
      case InputMode.penOnly:
        return kind == PointerDeviceKind.stylus || kind == PointerDeviceKind.invertedStylus;
      case InputMode.penPreferred:
        return kind == PointerDeviceKind.stylus ||
            kind == PointerDeviceKind.invertedStylus ||
            kind == PointerDeviceKind.unknown;
      case InputMode.touchAndMouse:
        return true;
    }
  }

  String pointerLabel(PointerDeviceKind kind) {
    switch (kind) {
      case PointerDeviceKind.stylus:
      case PointerDeviceKind.invertedStylus:
        return 'ペン入力中';
      case PointerDeviceKind.touch:
        return 'タッチ入力中';
      case PointerDeviceKind.mouse:
        return 'マウス入力中';
      default:
        return '入力中';
    }
  }

  double normalizedPressure(double pressure) {
    if (pressure <= 0 || pressure.isNaN) {
      return 0.5;
    }
    return pressure.clamp(0.0, 1.0);
  }

  void startStroke(PointerDownEvent event) {
    if (!acceptsPointer(event.kind)) {
      setState(() => inputStatus = 'この入力モードではその入力は使えません');
      return;
    }
    final pressure = normalizedPressure(event.pressure);
    setState(() {
      activeSamples = [DrawSample(point: event.localPosition, pressure: pressure)];
      inputStatus = '${pointerLabel(event.kind)} | 圧力 ${pressure.toStringAsFixed(2)}';
    });
  }

  void updateStroke(PointerMoveEvent event) {
    if (activeSamples.isEmpty) {
      return;
    }
    final pressure = normalizedPressure(event.pressure);
    setState(() {
      activeSamples = [...activeSamples, DrawSample(point: event.localPosition, pressure: pressure)];
      inputStatus =
          '${pointerLabel(event.kind)} | 圧力 ${pressure.toStringAsFixed(2)} | ${toolStyle.label}';
    });
  }

  void endStroke() {
    setState(() {
      if (activeSamples.length >= 2) {
        drawnStrokes.add(DrawStroke(samples: activeSamples));
      }
      activeSamples = [];
      inputStatus = '入力待ち';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final singleColumn = constraints.maxWidth < 900;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  HeroCard(character: selectedCharacter),
                  const SizedBox(height: 18),
                  Flex(
                    direction: singleColumn ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: buildModelPanel()),
                      SizedBox(width: singleColumn ? 0 : 18, height: singleColumn ? 18 : 0),
                      Expanded(child: buildPracticePanel()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Flex(
                    direction: singleColumn ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: buildModelBoard()),
                      SizedBox(width: singleColumn ? 0 : 18, height: singleColumn ? 18 : 0),
                      Expanded(child: buildPracticeBoard()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Flex(
                    direction: singleColumn ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: buildRegisterPanel()),
                      SizedBox(width: singleColumn ? 0 : 18, height: singleColumn ? 18 : 0),
                      Expanded(child: buildSavedPanel()),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildModelPanel() {
    return PanelCard(
      title: '見本モード',
      kicker: 'Character',
      trailing: '$shownStrokeCount / ${selectedCharacter.strokes.length} 画',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: selectedCharacter.id,
            decoration: const InputDecoration(
              labelText: '文字を選ぶ',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final character in widget.characters)
                DropdownMenuItem(
                  value: character.id,
                  child: Text('${character.glyph} (${character.reading})'),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                selectCharacter(findCharacter(value));
              }
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(onPressed: playModel, child: const Text('再生')),
              FilledButton.tonal(onPressed: revealNextStroke, child: const Text('一画ずつ')),
              OutlinedButton(
                onPressed: () {
                  playbackTimer?.cancel();
                  setState(() => shownStrokeCount = 0);
                },
                child: const Text('最初に戻す'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('${selectedCharacter.glyph} | ${selectedCharacter.reading} | ${selectedCharacter.meaning}'),
          const SizedBox(height: 14),
          for (var i = 0; i < selectedCharacter.strokes.length; i++)
            NoteTile(index: i + 1, text: selectedCharacter.strokes[i].note),
        ],
      ),
    );
  }

  Widget buildPracticePanel() {
    return PanelCard(
      title: '練習設定',
      kicker: 'Writing Tool',
      trailing: inputStatus,
      child: Column(
        children: [
          DropdownButtonFormField<WritingTool>(
            value: selectedTool,
            decoration: const InputDecoration(
              labelText: '筆記具',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: WritingTool.brushPen, child: Text('筆ペン')),
              DropdownMenuItem(value: WritingTool.ballpoint, child: Text('ボールペン')),
              DropdownMenuItem(value: WritingTool.pencil, child: Text('えんぴつ')),
            ],
            onChanged: (value) => setState(() => selectedTool = value ?? selectedTool),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<InputMode>(
            value: inputMode,
            decoration: const InputDecoration(
              labelText: '入力モード',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: InputMode.penPreferred, child: Text('ペン優先')),
              DropdownMenuItem(value: InputMode.penOnly, child: Text('ペンのみ')),
              DropdownMenuItem(value: InputMode.touchAndMouse, child: Text('指・マウスも可')),
            ],
            onChanged: (value) => setState(() => inputMode = value ?? inputMode),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('練習面に薄いお手本を表示'),
            value: showGhostModel,
            onChanged: (value) => setState(() => showGhostModel = value),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => setState(() {
                drawnStrokes.clear();
                activeSamples = [];
                inputStatus = '入力待ち';
              }),
              child: const Text('練習を消す'),
            ),
          ),
          const SizedBox(height: 14),
          ToolPreviewCard(style: toolStyle, tool: selectedTool),
        ],
      ),
    );
  }

  Widget buildModelBoard() {
    return PanelCard(
      title: '見本ボード',
      kicker: 'Model',
      trailing: '注意点つき',
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: ModelPainter(
            character: selectedCharacter,
            shownStrokeCount: shownStrokeCount,
            style: toolStyle,
          ),
        ),
      ),
    );
  }

  Widget buildPracticeBoard() {
    return PanelCard(
      title: 'ペン練習ボード',
      kicker: 'Practice',
      trailing: 'Apple Pencil / タッチ / マウス',
      child: AspectRatio(
        aspectRatio: 1,
        child: Listener(
          onPointerDown: startStroke,
          onPointerMove: updateStroke,
          onPointerUp: (_) => endStroke(),
          onPointerCancel: (_) => endStroke(),
          child: CustomPaint(
            painter: PracticePainter(
              character: selectedCharacter,
              showGhost: showGhostModel,
              style: toolStyle,
              strokes: drawnStrokes,
              activeStroke: activeSamples,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildRegisterPanel() {
    return PanelCard(
      title: '自分の漢字を登録',
      kicker: 'My List',
      trailing: '複数保存',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: registerCharacterId,
            decoration: const InputDecoration(
              labelText: '登録する文字',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final character in widget.characters)
                DropdownMenuItem(
                  value: character.id,
                  child: Text('${character.glyph} (${character.reading})'),
                ),
            ],
            onChanged: (value) => setState(() => registerCharacterId = value ?? registerCharacterId),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: memoController,
            decoration: const InputDecoration(
              labelText: 'メモ',
              hintText: '例: テスト前によく練習する漢字',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: addSavedCharacter,
              child: const Text('学習リストに追加'),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSavedPanel() {
    return PanelCard(
      title: '登録した漢字',
      kicker: 'Saved',
      trailing: '${savedCharacters.length} 件',
      child: savedCharacters.isEmpty
          ? const EmptyTile(
              message: 'まだ登録がありません。左のフォームから学習したい漢字を追加できます。',
            )
          : Column(
              children: [
                for (final item in savedCharacters)
                  SavedCharacterTile(
                    item: item,
                    character: findCharacter(item.characterId),
                    onSelect: () => selectCharacter(findCharacter(item.characterId)),
                    onDelete: () => setState(() {
                      savedCharacters.removeWhere((entry) => entry.id == item.id);
                    }),
                  ),
              ],
            ),
    );
  }
}

class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7E3), Color(0xFFF2E5D1)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final singleColumn = constraints.maxWidth < 820;
          return Flex(
            direction: singleColumn ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Moji Practice App'),
                    SizedBox(height: 10),
                    Text(
                      'もじれん',
                      style: TextStyle(fontSize: 42, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '見本を見て、止め・はね・はらいの要点を確認しながら、Apple Pencil やタッチペンでも練習できる文字練習アプリです。',
                    ),
                  ],
                ),
              ),
              SizedBox(width: singleColumn ? 0 : 24, height: singleColumn ? 18 : 0),
              Container(
                width: singleColumn ? double.infinity : 240,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('今日の練習'),
                    const SizedBox(height: 8),
                    Text(character.glyph, style: Theme.of(context).textTheme.displayLarge),
                    const SizedBox(height: 8),
                    Text(character.meaning),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
    required this.title,
    required this.kicker,
    required this.trailing,
    required this.child,
  });

  final String title;
  final String kicker;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x1F6B4F28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$kicker\n$title',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: Text(
                  trailing,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class NoteTile extends StatelessWidget {
  const NoteTile({super.key, required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7C8AB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFF7D4C5),
            child: Text('$index'),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class ToolPreviewCard extends StatelessWidget {
  const ToolPreviewCard({super.key, required this.style, required this.tool});

  final ToolStyle style;
  final WritingTool tool;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFAF3), Color(0xFFF5EBDD)],
        ),
        border: Border.all(color: const Color(0xFFE0C8A9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('表示プレビュー'),
          const SizedBox(height: 8),
          Text(
            '永',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: style.color,
              fontWeight: tool == WritingTool.brushPen ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: tool == WritingTool.ballpoint ? 2 : 0,
            ),
          ),
          Text(style.description),
        ],
      ),
    );
  }
}

class EmptyTile extends StatelessWidget {
  const EmptyTile({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message),
    );
  }
}

class SavedCharacterTile extends StatelessWidget {
  const SavedCharacterTile({
    super.key,
    required this.item,
    required this.character,
    required this.onSelect,
    required this.onDelete,
  });

  final SavedCharacter item;
  final CharacterModel character;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3CBB0)),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF4E9D8)],
              ),
            ),
            child: Text(
              character.glyph,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${character.glyph} (${character.reading})'),
                const SizedBox(height: 6),
                Text('${item.memo.isEmpty ? "メモなし" : item.memo} | ${character.meaning}'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              OutlinedButton(onPressed: onSelect, child: const Text('表示')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: onDelete, child: const Text('削除')),
            ],
          ),
        ],
      ),
    );
  }
}
