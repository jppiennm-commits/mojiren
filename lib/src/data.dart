import 'package:flutter/services.dart';

import 'models.dart';

class CharacterRepository {
  const CharacterRepository();

  static const assetPath = 'assets/kanji/characters.json';

  Future<List<CharacterModel>> loadCharacters() async {
    final raw = await rootBundle.loadString(assetPath);
    return CharacterModel.listFromJson(raw);
  }
}
