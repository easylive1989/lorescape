#!/usr/bin/env python3
"""把 writer vault 的龐貝景點包匯入 vn/assets/。可重跑。

用法：
    python3 vn/tool/import_pack.py [--webp] [--no-cache]

本階段只做「複製與去重」。去背與對齊在 Task 6 / Task 7 接進 process_sprite()。
"""
import argparse, hashlib, json, pathlib, shutil, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'writer/創作/龐貝/stories'
OUT = ROOT / 'vn/assets/content/pompeii-79'

PACK_TITLE = '龐貝 79'
PACK_PLACE = '龐貝'
PACK_BLURB = '同一座城，同一場災難，八個人各自的最後一個選擇。'


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
    """本階段原樣複製。Task 6 在此接去背，Task 7 接對齊。"""
    shutil.copyfile(src, dest)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--webp', action='store_true', help='轉 WebP（送審前才開）')
    ap.add_argument('--no-cache', action='store_true')
    a = ap.parse_args()
    import_pack(webp=a.webp, use_cache=not a.no_cache)
