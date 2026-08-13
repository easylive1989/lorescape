import json, subprocess, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'vn/assets/content/pompeii-79'

def test_slug_strips_order_prefix():
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    from import_pack import slug_of
    assert slug_of('pompeii_01_harbour_stranger') == '01-harbour-stranger'
    assert slug_of('pompeii_08_the_new_house') == '08-the-new-house'

def test_import_produces_eight_stories_and_dedup_assets():
    subprocess.run([sys.executable, str(ROOT / 'vn/tool/import_pack.py')], check=True)
    pack = json.loads((OUT / 'pack.json').read_text(encoding='utf-8'))
    assert len(pack['stories']) == 8
    assert [s['order'] for s in pack['stories']] == list(range(1, 9))
    # 116 份重複參照去重成 57 張唯一檔
    bgs = list((OUT / 'assets/backgrounds').glob('*.png'))
    sprites = list((OUT / 'assets/sprites').glob('*.png'))
    assert len(bgs) == 16, len(bgs)      # 15 背景 + cg_column_rising
    assert len(sprites) == 44, len(sprites)

def test_scripts_are_copied_verbatim():
    src = ROOT / 'writer/創作/龐貝/stories/01_港口的外地人/story.json'
    dst = OUT / 'stories/01-harbour-stranger/story.json'
    assert dst.read_bytes() == src.read_bytes()

def test_every_referenced_asset_exists():
    for story_dir in sorted((OUT / 'stories').iterdir()):
        s = json.loads((story_dir / 'story.json').read_text(encoding='utf-8'))
        for filename in s['backgrounds'].values():
            assert (OUT / 'assets/backgrounds' / filename).exists(), filename
        for char in s['characters'].values():
            for filename in (char.get('sprites') or {}).values():
                assert (OUT / 'assets/sprites' / filename).exists(), filename
