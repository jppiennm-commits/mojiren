import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'data.dart';
import 'models.dart';
import 'painters.dart';

enum LearningMode { model, practice, collection }

enum JapaneseScript { hiragana, katakana, kanji }

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
            body: Center(child: Text('文字データの読み込みに失敗しました: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
  late final Map<String, CharacterModel> characterMap;
  late CharacterModel selectedCharacter;
  LearningMode currentMode = LearningMode.model;
  WritingTool selectedTool = WritingTool.brushPen;
  InputMode inputMode = InputMode.penPreferred;
  bool showGhostModel = true;
  bool practiceSetupDone = false;
  int shownStrokeCount = 0;
  Timer? playbackTimer;
  final List<SavedCharacter> savedCharacters = [];
  final List<DrawStroke> drawnStrokes = [];
  final TextEditingController memoController = TextEditingController();
  String registerDraft = '';
  List<DrawSample> activeSamples = [];
  String inputStatus = '入力待ち';

  ToolStyle get toolStyle => ToolStyle.fromTool(selectedTool);

  @override
  void initState() {
    super.initState();
    characterMap = {for (final character in widget.characters) character.glyph: character};
    selectedCharacter = widget.characters.first;
  }

  @override
  void dispose() {
    playbackTimer?.cancel();
    memoController.dispose();
    super.dispose();
  }

  CharacterModel modelForGlyph(String glyph) {
    final existing = characterMap[glyph];
    if (existing != null) {
      return existing;
    }
    return CharacterModel(
      id: 'virtual_${glyph.runes.join('_')}',
      glyph: glyph,
      reading: scriptLabel(detectScript(glyph)),
      meaning: '見本表示のみ',
      strokes: const [],
    );
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

  Future<void> pickSingleCharacter({
    required String title,
    required CharacterModel initialCharacter,
    required ValueChanged<CharacterModel> onSelected,
  }) async {
    final pickedGlyph = await showDialog<String>(
      context: context,
      builder: (context) => CharacterSearchDialog(
        title: title,
        initialGlyph: initialCharacter.glyph,
        characterMap: characterMap,
      ),
    );
    if (!mounted || pickedGlyph == null) {
      return;
    }
    onSelected(modelForGlyph(pickedGlyph));
  }

  Future<void> appendRegisterCharacter() async {
    final initialGlyph = registerDraft.isEmpty ? selectedCharacter.glyph : registerDraft.characters.last;
    final pickedGlyph = await showDialog<String>(
      context: context,
      builder: (context) => CharacterSearchDialog(
        title: '登録する文字を検索',
        initialGlyph: initialGlyph,
        characterMap: characterMap,
      ),
    );
    if (!mounted || pickedGlyph == null) {
      return;
    }
    setState(() => registerDraft += pickedGlyph);
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
    final text = registerDraft.replaceAll(' ', '');
    if (text.isEmpty) {
      return;
    }
    setState(() {
      savedCharacters.insert(
        0,
        SavedCharacter(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: text,
          memo: memoController.text.trim(),
        ),
      );
      memoController.clear();
      registerDraft = '';
      currentMode = LearningMode.collection;
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
      setState(() => inputStatus = 'この入力モードではその入力方法は使えません');
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
      inputStatus = '${pointerLabel(event.kind)} | 圧力 ${pressure.toStringAsFixed(2)} | ${toolStyle.label}';
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

  void resetPractice() {
    setState(() {
      drawnStrokes.clear();
      activeSamples = [];
      inputStatus = '入力待ち';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              HeroCard(character: selectedCharacter, mode: currentMode),
              const SizedBox(height: 18),
              buildModeSwitch(),
              const SizedBox(height: 18),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: switch (currentMode) {
                    LearningMode.model => buildScrollableContent(
                        key: const ValueKey(LearningMode.model),
                        child: buildModelLayout(),
                      ),
                    LearningMode.practice => KeyedSubtree(
                        key: const ValueKey(LearningMode.practice),
                        child: buildPracticeLayout(),
                      ),
                    LearningMode.collection => buildScrollableContent(
                        key: const ValueKey(LearningMode.collection),
                        child: buildCollectionLayout(),
                      ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildScrollableContent({required Key key, required Widget child}) {
    return KeyedSubtree(
      key: key,
      child: SingleChildScrollView(child: child),
    );
  }

  Widget buildModeSwitch() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
      ),
      child: SegmentedButton<LearningMode>(
        segments: const [
          ButtonSegment(value: LearningMode.model, label: Text('見本モード')),
          ButtonSegment(value: LearningMode.practice, label: Text('練習モード')),
          ButtonSegment(value: LearningMode.collection, label: Text('マイリスト')),
        ],
        selected: {currentMode},
        onSelectionChanged: (selection) => setState(() => currentMode = selection.first),
      ),
    );
  }

  Widget buildModelLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < 900;
        if (singleColumn) {
          return Column(
            children: [
              buildModelPanel(),
              const SizedBox(height: 18),
              buildModelBoard(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: buildModelPanel()),
            const SizedBox(width: 18),
            Expanded(child: buildModelBoard()),
          ],
        );
      },
    );
  }

  Widget buildPracticeLayout() {
    if (!practiceSetupDone) {
      return SingleChildScrollView(child: buildPracticeSetupCard());
    }

    return Column(
      children: [
        PanelCard(
          title: '練習ヘッダー',
          kicker: 'Practice',
          trailing: inputStatus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CharacterPickerButton(
                      label: '文字を検索して変更',
                      character: selectedCharacter,
                      onTap: () => pickSingleCharacter(
                        title: '練習する文字を検索',
                        initialCharacter: selectedCharacter,
                        onSelected: selectCharacter,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => practiceSetupDone = false),
                    child: const Text('設定変更'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 140,
                child: CharacterMiniBoard(character: selectedCharacter, style: toolStyle),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: PanelCard(
            title: '練習ボード',
            kicker: 'Practice Board',
            trailing: toolStyle.label,
            child: Column(
              children: [
                Expanded(
                  child: Listener(
                    onPointerDown: startStroke,
                    onPointerMove: updateStroke,
                    onPointerUp: (_) => endStroke(),
                    onPointerCancel: (_) => endStroke(),
                    child: SizedBox.expand(
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
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonal(onPressed: resetPractice, child: const Text('練習を消す')),
                    OutlinedButton(
                      onPressed: () => setState(() => showGhostModel = !showGhostModel),
                      child: Text(showGhostModel ? '下書きを隠す' : '下書きを表示'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildCollectionLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < 980;
        if (singleColumn) {
          return Column(
            children: [
              buildRegisterPanel(),
              const SizedBox(height: 18),
              buildSavedPanel(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: buildRegisterPanel()),
            const SizedBox(width: 18),
            Expanded(flex: 6, child: buildSavedPanel()),
          ],
        );
      },
    );
  }

  Widget buildModelPanel() {
    return PanelCard(
      title: '見本モード',
      kicker: 'Character',
      trailing: selectedCharacter.hasStrokeModel
          ? '$shownStrokeCount / ${selectedCharacter.strokes.length} 画'
          : '楷書見本',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CharacterPickerButton(
            label: '文字を検索して選ぶ',
            character: selectedCharacter,
            onTap: () => pickSingleCharacter(
              title: '見本にする文字を検索',
              initialCharacter: selectedCharacter,
              onSelected: selectCharacter,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: selectedCharacter.hasStrokeModel ? playModel : null,
                child: const Text('再生'),
              ),
              FilledButton.tonal(
                onPressed: selectedCharacter.hasStrokeModel ? revealNextStroke : null,
                child: const Text('一画ずつ'),
              ),
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
          Text(
            selectedCharacter.hasStrokeModel
                ? '見本の字は楷書系フォントで表示し、見本ボードでも補助線つきで確認できます。'
                : 'この文字は楷書系フォントの見本表示に対応しています。書き順データはまだ入っていません。',
          ),
          if (selectedCharacter.hasStrokeModel) ...[
            const SizedBox(height: 14),
            for (var i = 0; i < selectedCharacter.strokes.length; i++)
              NoteTile(index: i + 1, text: selectedCharacter.strokes[i].note),
          ],
        ],
      ),
    );
  }

  Widget buildModelBoard() {
    return PanelCard(
      title: '見本ボード',
      kicker: 'Model',
      trailing: '楷書 + 補助線',
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

  Widget buildPracticeSetupCard() {
    return PanelCard(
      title: '練習の準備',
      kicker: 'Practice Setup',
      trailing: '最初だけ設定',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CharacterPickerButton(
            label: '練習する文字を検索',
            character: selectedCharacter,
            onTap: () => pickSingleCharacter(
              title: '練習する文字を検索',
              initialCharacter: selectedCharacter,
              onSelected: selectCharacter,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<WritingTool>(
            initialValue: selectedTool,
            decoration: const InputDecoration(labelText: '筆記具', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: WritingTool.brushPen, child: Text('筆ペン')),
              DropdownMenuItem(value: WritingTool.ballpoint, child: Text('ボールペン')),
              DropdownMenuItem(value: WritingTool.pencil, child: Text('えんぴつ')),
            ],
            onChanged: (value) => setState(() => selectedTool = value ?? selectedTool),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<InputMode>(
            initialValue: inputMode,
            decoration: const InputDecoration(labelText: '入力モード', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: InputMode.penPreferred, child: Text('ペン優先')),
              DropdownMenuItem(value: InputMode.penOnly, child: Text('ペンのみ')),
              DropdownMenuItem(value: InputMode.touchAndMouse, child: Text('指・マウスも可')),
            ],
            onChanged: (value) => setState(() => inputMode = value ?? inputMode),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('見本のうすい下書きを表示'),
            value: showGhostModel,
            onChanged: (value) => setState(() => showGhostModel = value),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => setState(() => practiceSetupDone = true),
            child: const Text('この設定で練習を始める'),
          ),
        ],
      ),
    );
  }

  Widget buildRegisterPanel() {
    return PanelCard(
      title: '文字を登録',
      kicker: 'My List',
      trailing: '縦書きで保存',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: appendRegisterCharacter,
            icon: const Icon(Icons.search),
            label: const Text('ひらがな・カタカナ・漢字から1文字追加'),
          ),
          const SizedBox(height: 14),
          RegisterDraftPreview(text: registerDraft, resolver: modelForGlyph),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(onPressed: addSavedCharacter, child: const Text('学習リストに追加')),
              OutlinedButton(
                onPressed: registerDraft.isEmpty ? null : () => setState(() => registerDraft = ''),
                child: const Text('文字をクリア'),
              ),
              OutlinedButton(
                onPressed: registerDraft.isEmpty
                    ? null
                    : () => setState(() => registerDraft = registerDraft.substring(0, registerDraft.length - 1)),
                child: const Text('1文字戻す'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: memoController,
            decoration: const InputDecoration(
              labelText: 'メモ',
              hintText: '例: 日本語をまとめて練習する',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSavedPanel() {
    return PanelCard(
      title: '登録した文字',
      kicker: 'Saved',
      trailing: '${savedCharacters.length} 件',
      child: savedCharacters.isEmpty
          ? const EmptyTile(message: 'まだ登録がありません。検索から1文字ずつ追加して、縦書きの練習セットを作れます。')
          : Column(
              children: [
                for (final item in savedCharacters)
                  SavedCharacterTile(
                    item: item,
                    resolver: modelForGlyph,
                    onSelect: () => selectCharacter(modelForGlyph(item.text.characters.first)),
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
  const HeroCard({super.key, required this.character, required this.mode});

  final CharacterModel character;
  final LearningMode mode;

  String get modeTitle {
    switch (mode) {
      case LearningMode.model:
        return '見本モード';
      case LearningMode.practice:
        return '練習モード';
      case LearningMode.collection:
        return 'マイリスト';
    }
  }

  String get modeDescription {
    switch (mode) {
      case LearningMode.model:
        return '見本の文字は楷書系フォントで表示し、見本ボードでも補助線つきで確認できます。';
      case LearningMode.practice:
        return '練習中はスクロールしない固定レイアウトです。上の見本を見て、そのまま下の練習ボードに書けます。';
      case LearningMode.collection:
        return 'ひらがな・カタカナ・漢字から1文字ずつ選び、縦書きの語として登録できます。';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFFFFF7E3), Color(0xFFF2E5D1)]),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final singleColumn = constraints.maxWidth < 820;
          return Flex(
            direction: singleColumn ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Moji Practice App'),
                    const SizedBox(height: 10),
                    const Text('もじれん', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text(modeDescription),
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
                    Text(modeTitle),
                    const SizedBox(height: 8),
                    Text(character.glyph, style: kaishoDisplayStyle(context).copyWith(fontSize: 56)),
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
      width: double.infinity,
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
              Expanded(child: Text('$kicker\n$title', style: const TextStyle(fontWeight: FontWeight.w700))),
              Flexible(child: Text(trailing, textAlign: TextAlign.right)),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class CharacterPickerButton extends StatelessWidget {
  const CharacterPickerButton({
    super.key,
    required this.label,
    required this.character,
    required this.onTap,
  });

  final String label;
  final CharacterModel character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD7BDA1)),
          color: const Color(0xFFFFFBF5),
        ),
        child: Row(
          children: [
            Text(character.glyph, style: kaishoDisplayStyle(context).copyWith(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(character.reading.isEmpty ? character.meaning : '${character.reading} | ${character.meaning}'),
                ],
              ),
            ),
            const Icon(Icons.search),
          ],
        ),
      ),
    );
  }
}

class CharacterMiniBoard extends StatelessWidget {
  const CharacterMiniBoard({
    super.key,
    required this.character,
    required this.style,
  });

  final CharacterModel character;
  final ToolStyle style;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: CustomPaint(
        painter: ModelPainter(
          character: character,
          shownStrokeCount: character.strokes.length,
          style: style,
          showNotes: false,
          showStrokeNumbers: false,
          showReferenceGlyph: true,
        ),
      ),
    );
  }
}

class CharacterSearchDialog extends StatefulWidget {
  const CharacterSearchDialog({
    super.key,
    required this.title,
    required this.initialGlyph,
    required this.characterMap,
  });

  final String title;
  final String initialGlyph;
  final Map<String, CharacterModel> characterMap;

  @override
  State<CharacterSearchDialog> createState() => _CharacterSearchDialogState();
}

class _CharacterSearchDialogState extends State<CharacterSearchDialog> {
  late final TextEditingController searchController;
  late JapaneseScript selectedScript;
  String query = '';

  @override
  void initState() {
    super.initState();
    selectedScript = detectScript(widget.initialGlyph);
    searchController = TextEditingController(text: widget.initialGlyph);
    query = widget.initialGlyph;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = buildGlyphResults(selectedScript, query).take(120).toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              SegmentedButton<JapaneseScript>(
                segments: const [
                  ButtonSegment(value: JapaneseScript.hiragana, label: Text('ひらがな')),
                  ButtonSegment(value: JapaneseScript.katakana, label: Text('カタカナ')),
                  ButtonSegment(value: JapaneseScript.kanji, label: Text('漢字')),
                ],
                selected: {selectedScript},
                onSelectionChanged: (selection) => setState(() => selectedScript = selection.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: selectedScript == JapaneseScript.kanji ? '漢字を1文字入力' : '1文字を検索',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => query = value.trim()),
              ),
              const SizedBox(height: 14),
              if (selectedScript == JapaneseScript.kanji && query.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('漢字は多いので、1文字入力して検索してください。'),
                ),
              Expanded(
                child: ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final glyph = results[index];
                    final model = widget.characterMap[glyph];
                    final subtitle = model == null
                        ? '${scriptLabel(selectedScript)} | 見本表示'
                        : [model.reading, model.meaning].where((text) => text.isNotEmpty).join(' | ');
                    return ListTile(
                      leading: Text(glyph, style: kaishoDisplayStyle(context).copyWith(fontSize: 28)),
                      title: Text(glyph),
                      subtitle: Text(subtitle),
                      onTap: () => Navigator.of(context).pop(glyph),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterDraftPreview extends StatelessWidget {
  const RegisterDraftPreview({
    super.key,
    required this.text,
    required this.resolver,
  });

  final String text;
  final CharacterModel Function(String glyph) resolver;

  @override
  Widget build(BuildContext context) {
    final glyphs = text.characters.where((glyph) => glyph.trim().isNotEmpty).toList();
    if (glyphs.isEmpty) {
      return const EmptyTile(message: 'まだ文字が入っていません。検索で1文字ずつ追加してください。');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3CBB0)),
      ),
      child: Column(
        children: [
          for (final glyph in glyphs) ...[
            SizedBox(
              width: 120,
              height: 120,
              child: CharacterMiniBoard(
                character: resolver(glyph),
                style: ToolStyle.fromTool(WritingTool.brushPen),
              ),
            ),
            if (glyph != glyphs.last) const SizedBox(height: 10),
          ],
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
          CircleAvatar(radius: 14, backgroundColor: const Color(0xFFF7D4C5), child: Text('$index')),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
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
    required this.resolver,
    required this.onSelect,
    required this.onDelete,
  });

  final SavedCharacter item;
  final CharacterModel Function(String glyph) resolver;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final glyphs = item.text.characters.where((glyph) => glyph.trim().isNotEmpty).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3CBB0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Column(
              children: [
                for (final glyph in glyphs) ...[
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CharacterMiniBoard(
                      character: resolver(glyph),
                      style: ToolStyle.fromTool(WritingTool.brushPen),
                    ),
                  ),
                  if (glyph != glyphs.last) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.text, style: kaishoDisplayStyle(context).copyWith(fontSize: 28)),
                const SizedBox(height: 6),
                Text(item.memo.isEmpty ? 'メモなし' : item.memo),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(onPressed: onSelect, child: const Text('開く')),
                    OutlinedButton(onPressed: onDelete, child: const Text('削除')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle kaishoDisplayStyle(BuildContext context) {
  return Theme.of(context).textTheme.displayMedium!.copyWith(
        fontFamily: 'YuKyokasho',
        fontFamilyFallback: const [
          'STKaiti',
          'Kaiti SC',
          'Hiragino Mincho ProN',
          'Yu Mincho',
          'serif',
        ],
        fontWeight: FontWeight.w500,
        height: 1.1,
      );
}

JapaneseScript detectScript(String glyph) {
  if (glyph.isEmpty) {
    return JapaneseScript.kanji;
  }
  final code = glyph.runes.first;
  if (code >= 0x3041 && code <= 0x3096) {
    return JapaneseScript.hiragana;
  }
  if (code >= 0x30A1 && code <= 0x30FA) {
    return JapaneseScript.katakana;
  }
  return JapaneseScript.kanji;
}

String scriptLabel(JapaneseScript script) {
  switch (script) {
    case JapaneseScript.hiragana:
      return 'ひらがな';
    case JapaneseScript.katakana:
      return 'カタカナ';
    case JapaneseScript.kanji:
      return '漢字';
  }
}

Iterable<String> buildGlyphResults(JapaneseScript script, String query) sync* {
  switch (script) {
    case JapaneseScript.hiragana:
      for (var code = 0x3041; code <= 0x3096; code++) {
        final glyph = String.fromCharCode(code);
        if (query.isEmpty || glyph.contains(query)) {
          yield glyph;
        }
      }
      return;
    case JapaneseScript.katakana:
      for (var code = 0x30A1; code <= 0x30FA; code++) {
        final glyph = String.fromCharCode(code);
        if (query.isEmpty || glyph.contains(query)) {
          yield glyph;
        }
      }
      return;
    case JapaneseScript.kanji:
      if (query.isEmpty) {
        return;
      }
      for (final glyph in query.characters) {
        if (detectScript(glyph) == JapaneseScript.kanji) {
          yield glyph;
        }
      }
  }
}
