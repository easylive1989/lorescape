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

def test_sprites_have_alpha_and_opaque_subject():
    from PIL import Image
    import numpy as np
    img = Image.open(OUT / 'assets/sprites/vibia_neutral.png')
    assert img.mode == 'RGBA', img.mode
    a = np.asarray(img)[:, :, 3]
    # 四角應該全透明（那是被去掉的灰底）
    assert a[0, 0] == 0 and a[0, -1] == 0, '左右上角沒去乾淨'
    # 中央偏下應該是人物，全不透明
    h, w = a.shape
    assert a[int(h * 0.6), int(w * 0.5)] == 255, '人物被啃掉了'
    # 透明佔比要落在合理區間——太低表示沒去到，太高表示啃過頭
    # 實測 44 張落在 0.337–0.508，區間取 0.25–0.60 留一點餘裕但不至於形同虛設。
    ratio = float((a == 0).mean())
    assert 0.25 < ratio < 0.60, f'透明佔比異常：{ratio:.2f}'


def _interior_islands(alpha):
    """回傳「不與畫面邊界連通的透明像素數」——會透出背景的破洞。"""
    import numpy as np
    transparent = alpha <= 127
    h, w = transparent.shape
    reach = np.zeros((h, w), dtype=bool)
    reach[0, :] |= transparent[0, :]
    reach[-1, :] |= transparent[-1, :]
    reach[:, 0] |= transparent[:, 0]
    reach[:, -1] |= transparent[:, -1]
    while True:
        grown = reach.copy()
        grown[1:, :] |= reach[:-1, :]
        grown[:-1, :] |= reach[1:, :]
        grown[:, 1:] |= reach[:, :-1]
        grown[:, :-1] |= reach[:, 1:]
        grown &= transparent
        if grown.sum() == reach.sum():
            break
        reach = grown
    return int((transparent & ~reach).sum())


def test_no_interior_holes():
    """閉運算會把咬痕的頸部填掉、讓殘骸變成孤島，_fill_interior 負責收拾。

    孤島 ＝ 人物身上會透出背景的破洞，一個都不該留。
    """
    from PIL import Image
    import numpy as np
    for path in sorted((OUT / 'assets/sprites').glob('*.png')):
        alpha = np.asarray(Image.open(path).convert('RGBA').getchannel('A')).astype(int)
        assert _interior_islands(alpha) == 0, f'{path.name} 有內部破洞'


def test_genuine_gaps_are_not_bridged():
    """尼基亞斯手臂與軀幹之間的縫隙不得被閉運算夾斷。

    這是 CLOSE_RADIUS 從 7 降到 4 的原因。**這個回歸在「透明比例」上量不到**
    ——r=7 時尼基亞斯的主體佔比只多 0.16 個百分點，看起來完全安全，實際上
    那條縫隙已經被從中間夾斷、上半段封成 3,150px 的孤島，再被 _fill_interior
    填實。只有量特定區域的拓樸才抓得到。
    """
    from PIL import Image
    import numpy as np
    for path in sorted((OUT / 'assets/sprites').glob('nikias_*.png')):
        alpha = np.asarray(Image.open(path).convert('RGBA').getchannel('A')).astype(int)
        gap = alpha[1250:1500, 150:280] <= 127
        # 實測四張表情都是 13.0–13.7%；被夾斷後會掉到 3% 左右。
        assert gap.mean() > 0.08, f'{path.name} 的手臂縫隙被填掉了：{gap.mean():.3f}'


def test_backgrounds_stay_opaque():
    from PIL import Image
    img = Image.open(OUT / 'assets/backgrounds/bg_harbour.png')
    assert img.mode in ('RGB', 'RGBA')
    if img.mode == 'RGBA':
        import numpy as np
        assert np.asarray(img)[:, :, 3].min() == 255, '背景不該被去背'
