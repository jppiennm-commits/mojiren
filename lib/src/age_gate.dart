import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AudienceAgeGroup { under13, over13 }

extension AudienceAgeGroupText on AudienceAgeGroup {
  String get label => this == AudienceAgeGroup.under13 ? '13歳未満' : '13歳以上';

  String get adLabel => this == AudienceAgeGroup.under13 ? '制限広告' : '通常広告';

  String get description => this == AudienceAgeGroup.under13
      ? 'パーソナライズなしの安全な広告設定'
      : '通常の広告設定';
}

class AgePreferenceStore {
  static const _storageKey = 'audience_age_group_v1';

  const AgePreferenceStore();

  Future<AudienceAgeGroup?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_storageKey);
    switch (value) {
      case 'under13':
        return AudienceAgeGroup.under13;
      case 'over13':
        return AudienceAgeGroup.over13;
      default:
        return null;
    }
  }

  Future<void> save(AudienceAgeGroup group) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      group == AudienceAgeGroup.under13 ? 'under13' : 'over13',
    );
  }
}

class AgeGateController extends ChangeNotifier {
  AgeGateController(this._group);

  AudienceAgeGroup _group;

  AudienceAgeGroup get group => _group;

  Future<void> update(AudienceAgeGroup group) async {
    await const AgePreferenceStore().save(group);
    _group = group;
    notifyListeners();
  }
}

class AgeGateScope extends InheritedNotifier<AgeGateController> {
  const AgeGateScope({
    super.key,
    required AgeGateController controller,
    required super.child,
  }) : super(notifier: controller);

  static AgeGateController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AgeGateScope>()?.notifier;
  }
}

class AgeGateShell extends StatefulWidget {
  const AgeGateShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AgeGateShell> createState() => _AgeGateShellState();
}

class _AgeGateShellState extends State<AgeGateShell> {
  AgeGateController? controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final group = await const AgePreferenceStore().load();
    if (!mounted) {
      return;
    }
    if (group == null) {
      setState(() => controller = null);
      return;
    }
    setState(() => controller = AgeGateController(group));
  }

  Future<void> _select(AudienceAgeGroup group) async {
    final next = AgeGateController(group);
    await next.update(group);
    if (!mounted) {
      return;
    }
    setState(() => controller = next);
  }

  @override
  Widget build(BuildContext context) {
    final current = controller;
    if (current == null) {
      return AudienceAgeGateScreen(onSelect: _select);
    }
    return AgeGateScope(
      controller: current,
      child: widget.child,
    );
  }
}

class AudienceAgeGateScreen extends StatelessWidget {
  const AudienceAgeGateScreen({
    super.key,
    required this.onSelect,
  });

  final Future<void> Function(AudienceAgeGroup group) onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0x1F6B4F28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '年齢設定',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Text('あなたは13歳未満ですか？'),
                    const SizedBox(height: 8),
                    const Text(
                      '年齢に応じて広告の表示方法を切り替えます。設定画面から後で変更できます。',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => onSelect(AudienceAgeGroup.under13),
                        child: const Text('はい'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => onSelect(AudienceAgeGroup.over13),
                        child: const Text('いいえ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AudienceSettingsSheet extends StatelessWidget {
  const AudienceSettingsSheet({
    super.key,
    required this.currentGroup,
    required this.onChanged,
  });

  final AudienceAgeGroup currentGroup;
  final Future<void> Function(AudienceAgeGroup group) onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '年齢設定',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text('現在: ${currentGroup.label} / ${currentGroup.adLabel}'),
            const SizedBox(height: 16),
            for (final group in AudienceAgeGroup.values) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(group.label),
                subtitle: Text(group.description),
                trailing: currentGroup == group ? const Icon(Icons.check) : null,
                onTap: () async {
                  await onChanged(group);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              if (group != AudienceAgeGroup.values.last) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}
