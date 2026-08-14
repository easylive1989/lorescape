#!/usr/bin/env python3
"""把 writer vault 的龐貝景點包匯入 story/assets/。可重跑。

用法：
    python3 story/tool/import_pack.py [--png] [--no-cache]

立繪去背見 remove_background()；表情差分對齊（Task 8）見 align_to_base()，
兩者串接於 process_sprites()。
"""
import argparse, collections, hashlib, json, pathlib, shutil, sys
from PIL import Image, ImageFilter
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'writer/創作/龐貝/stories'
OUT = ROOT / 'story/assets/content/pompeii-79'

PACK_TITLE = '龐貝 79'
PACK_PLACE = '龐貝'
PACK_BLURB = '同一座城，同一場災難，八個人各自的最後一個選擇。'

CACHE = ROOT / 'writer/創作/龐貝/美術測試/_processed'
REVIEW = ROOT / 'story/tool/_review'

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

    alpha = Image.fromarray(np.where(reachable, 0, 255).astype(np.uint8), mode='L')
    alpha = _close_bites(alpha)
    alpha = _fill_interior(np.asarray(alpha).astype(int))
    out = Image.fromarray(np.dstack([np.asarray(img), alpha]), mode='RGBA')
    # 1px 羽化：去背邊緣會有一圈灰，模糊 alpha 讓它過渡掉。
    out.putalpha(out.getchannel('A').filter(ImageFilter.GaussianBlur(radius=1.0)))
    return out


# 閉運算的半徑（px）。r=4 會填掉寬度 8px 以內的凹陷。
#
# **不要調大。** 實測掃過 r=1..9：r=5 起會橋接尼基亞斯手臂與軀幹之間的縫隙，
# 把那塊真實背景封成 3,150–3,461px 的孤島（四張表情都中）。r=4 是唯一同時
# 「填掉祭司咬痕」與「不碰真實縫隙」的窗口——祭司在 r=4 已填入 12,247px，
# 達到 r=7 的 92%。
CLOSE_RADIUS = 4


def _close_bites(alpha):
    """對主體遮罩做閉運算（先膨脹後侵蝕），填掉泛洪咬進衣服的細長凹陷。

    祭司的米白僧袍在右肩下緣的陰影剛好貼近背景灰，泛洪會沿著那裡鑽進布料，
    留下幾道深入的鋸齒——遊戲內縮到 0.72H 仍有 8–15px 寬，看起來像袍子破了。

    ⚠️ 閉運算的危險不在「多填了多少主體像素」（那個量很小、看指標會誤判安全），
    而在**它可能把一條真實的背景縫隙從中間夾斷**。判斷安全與否要看
    「有多少原本連通的背景被封成孤島」，不是看主體佔比增加多少。
    """
    binary = alpha.point(lambda v: 255 if v > 127 else 0)
    size = CLOSE_RADIUS * 2 + 1
    return binary.filter(ImageFilter.MaxFilter(size)).filter(ImageFilter.MinFilter(size))


def _fill_interior(alpha_array):
    """透明區域只有**與畫面邊界連通**的才算背景，其餘填實。

    這是把泛洪本來就依賴的那條不變式，在閉運算之後重新套一次——閉運算會把
    咬痕的「頸部」填掉，讓殘骸變成不再連通邊界的孤島。

    實測 r=4 下的孤島有兩類：祭司袍子上的咬痕殘骸（1,006–1,706px，正是要清掉
    的），以及莎爾維婭與特婭耳環圈裡的縫隙（555px／107px，遊戲內約 2px，
    填掉等於耳環變實心，看不出來）。兩類都填是對的取捨。
    """
    transparent = alpha_array <= 127
    height, width = transparent.shape
    reachable = np.zeros((height, width), dtype=bool)
    reachable[0, :] |= transparent[0, :]
    reachable[-1, :] |= transparent[-1, :]
    reachable[:, 0] |= transparent[:, 0]
    reachable[:, -1] |= transparent[:, -1]
    while True:
        grown = reachable.copy()
        grown[1:, :] |= reachable[:-1, :]
        grown[:-1, :] |= reachable[1:, :]
        grown[:, 1:] |= reachable[:, :-1]
        grown[:, :-1] |= reachable[:, 1:]
        grown &= transparent
        if grown.sum() == reachable.sum():
            break
        reachable = grown
    return np.where(reachable, 0, 255).astype(np.uint8)


