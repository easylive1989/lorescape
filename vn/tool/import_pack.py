#!/usr/bin/env python3
"""把 writer vault 的龐貝景點包匯入 vn/assets/。可重跑。

用法：
    python3 vn/tool/import_pack.py [--webp] [--no-cache]

立繪去背在 Task 7 接進 process_asset()（見 remove_background()）；表情差分對齊留給 Task 8。
"""
import argparse, collections, hashlib, json, pathlib, shutil, sys
from PIL import Image, ImageFilter
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'writer/創作/龐貝/stories'
OUT = ROOT / 'vn/assets/content/pompeii-79'

PACK_TITLE = '龐貝 79'
PACK_PLACE = '龐貝'
PACK_BLURB = '同一座城，同一場災難，八個人各自的最後一個選擇。'

CACHE = ROOT / 'writer/創作/龐貝/美術測試/_processed'
REVIEW = ROOT / 'vn/tool/_review'

# 灰底判定的容差。AI 出的平灰底其實有輕微雜訊，純等值比對會留下一圈麻點。
BG_TOLERANCE = 26


def remove_background(src: pathlib.Path):
    """平灰底 → alpha。只從四邊界往內泛洪，避免把人物內部的灰色一起吃掉。

    為什麼是泛洪而不是「所有接近灰的像素都設透明」：維比婭的斗篷是灰綠色、
    多個角色有灰白頭髮，用顏色判定會在人物身上打洞。泛洪只吃「與邊界連通」
    的區域，人物內部再灰也不會被碰到。
    """
    img = Image.open(src).convert('RGB')
    pixels = np.asarray(img).astype(np.int16)
    h, w, _ = pixels.shape

    bg = _background_colour(pixels)
    similar = (np.abs(pixels - bg).max(axis=2) <= BG_TOLERANCE)

    # 從邊界泛洪（4 連通的 BFS，用 numpy 的逐列擴張代替遞迴）
    reachable = np.zeros((h, w), dtype=bool)
    reachable[0, :] |= similar[0, :]
    reachable[-1, :] |= similar[-1, :]
    reachable[:, 0] |= similar[:, 0]
    reachable[:, -1] |= similar[:, -1]
    while True:
        grown = reachable.copy()
        grown[1:, :] |= reachable[:-1, :]
        grown[:-1, :] |= reachable[1:, :]
        grown[:, 1:] |= reachable[:, :-1]
        grown[:, :-1] |= reachable[:, 1:]
        grown &= similar
        if grown.sum() == reachable.sum():
            break
        reachable = grown

    alpha = np.where(reachable, 0, 255).astype(np.uint8)
    out = Image.fromarray(np.dstack([np.asarray(img), alpha]), mode='RGBA')
    # 1px 羽化：去背邊緣會有一圈灰，模糊 alpha 讓它過渡掉。
    blurred = out.getchannel('A').filter(ImageFilter.GaussianBlur(radius=1.0))
    out.putalpha(blurred)
    return out


def _background_colour(pixels):
    """取邊界像素的**眾數**當背景色。

    不要用「四角中位數」——這批立繪是半身像，人物的衣服延伸到畫面下緣，
    **下面兩角取到的是人物本身**。實測 vibia_neutral 的下緣兩角是 (91,80,55)
    與 (84,74,47)，那是她的橄欖綠斗篷；混進中位數會把背景估成 (135,129,112)，
    與真正的背景 (150,149,148) 差了 37，超過容差，於是泛洪從邊界長不出去、
    幾乎沒去到背景。

    眾數則對「人物佔掉一部分邊界」免疫：實測 44 張，背景色都是邊界的最大宗
    （佔 56–72%），且沒有任何一張的人物碰到上緣。
    """
    height, width, _ = pixels.shape
    border = np.concatenate([
        pixels[0:4, :].reshape(-1, 3), pixels[height - 4:, :].reshape(-1, 3),
        pixels[:, 0:4].reshape(-1, 3), pixels[:, width - 4:].reshape(-1, 3),
    ])
    # 量化到 /8 再數，避免 JPEG 式雜訊把同一個顏色拆成幾十種。
    quantised = border // 8
    counts = collections.Counter(map(tuple, quantised))
    return np.array(counts.most_common(1)[0][0]) * 8 + 4


