# 漢字データ取り込み

このアプリは `assets/kanji/characters.json` を読み込みます。

## 推奨ソース

- 書き順: KanjiVG
- 読み・意味: KANJIDIC2

## 置き場所の例

- `vendor/kanjivg/` に KanjiVG の SVG 一式
- `vendor/kanjidic2/kanjidic2.xml` に KANJIDIC2
- `vendor/joyo.txt` に取り込みたい漢字一覧

## 生成コマンド

```powershell
dart run tool/build_kanji_assets.dart vendor/kanjivg vendor/kanjidic2/kanjidic2.xml assets/kanji/characters.json vendor/joyo.txt
```

## 出力形式

```json
[
  {
    "id": "06c38",
    "glyph": "水",
    "reading": "スイ / みず",
    "meaning": "water",
    "strokes": [
      {
        "points": [[50.0, 18.0], [50.0, 76.0]],
        "note": "",
        "notePos": [50.0, 18.0]
      }
    ]
  }
]
```

## 補足

- このスクリプトは最初の取り込み土台です。
- `note` は空で出るので、止め・はね・はらいの注記は後段で補完します。
- KanjiVG の `d` パスは簡易抽出しているため、必要ならベジェ曲線対応を追加してください。