def _background_colour(pixels):
    """取邊界像素的**眾數**當背景色。

    不要用「四角中位數」——這批立繪是半身像，人物的衣服延伸到畫面下緣，
    **下面兩角取到的是人物本身**。實測 vibia_neutral 的下緣兩角是 (91,80,55)
    與 (84,74,47)，那是她的橄欖綠斗篷；混進中位數會把背景估成 (135,129,112)，
    與真正的背景 (150,149,148) 差了 37，超過容差，於是泛洪從邊界長不出去、
    幾乎沒去到背景。

    眾數對「人物佔掉一部分邊界」免疫：實測 44 張，背景色都是邊界的**最大宗**
    （相對多數 18.5–84.6%，不是絕對多數），且沒有任何一張的人物碰到上緣。

    佔比最低的 philemon_neutral 只有 18.5%，是因為它的背景本身有雜訊，被 /8
    量化拆成四個相鄰 bin（合計約 53%）。它仍然能正確去背——真正的安全網是
    「相對多數勝出 ＋ 容差夠寬，把相鄰的量化 bin 一起吃進來」，**不是**
    「背景要過半」。日後有人排查新素材去背失敗，不要往「背景佔比為何偏低」
    這個方向找，那不是原因。
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


# 去背演算法的版本號。**改動 remove_background() 的行為時要手動 +1。**
PIPELINE_VERSION = 1


def _cache_key(src: pathlib.Path) -> str:
    """快取鍵要綁「來源圖 ＋ 演算法參數 ＋ 版本號」，不能只綁來源圖。

    只綁來源圖的話，調了 BG_TOLERANCE 或 CLOSE_RADIUS 卻忘記加 `--no-cache`，
    就會靜默命中舊 hash、吐出用舊參數跑出來的舊結果，而且不會有任何警告。
    這一版的三輪修正全都是「來源圖沒變、演算法變了」，正是這個坑的形狀。
    """
    stamp = f'{BG_TOLERANCE}:{CLOSE_RADIUS}:{PIPELINE_VERSION}'.encode()
    return hashlib.md5(src.read_bytes() + stamp).hexdigest()


# 對齊搜尋範圍。菲勒蒙的基底取景較近，需要縮小才對得上（進度與交接 §3）。
SCALE_RANGE = [0.88 + 0.02 * i for i in range(13)]   # 0.88 … 1.12
SHIFT_LIMIT = 72                                      # px，於 1/4 解析度上為 18


# 對齊分數的下限。低於它就不套用對齊——搜尋在弱訊號的地形上會挑出比不動更歪
# 的假最佳解（實測發生過：把一張本來就對齊的圖弄歪 132px）。
#
# **這個分數不是可靠的壞素材偵測器。** 曾經以為是：四張壞素材落在 0.60–0.93，
# 當時最低的好素材是 0.9788，看起來斷得很開。四張重出之後才看清楚——
# `hylas_scared` 的 prompt 寫著「shoulders drawn up slightly」，那個合法的姿勢
# 改變讓剪影差了 6.6%、分數只有 0.9433，跟錯掛版的 `orestes_urgent`（0.9349）
# 只差 0.008。任何門檻都會誤判其中一邊。所以這個值只留著擋「套用垃圾變換」，
# 偵測壞素材交給下面那道 exact 檢查。
ALIGN_MIN_SCORE = 0.90

# 已知有問題的立繪。**四張已於 2026-08-14 重出修好，這裡現在應該是空的。**
#
# 保留這個常數與雙向斷言：多出新的壞素材會紅，而素材修好之後沒刪這裡也會紅。
KNOWN_BAD_SPRITES: dict[str, str] = {}


def _score(a, b):
    """正規化互相關。兩張同尺寸的 numpy 陣列。"""
    a = a - a.mean()
    b = b - b.mean()
    denom = np.sqrt((a * a).sum() * (b * b).sum())
    return float((a * b).sum() / denom) if denom else -1.0


def align_to_base(base_rgba, variant_rgba):
    """把 variant 縮放 + 平移對到 base，回傳 (對齊後的 RGBA, 參數)。

    表情差分是 image-to-image 從基底生成的，兩者整體構圖高度相關，因此在
    1/4 解析度上窮舉縮放與平移、取正規化互相關分數最高的組合即可對齊——
    不需要規範原定的臉部特徵點偵測（環境沒有臉部偵測可用）。
    """
    w, h = base_rgba.size

    # **比 alpha 剪影，不要比灰階亮度。**
    #
    # 差分的原始畫布尺寸不一定與基底相同（實測 4 張是 1023×1537、officer_hard
    # 是 1122×1402，其餘 39 張才是 1024×1536）。把差分貼到基底尺寸的畫布上時，
    # 邊緣會留下一圈墊底色，而 `convert('L')` 丟掉 alpha 只看 RGB——那圈邊在
    # 互相關裡是極強的人造對比，分數整個被它主導。實測灰階法會把
    # nikias_watchful 評成 0.38 並挑出 scale 0.90 的錯誤解，把一張本來就對齊
    # 的圖弄歪 132px。
    #
    # alpha 對此免疫：透明區的值是 0，與畫布留白同值，沒有人造邊。改用 alpha
    # 之後 24/28 個差分都是 score ≥ 0.978、scale 1.00、位移 (0,0)。
    def silhouette(image):
        return np.asarray(image.getchannel('A').resize((w // 4, h // 4))).astype(np.float32)

    base_small = silhouette(base_rgba)

    best = (-1.0, 1.0, 0, 0)
    for scale in SCALE_RANGE:
        scaled = variant_rgba.resize((int(w * scale), int(h * scale)))
        canvas = Image.new('RGBA', (w, h))
        canvas.paste(scaled, ((w - scaled.width) // 2, (h - scaled.height) // 2))
        small = silhouette(canvas)
        for dy in range(-SHIFT_LIMIT // 4, SHIFT_LIMIT // 4 + 1, 2):
            for dx in range(-SHIFT_LIMIT // 4, SHIFT_LIMIT // 4 + 1, 2):
                shifted = np.roll(np.roll(small, dy, axis=0), dx, axis=1)
                score = _score(base_small, shifted)
                if score > best[0]:
                    best = (score, scale, dx * 4, dy * 4)

    score, scale, dx, dy = best
    if score < ALIGN_MIN_SCORE:
        # 分數這麼低不是「沒對齊」，是「這兩張根本不是同一個人／同一個時代」。
        # 硬套搜尋出來的最佳解只會把它縮放平移到更歪的位置——實測就發生過。
        #
        # **原封不動回傳，連畫布都不要正規化。** 貼進基底畫布看似無害，實際上
        # 會裁掉比基底寬的圖：officer_hard 是 1122×1402，置中貼進 1024×1536
        # 會左裁 49px、右裁 27px，實測損失 20,491 個不透明像素（主體的
        # 2.45%，左邊那塊是大腿）。「skipped」就該是字面意義的沒被動過。
        #
        # 尺寸不一致不影響播放：Flutter 端是 `BoxFit.fitHeight` 依高度縮放。
        return variant_rgba, {'scale': 1.0, 'dx': 0, 'dy': 0,
                              'score': round(score, 4), 'skipped': True}
    scaled = variant_rgba.resize((int(w * scale), int(h * scale)))
    out = Image.new('RGBA', (w, h))
    out.paste(scaled, ((w - scaled.width) // 2 + dx, (h - scaled.height) // 2 + dy))
    return out, {'scale': round(scale, 3), 'dx': dx, 'dy': dy, 'score': round(score, 4),
                 'skipped': False}


def write_align_review(name: str, base, before, after) -> None:
    """三聯圖：基底 / 對齊前 / 對齊後，各自疊在基底輪廓上看偏移。"""
    REVIEW.mkdir(parents=True, exist_ok=True)
    def overlay(img):
        # 少數來源圖的畫布尺寸跟基底差 1px（甚至更多，如 officer_hard 是
        # 1122x1402），「對齊前」單純貼原圖看飄移，尺寸不同就置左上角裁貼，
        # 不縮放——縮放會混淆「畫布尺寸不同」與「真的位置飄移」兩件事。
        if img.size != base.size:
            padded = Image.new('RGBA', base.size)
            padded.paste(img, (0, 0))
            img = padded
        canvas = Image.new('RGB', base.size, (18, 18, 18))
        canvas.paste(Image.new('RGB', base.size, (60, 90, 140)), (0, 0), base)
        canvas.paste(Image.new('RGB', base.size, (220, 90, 60)), (0, 0),
                     img.getchannel('A').point(lambda v: v // 2))
        return canvas
    canvas = Image.new('RGB', (base.width * 3, base.height))
    canvas.paste(base.convert('RGB'), (0, 0))
    canvas.paste(overlay(before), (base.width, 0))
    canvas.paste(overlay(after), (base.width * 2, 0))
    canvas.resize((canvas.width // 4, canvas.height // 4)).save(REVIEW / f'align_{name}')


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


def detect_duplicate_sprites(picked) -> None:
    """不同檔名、位元組完全相同的立繪 ＝ 表情差分被指到了別人的臉。

    這道檢查是 exact 的、零誤判，正好補上對齊分數量不準的那一塊：三張錯掛的
    立繪（hylas_scared≡master_impatient、orestes_urgent≡thea_afraid、
    survivor_sharp≡pliny_labored）都是位元組相同，而它們的對齊分數
    （0.79/0.93/0.80）跟合法的大幅表情變化重疊，光看分數分不出來。

    真正需要兩個角色共用同一張圖時，把它們加進 ALLOWED_DUPLICATE_SPRITES。
    """
    by_digest = {}
    for (kind, name), path in sorted(picked.items()):
        if kind != 'sprites':
            continue
        by_digest.setdefault(hashlib.md5(path.read_bytes()).hexdigest(), []).append(name)
    clashes = [
        tuple(sorted(names)) for names in by_digest.values()
        if len(names) > 1 and tuple(sorted(names)) not in ALLOWED_DUPLICATE_SPRITES
    ]
    if clashes:
        lines = '\n'.join(f'  {" ≡ ".join(c)}' for c in sorted(clashes))
        sys.exit(f'✗ 不同角色的立繪位元組相同（表情差分指錯基底？）：\n{lines}')


# 刻意讓兩個角色共用同一張圖時，把 (檔名, 檔名) 排序後加進來。
ALLOWED_DUPLICATE_SPRITES: set[tuple[str, ...]] = set()


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


def verify(story_paths, webp: bool = False) -> None:
    missing = []
    for p in story_paths:
        s = json.loads(p.read_text(encoding='utf-8'))
        for filename in s['backgrounds'].values():
            if not (OUT / 'assets/backgrounds' / asset_filename(filename, webp)).exists():
                missing.append(filename)
        for char in s['characters'].values():
            for filename in (char.get('sprites') or {}).values():
                if not (OUT / 'assets/sprites' / asset_filename(filename, webp)).exists():
                    missing.append(filename)
    if missing:
        sys.exit(f'✗ 參照的檔案不存在：{sorted(set(missing))}')


# WebP 的品質參數。背景沒有 alpha，立繪要保住去背成果。
WEBP_QUALITY_BACKGROUND = 80
WEBP_QUALITY_SPRITE = 85


def asset_filename(name: str, webp: bool) -> str:
    """素材的實際檔名。story.json 一律寫 `.png`，轉檔後檔名要跟著換。

    劇本是逐字複製的、不能改，所以副檔名的轉換由**引擎組路徑時**處理——
    Flutter製作規範 §1 本來就寫「資產參照是不含路徑的檔名，引擎負責組出
    路徑」。`pack.json` 的 `assetFormat` 就是告訴引擎要組哪一種。
    """
    return name[:-4] + '.webp' if webp else name


def write_sprite(image, dest: pathlib.Path, webp: bool) -> None:
    if webp:
        save_webp(image, dest, WEBP_QUALITY_SPRITE)
    else:
        image.save(dest)


def save_webp(image, dest: pathlib.Path, quality: int) -> None:
    """method=6 是最慢也最小的壓縮等級；這是一次性的匯入，值得。

    alpha_quality=100 讓透明通道無損——實測 44 張立繪轉檔前後「完全透明」
    與「完全不透明」的像素數一個不差，去背成果不會被壓損。
    """
    image.save(dest, 'WEBP', quality=quality, alpha_quality=100, method=6)


def import_pack(webp: bool = True, use_cache: bool = True) -> dict:
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
    detect_duplicate_sprites(picked)
    for (kind, name), src_path in sorted(picked.items()):
        if kind != 'backgrounds':
            continue
        dest = OUT / 'assets/backgrounds' / asset_filename(name, webp)
        if webp:
            save_webp(Image.open(src_path).convert('RGB'), dest, WEBP_QUALITY_BACKGROUND)
        else:
            shutil.copyfile(src_path, dest)
    process_sprites(picked, use_cache, webp)

    entries.sort(key=lambda e: e['order'])
    pack = {'id': 'pompeii_79', 'title': PACK_TITLE, 'place': PACK_PLACE,
            'blurb': PACK_BLURB, 'assetFormat': 'webp' if webp else 'png',
            'stories': entries}
    (OUT / 'pack.json').write_text(
        json.dumps(pack, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    verify(copied_scripts, webp)
    total = sum(f.stat().st_size for f in (OUT / 'assets').rglob('*') if f.is_file())
    print(f'✅ 8 篇、{len(picked)} 張素材（{"webp" if webp else "png"}，'
          f'{total // 1024 // 1024} MB）、pack.json 完成')
    return pack


# 對齊演算法的版本號。**改動 align_to_base() 的行為時要手動 +1。**
# 對齊快取鍵要綁「差分的去背快取鍵 ＋ 基底的去背快取鍵 ＋ 這個版本號」——
# 理由與 _cache_key() 一樣：只綁來源圖的話，調了 SCALE_RANGE 或 SHIFT_LIMIT
# 卻忘記加 --no-cache，就會靜默吐出用舊參數對齊的舊結果。
ALIGN_PIPELINE_VERSION = 3


def _align_stamp(key: str, base_key: str) -> str:
    """對齊快取鍵要綁**所有會改變結果的參數**，不只手動版本號。

    只綁版本號的話，調了 ALIGN_MIN_SCORE 卻忘記 +1，就會靜默吐出用舊門檻算的
    舊 `skipped` 判定——實測踩過：門檻 0.95→0.90 之後，快取仍說 hylas_scared
    是 skipped，害雙向斷言誤報「出現新的壞素材」。去背那邊的 `_cache_key` 早
    就綁了參數，對齊這邊漏了同一件事。
    """
    params = f'{ALIGN_MIN_SCORE}:{SHIFT_LIMIT}:{SCALE_RANGE[0]}:{SCALE_RANGE[-1]}:{len(SCALE_RANGE)}'
    return f'{key}:{base_key}:{params}:{ALIGN_PIPELINE_VERSION}'


def process_sprites(picked, use_cache: bool, webp: bool = False) -> None:
    """先全部去背，再把差分對齊到同角色的 _neutral 基底。

    對齊需要同角色的基底一起在手上比對，不能像背景那樣逐檔獨立處理，
    所以改由這裡在收齊所有立繪的去背結果後統一對齊。
    """
    CACHE.mkdir(parents=True, exist_ok=True)
    cutouts = {}
    for (kind, name), src in sorted(picked.items()):
        if kind != 'sprites':
            continue
        key = _cache_key(src)
        cached = CACHE / f'{key}_cutout.png'
        if not (use_cache and cached.exists()):
            cutout = remove_background(src)
            cutout.save(cached)
            write_review(src.name, Image.open(src), cutout)
        cutouts[name] = (Image.open(cached).convert('RGBA'), key)

    # 對齊結果的參數（含 skipped 與否）額外存一份 manifest，讓測試能查「哪些
    # 素材被判定分數過低而跳過對齊」，不必為了問這件事重新跑一次對齊。
    manifest = {}
    for name, (img, key) in sorted(cutouts.items()):
        character = name.rsplit('_', 1)[0]
        base_name = f'{character}_neutral.png'
        dest = OUT / 'assets/sprites' / asset_filename(name, webp)
        if name == base_name or base_name not in cutouts:
            write_sprite(img, dest, webp)
            continue
        base, base_key = cutouts[base_name]
        align_key = hashlib.md5(_align_stamp(key, base_key).encode()).hexdigest()
        aligned_cache = CACHE / f'{align_key}_aligned.png'
        params_cache = CACHE / f'{align_key}_aligned.json'
        # 快取一律存無損 PNG——換輸出格式不該要求重跑昂貴的去背與對齊。
        if use_cache and aligned_cache.exists() and params_cache.exists():
            aligned = Image.open(aligned_cache).convert('RGBA')
            params = json.loads(params_cache.read_text(encoding='utf-8'))
        else:
            aligned, params = align_to_base(base, img)
            aligned.save(aligned_cache)
            params_cache.write_text(json.dumps(params), encoding='utf-8')
            write_align_review(name, base, img, aligned)
            print(f'  對齊 {name}: {params}')
        write_sprite(aligned, dest, webp)
        manifest[name] = params

    REVIEW.mkdir(parents=True, exist_ok=True)
    (REVIEW / 'align_manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + '\n',
        encoding='utf-8')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    # WebP 是預設：實測背景與立繪壓縮 11–20 倍（143 MB → 11 MB），alpha 用
    # alpha_quality=100 無損（去背成果的透明像素數轉檔前後一個不差），人物區
    # RGB 平均差 2.5/255 肉眼看不出來。Flutter 在 iOS／Android／Web 全平台
    # 原生支援。--png 留著當退路。
    ap.add_argument('--png', action='store_true', help='輸出 PNG 而非 WebP')
    ap.add_argument('--no-cache', action='store_true')
    a = ap.parse_args()
    import_pack(webp=not a.png, use_cache=not a.no_cache)