def write_review(name: str, before, after) -> None:
    """把去背前後拼成一張對照圖，人工驗收用。"""
    REVIEW.mkdir(parents=True, exist_ok=True)
    checker = Image.new('RGB', after.size, (220, 60, 160))  # 洋紅底，殘留的灰會很明顯
    checker.paste(after, (0, 0), after)
    canvas = Image.new('RGB', (before.width * 2, before.height))
    canvas.paste(before.convert('RGB'), (0, 0))
    canvas.paste(checker, (before.width, 0))
    canvas.resize((canvas.width // 3, canvas.height // 3)).save(REVIEW / f'cutout_{name}')


def slug_of(meta_id: str) -> str:
    """'pompeii_01_harbour_stranger' -> '01-harbour-stranger'"""
    _pack, order, *rest = meta_id.split('_')
    return f"{order}-{'-'.join(rest).replace('_', '-')}"


def collect_assets(story_dirs):
    """回傳 {('backgrounds'|'sprites', basename): 來源路徑}，同名不同內容即中止。"""
    picked, digests = {}, {}
    for d in story_dirs:
        for kind in ('backgrounds', 'sprites'):
            for path in sorted((d / 'assets' / kind).glob('*.png')):
                key = (kind, path.name)
                digest = hashlib.md5(path.read_bytes()).hexdigest()
                if key in digests and digests[key] != digest:
                    sys.exit(f'✗ 同名不同內容：{key} 於 {path}')
                digests.setdefault(key, digest)
                picked.setdefault(key, path)
    return picked


def verify(story_paths) -> None:
    missing = []
    for p in story_paths:
        s = json.loads(p.read_text(encoding='utf-8'))
        for filename in s['backgrounds'].values():
            if not (OUT / 'assets/backgrounds' / filename).exists():
                missing.append(filename)
        for char in s['characters'].values():
            for filename in (char.get('sprites') or {}).values():
                if not (OUT / 'assets/sprites' / filename).exists():
                    missing.append(filename)
    if missing:
        sys.exit(f'✗ 參照的檔案不存在：{sorted(set(missing))}')


def import_pack(webp: bool = False, use_cache: bool = True) -> dict:
    story_dirs = sorted(d for d in SRC.iterdir() if d.is_dir() and (d / 'story.json').exists())
    if len(story_dirs) != 8:
        sys.exit(f'✗ 預期 8 篇，實際 {len(story_dirs)}')

    for kind in ('backgrounds', 'sprites', 'audio'):
        (OUT / 'assets' / kind).mkdir(parents=True, exist_ok=True)

    entries, copied_scripts = [], []
    for d in story_dirs:
        src_json = d / 'story.json'
        meta = json.loads(src_json.read_text(encoding='utf-8'))['meta']
        dest_dir = OUT / 'stories' / slug_of(meta['id'])
        dest_dir.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src_json, dest_dir / 'story.json')  # 逐字複製
        copied_scripts.append(dest_dir / 'story.json')
        entries.append({
            'id': meta['id'], 'order': meta['order'], 'dir': slug_of(meta['id']),
            'title': meta['title'], 'subtitle': meta.get('subtitle', ''),
            'estimatedMinutes': meta['estimatedMinutes'],
        })

    picked = collect_assets(story_dirs)
    for (kind, name), src_path in sorted(picked.items()):
        process_asset(kind, src_path, OUT / 'assets' / kind / name, webp, use_cache)

    entries.sort(key=lambda e: e['order'])
    pack = {'id': 'pompeii_79', 'title': PACK_TITLE, 'place': PACK_PLACE,
            'blurb': PACK_BLURB, 'stories': entries}
    (OUT / 'pack.json').write_text(
        json.dumps(pack, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    verify(copied_scripts)
    print(f'✅ 8 篇、{len(picked)} 張素材、pack.json 完成')
    return pack


def process_asset(kind: str, src: pathlib.Path, dest: pathlib.Path,
                  webp: bool, use_cache: bool) -> None:
    if kind != 'sprites':
        shutil.copyfile(src, dest)   # 背景不去背
        return
    CACHE.mkdir(parents=True, exist_ok=True)
    digest = hashlib.md5(src.read_bytes()).hexdigest()
    cached = CACHE / f'{digest}_cutout.png'
    if use_cache and cached.exists():
        shutil.copyfile(cached, dest)
        return
    cutout = remove_background(src)
    cutout.save(cached)
    shutil.copyfile(cached, dest)
    write_review(src.name, Image.open(src), cutout)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--webp', action='store_true', help='轉 WebP（送審前才開）')
    ap.add_argument('--no-cache', action='store_true')
    a = ap.parse_args()
    import_pack(webp=a.webp, use_cache=not a.no_cache)
