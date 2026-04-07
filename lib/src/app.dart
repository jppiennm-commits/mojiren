import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'data.dart';
import 'models.dart';
import 'painters.dart';

enum LearningMode { model, practice, collection }

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
              child: Text('文字データの読み込みに失敗しました: ${snapshot.error}'),
            ),
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
  late CharacterModel selectedCharacter;
  late String registerCharacterId;
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

  Future<void> pickCharacter({
    required String title,
    required String initialId,
    required ValueChanged<CharacterModel> onSelected,
  }) async {
    final pickedId = await showDialog<String>(
      context: context,
      builder: (context) => CharacterSearchDialog(
        title: title,
        characters: widget.characters,
        initialId: initialId,
      ),
    );

    if (!mounted || pickedId == null) {
      return;
    }
    onSelected(findCharacter(pickedId));
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              HeroCard(character: selectedCharacter, mode: currentMode),
              const SizedBox(height: 18),
              buildModeSwitch(),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: switch (currentMode) {
                  LearningMode.model => buildModelLayout(),
                  LearningMode.practice => buildPracticeLayout(),
                  LearningMode.collection => buildCollectionLayout(),
                },
              ),
            ],
          ),
        ),
      ),
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
    return KeyedSubtree(
      key: const ValueKey(LearningMode.model),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final singleColumn = constraints.maxWidth < 900;
          return Flex(
            direction: singleColumn ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: buildModelPanel()),
              SizedBox(width: singleColumn ? 0 : 18, height: singleColumn ? 18 : 0),
              Expanded(child: buildModelBoard()),
            ],
          );
        },
      ),
    );
  }

  Widget buildPracticeLayout() {
    return KeyedSubtree(
      key: const ValueKey(LearningMode.practice),
      child: Column(
        children: [
          if (!practiceSetupDone) buildPracticeSetupCard(),
          if (practiceSetupDone) buildPracticeWorkspace(),
        ],
      ),
    );
  }

  Widget buildCollectionLayout() {
    return KeyedSubtree(
      key: const ValueKey(LearningMode.collection),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final singleColumn = constraints.maxWidth < 980;
          return Flex(
            direction: singleColumn ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: singleColumn ? 0 : 4, child: buildRegisterPanel()),
              SizedBox(width: singleColumn ? 0 : 18, height: singleColumn ? 18 : 0),
              Expanded(flex: singleColumn ? 0 : 6, child: buildSavedPanel()),
            ],
          );
        },
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
          CharacterPickerButton(
            label: '文字を検索して選ぶ',
            character: selectedCharacter,
            onTap: () => pickCharacter(
              title: '見本にする文字を検索',
              initialId: selectedCharacter.id,
              onSelected: selectCharacter,
            ),
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
          const Text('検索で文字を選んだら、中央の十字リーダーと四分割線を見ながら書き順を確認できます。'),
          const SizedBox(height: 14),
          for (var i = 0; i < selectedCharacter.strokes.length; i++)
            NoteTile(index: i + 1, text: selectedCharacter.strokes[i].note),
        ],
      ),
    );
  }

  Widget buildModelBoard() {
    return PanelCard(
      title: '見本ボード',
      kicker: 'Model',
      trailing: '補助線つき表示',
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
            onTap: () => pickCharacter(
              title: '練習する文字を検索',
              initialId: selectedCharacter.id,
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

  Widget buildPracticeWorkspace() {
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
                      onTap: () => pickCharacter(
                        title: '練習する文字を検索',
                        initialId: selectedCharacter.id,
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
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 2.1,
                child: CharacterMiniBoard(character: selectedCharacter, style: toolStyle),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PanelCard(
          title: '練習ボード',
          kicker: 'Practice Board',
          trailing: toolStyle.label,
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
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
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
        ),
      ],
    );
  }

  Widget buildRegisterPanel() {
    final registerCharacter = findCharacter(registerCharacterId);
    return PanelCard(
      title: '文字を登録',
      kicker: 'My List',
      trailing: '検索して追加',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CharacterPickerButton(
            label: '登録する文字を検索',
            character: registerCharacter,
            onTap: () => pickCharacter(
              title: '登録する文字を検索',
              initialId: registerCharacterId,
              onSelected: (character) => setState(() => registerCharacterId = character.id),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: memoController,
            decoration: const InputDecoration(
              labelText: 'メモ',
              hintText: '例: テスト前によく練習する文字',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: addSavedCharacter,
            child: const Text('学習リストに追加'),
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
          ? const EmptyTile(message: 'まだ登録がありません。左の検索から学習したい文字を追加できます。')
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
        return '検索で文字を選び、止め・はね・はらいの要点を見本で確認する画面です。';
      case LearningMode.practice:
        return '最初に筆記具と入力方法を決めたら、上の補助線つき見本と下の練習ボードに集中できます。';
      case LearningMode.collection:
        return '追加した文字が上から順に補助線つきの見本で並ぶ、復習用のリストです。';
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
            Text(character.glyph, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${character.reading} | ${character.meaning}'),
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
        ),
      ),
    );
  }
}

class CharacterSearchDialog extends StatefulWidget {
  const CharacterSearchDialog({
    super.key,
    required this.title,
    required this.characters,
    required this.initialId,
  });

  final String title;
  final List<CharacterModel> characters;
  final String initialId;

  @override
  State<CharacterSearchDialog> createState() => _CharacterSearchDialogState();
}

class _CharacterSearchDialogState extends State<CharacterSearchDialog> {
  late final TextEditingController searchController;
  String query = '';

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.characters.where((character) {
      final source = '${character.glyph} ${character.reading} ${character.meaning}'.toLowerCase();
      return source.contains(query.toLowerCase());
    }).toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  hintText: '漢字、読み、意味で検索',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final character = filtered[index];
                    final selected = character.id == widget.initialId;
                    return ListTile(
                      selected: selected,
                      leading: Text(character.glyph, style: Theme.of(context).textTheme.headlineSmall),
                      title: Text('${character.glyph} (${character.reading})'),
                      subtitle: Text(character.meaning),
                      trailing: selected ? const Icon(Icons.check_circle) : null,
                      onTap: () => Navigator.of(context).pop(character.id),
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
    final previewStyle = ToolStyle.fromTool(WritingTool.brushPen);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3CBB0)),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 2.2,
            child: CharacterMiniBoard(character: character, style: previewStyle),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
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
                  OutlinedButton(onPressed: onSelect, child: const Text('開く')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: onDelete, child: const Text('削除')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
