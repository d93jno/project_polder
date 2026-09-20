#!/usr/bin/env python3
"""P0 combat HUD compositor.

Image models paint the subjects. This script keys mint, pads, downscales,
composes 9-slice frames, draws path/line pieces, and builds the digit atlas.
Glyphs are PIL, never an image model.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/home/jonas/proj/project_polder/assets")
ICONS = ROOT / "ui" / "icons"
THEME = ROOT / "ui" / "theme"
HUD = ROOT / "ui" / "hud"
SESS = Path(
    "/home/jonas/.grok/sessions/%2Fhome%2Fjonas%2Fproj%2Fproject_polder"
    "/01a0bdbe-dd38-7a11-98b4-422a490ff8be/images"
)
FONT = Path("/tmp/polder_fonts/BarlowCondensed-Black.ttf")
NINE = THEME / "ui_panel_9slice.png"

MINT = (0, 255, 170)
PAD = 0.14  # ~14% canvas on each side after subject crop

LANCZOS = Image.Resampling.LANCZOS


def load_rgb(path: Path) -> Image.Image:
    return Image.open(path).convert("RGB")


def np_img(im: Image.Image) -> np.ndarray:
    return np.asarray(im).astype(np.float32)


def from_np(arr: np.ndarray, mode: str = "RGB") -> Image.Image:
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode)


def mint_mask(arr: np.ndarray) -> np.ndarray:
    """True where the pixel is chroma-key mint, not subject or contact shadow."""
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    mx = arr.max(axis=2)
    mn = arr.min(axis=2)
    # Green-dominant, bright, saturated enough to be the key field.
    green_dom = (g > r + 22) & (g >= b - 8)
    bright = mx >= 130
    chroma = (mx - mn) >= 28
    not_cream = ~((r >= 170) & (g >= 170) & (b >= 130) & (r + 12 >= g))
    not_rust = ~((r > g + 8) & (r > b + 12) & (g < 170))
    return green_dom & bright & chroma & not_cream & not_rust


def apply_mint_key(im: Image.Image) -> Image.Image:
    arr = np_img(im.convert("RGB"))
    mask = mint_mask(arr)
    # Close 1px JPEG holes in the field; do not eat the subject.
    m = Image.fromarray(mask.astype(np.uint8) * 255, "L")
    m = m.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    mask = np.asarray(m) > 127
    arr[mask] = np.array(MINT, dtype=np.float32)
    return from_np(arr)


def subject_bbox(im: Image.Image, margin_frac: float = PAD) -> tuple[int, int, int, int]:
    arr = np_img(im)
    mask = ~mint_mask(arr)
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return (0, 0, im.width, im.height)
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    w, h = x1 - x0, y1 - y0
    side = max(w, h)
    pad = int(round(side * margin_frac / (1.0 - 2 * margin_frac)))
    cx = (x0 + x1) / 2.0
    cy = (y0 + y1) / 2.0
    half = side / 2.0 + pad
    left = int(round(cx - half))
    top = int(round(cy - half))
    right = int(round(cx + half))
    bot = int(round(cy + half))
    return (left, top, right, bot)


def paste_square(im: Image.Image, bbox: tuple[int, int, int, int], size: int) -> Image.Image:
    left, top, right, bot = bbox
    side = max(right - left, bot - top)
    canvas = Image.new("RGB", (side, side), MINT)
    src = im.convert("RGB")
    # Paste the overlapping region.
    src_box = (
        max(0, left),
        max(0, top),
        min(src.width, right),
        min(src.height, bot),
    )
    dst_xy = (src_box[0] - left, src_box[1] - top)
    canvas.paste(src.crop(src_box), dst_xy)
    out = canvas.resize((size, size), LANCZOS)
    # Re-key after resize (fringes).
    return apply_mint_key(out)


def down(im: Image.Image, size: int) -> Image.Image:
    out = im.resize((size, size), LANCZOS)
    out = out.filter(ImageFilter.UnsharpMask(radius=0.8, percent=45, threshold=2))
    return apply_mint_key(out)


def save(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG", optimize=True)
    print(f"  wrote {path.relative_to(ROOT)} {im.size} {im.mode}")


def export_icon(src: Image.Image, dest_dir: Path, stem: str, with_512: bool = True) -> Image.Image:
    keyed = apply_mint_key(src)
    bbox = subject_bbox(keyed)
    master = paste_square(keyed, bbox, 512)
    if with_512:
        save(master, dest_dir / f"{stem}_512.png")
    i128 = down(master, 128)
    save(i128, dest_dir / f"{stem}.png")
    save(down(master, 64), dest_dir / f"{stem}_64.png")
    save(down(master, 32), dest_dir / f"{stem}_32.png")
    return i128


def mint_to_alpha(im: Image.Image) -> Image.Image:
    rgb = apply_mint_key(im.convert("RGB"))
    arr = np_img(rgb)
    mask = mint_mask(arr)
    rgba = np.dstack([arr, np.where(mask, 0.0, 255.0)])
    rgba[mask, 0:3] = 0.0  # match confirm_frame: transparent is (0,0,0,0)
    return from_np(rgba, "RGBA")


def inpaint_undo_blob(im: Image.Image) -> Image.Image:
    """Clone wet-slate over the mud lump under the boot."""
    arr = np_img(im.convert("RGB"))
    h, w = arr.shape[:2]
    # Ellipse covering the lump (authoring 1024).
    cy, cx, ry, rx = 598, 518, 42, 58
    yy, xx = np.ogrid[:h, :w]
    ell = ((yy - cy) / ry) ** 2 + ((xx - cx) / rx) ** 2 <= 1.0
    # Source: wet tile to the left of the lump.
    src = arr[560:700, 360:500].copy()
    # Fill ellipse from tiled source patch.
    ys, xs = np.where(ell)
    for y, x in zip(ys, xs):
        sy = (y - 560) % src.shape[0]
        sx = (x - 360) % src.shape[1]
        # Keep a soft edge.
        d = ((y - cy) / ry) ** 2 + ((x - cx) / rx) ** 2
        t = 1.0 if d < 0.55 else float(np.clip((1.0 - d) / 0.45, 0, 1))
        arr[y, x] = arr[y, x] * (1 - t) + src[sy, sx] * t
    return from_np(arr)


def nine_slice(src: Image.Image, out_w: int, out_h: int, margin: int) -> Image.Image:
    src = src.convert("RGB")
    m = margin
    sw, sh = src.size
    if out_w < 2 * m or out_h < 2 * m:
        raise ValueError("output smaller than corners")
    dst = Image.new("RGB", (out_w, out_h), (95, 114, 118))
    # corners
    dst.paste(src.crop((0, 0, m, m)), (0, 0))
    dst.paste(src.crop((sw - m, 0, sw, m)), (out_w - m, 0))
    dst.paste(src.crop((0, sh - m, m, sh)), (0, out_h - m))
    dst.paste(src.crop((sw - m, sh - m, sw, sh)), (out_w - m, out_h - m))
    # edges
    top = src.crop((m, 0, sw - m, m)).resize((out_w - 2 * m, m), LANCZOS)
    bot = src.crop((m, sh - m, sw - m, sh)).resize((out_w - 2 * m, m), LANCZOS)
    left = src.crop((0, m, m, sh - m)).resize((m, out_h - 2 * m), LANCZOS)
    right = src.crop((sw - m, m, sw, sh - m)).resize((m, out_h - 2 * m), LANCZOS)
    dst.paste(top, (m, 0))
    dst.paste(bot, (m, out_h - m))
    dst.paste(left, (0, m))
    dst.paste(right, (out_w - m, m))
    # centre
    mid = src.crop((m, m, sw - m, sh - m)).resize((out_w - 2 * m, out_h - 2 * m), LANCZOS)
    dst.paste(mid, (m, m))
    return dst


def noise_layer(size: tuple[int, int], seed: int, scale: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    w, h = size
    small = rng.random((max(2, h // 8), max(2, w // 8))).astype(np.float32)
    layer = np.array(
        Image.fromarray((small * 255).astype(np.uint8), "L").resize((w, h), Image.Resampling.BICUBIC),
        dtype=np.float32,
    ) / 255.0
    return (layer - 0.5) * scale


def draw_line(kind: str) -> Image.Image:
    """Horizontal stroke. Clean = solid rail; blocked = dashed rail. Shape carries."""
    w, h = 256, 32
    rgba = np.zeros((h, w, 4), dtype=np.float32)
    # Stroke band.
    y0, y1 = 8, 24
    cream = np.array([214, 196, 168, 255], dtype=np.float32)
    iron = np.array([92, 64, 52, 255], dtype=np.float32)
    n = noise_layer((w, h), 7 if kind == "clean" else 11, 28.0)
    xs = np.arange(w)
    if kind == "clean":
        on = np.ones(w, dtype=bool)
    else:
        # 16px dash, 16px gap — tiles at 32px. Not a recolour of clean.
        on = (xs % 32) < 16
    for y in range(y0, y1):
        t = abs((y - (y0 + y1) / 2) / ((y1 - y0) / 2))
        col = cream * (1 - t * 0.35) + iron * (t * 0.35)
        edge = 1.0 if (y <= y0 + 1 or y >= y1 - 2) else 0.0
        col = col * (1 - edge) + iron * edge
        row = np.tile(col, (w, 1))
        row[:, 0] += n[y]
        row[:, 1] += n[y] * 0.7
        row[:, 2] += n[y] * 0.5
        row[~on] = 0.0
        rgba[y] = row
    # Caps so a 9-slice can hold the ends: 8px solid even on blocked? No —
    # blocked must stay dashed at the ends too so tiling/slicing does not lie.
    return from_np(rgba, "RGBA")


def draw_digits() -> tuple[Image.Image, list[str]]:
    """10-cell atlas, 64px cells, 0–9. Cream fill, iron contact, mint key."""
    cell = 64
    atlas = Image.new("RGB", (cell * 10, cell), MINT)
    font = ImageFont.truetype(str(FONT), size=52)
    reads: list[str] = []
    for i, ch in enumerate("0123456789"):
        cell_im = Image.new("RGB", (cell, cell), MINT)
        d = ImageDraw.Draw(cell_im)
        # Measure and center.
        bbox = d.textbbox((0, 0), ch, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        x = (cell - tw) // 2 - bbox[0]
        y = (cell - th) // 2 - bbox[1] - 1
        # Iron drop-shadow (baked, like icon contact shadows).
        d.text((x + 2, y + 2), ch, font=font, fill=(78, 54, 42))
        d.text((x, y), ch, font=font, fill=(232, 214, 186))
        atlas.paste(cell_im, (i * cell, 0))
        # Verify with tesseract on the isolated cell.
        tmp = Path("/tmp") / f"polder_digit_{ch}.png"
        # Upscale for OCR.
        ocr_im = cell_im.resize((cell * 4, cell * 4), LANCZOS)
        ocr_im.save(tmp)
        proc = subprocess.run(
            [
                "tesseract",
                str(tmp),
                "stdout",
                "--psm",
                "10",
                "-c",
                "tessedit_char_whitelist=0123456789",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        got = "".join(c for c in proc.stdout.strip() if c.isdigit())
        reads.append(got if got else "?")
        if got != ch:
            print(f"  OCR mismatch digit {ch} -> {got!r}")
        else:
            print(f"  OCR digit {ch} ok")
    return atlas, reads


def contact_sheet(icons: list[Image.Image], cols: int = 5, gap: int = 12) -> Image.Image:
    n = len(icons)
    rows = (n + cols - 1) // cols
    cell = 128
    w = cols * cell + (cols + 1) * gap
    h = rows * cell + (rows + 1) * gap
    sheet = Image.new("RGB", (w, h), MINT)
    for i, im in enumerate(icons):
        r, c = divmod(i, cols)
        x = gap + c * (cell + gap)
        y = gap + r * (cell + gap)
        tile = im.convert("RGB")
        if tile.size != (cell, cell):
            tile = tile.resize((cell, cell), LANCZOS)
        sheet.paste(apply_mint_key(tile), (x, y))
    return apply_mint_key(sheet)


def main() -> None:
    HUD.mkdir(parents=True, exist_ok=True)

    print("== icons ==")
    icon_map = {
        "ui_icon_hidden": "6.jpg",
        "ui_icon_exposed": "5.jpg",
        "ui_icon_no_hide": "11.jpg",
        "ui_icon_ducked": "3.jpg",
        "ui_icon_ducking_next": "8.jpg",
        "ui_icon_watch_spent": "16.jpg",
        "ui_icon_watch_friendly": "9.jpg",
    }
    icon_128: dict[str, Image.Image] = {}
    for stem, fn in icon_map.items():
        print(stem)
        icon_128[stem] = export_icon(load_rgb(SESS / fn), ICONS, stem, with_512=True)

    print("== theme pips / phase ==")
    print("ui_pip_bleed")
    bleed = export_icon(load_rgb(SESS / "18.jpg"), THEME, "ui_pip_bleed", with_512=False)
    print("ui_phase_yours")
    phase_y = export_icon(load_rgb(SESS / "10.jpg"), THEME, "ui_phase_yours", with_512=True)
    print("ui_phase_theirs")
    phase_t = export_icon(load_rgb(SESS / "13.jpg"), THEME, "ui_phase_theirs", with_512=True)

    print("== theme frames ==")
    sel = mint_to_alpha(load_rgb(SESS / "14.jpg"))
    sel = sel.resize((512, 512), LANCZOS)
    # Re-key alpha after resize.
    rgb = Image.new("RGB", sel.size, MINT)
    rgb.paste(sel.convert("RGB"), mask=sel.split()[-1])
    sel = mint_to_alpha(rgb)
    save(sel, THEME / "ui_selection_frame.png")

    nine = load_rgb(NINE)
    # Fireteam slot: tall empty portrait. Corners from the 512 9-slice (margin 90).
    slot = nine_slice(nine, 256, 384, margin=72)
    save(slot, THEME / "ui_fireteam_slot.png")
    fuel = nine_slice(nine, 256, 256, margin=72)
    save(fuel, THEME / "ui_fuel_count_frame.png")
    fuel128 = fuel.resize((128, 128), LANCZOS)
    save(fuel128, THEME / "ui_fuel_count_frame_128.png")

    print("== hud path / line ==")
    print("ui_path_tile")
    path_tile = export_icon(load_rgb(SESS / "21.jpg"), HUD, "ui_path_tile", with_512=False)
    print("ui_path_reserve_shot")
    reserve_shot = export_icon(load_rgb(SESS / "17.jpg"), HUD, "ui_path_reserve_shot", with_512=False)
    print("ui_path_reserve_watch")
    reserve_watch = export_icon(load_rgb(SESS / "9.jpg"), HUD, "ui_path_reserve_watch", with_512=False)
    print("ui_undo_afford")
    undo_src = inpaint_undo_blob(load_rgb(SESS / "22.jpg"))
    undo = export_icon(undo_src, HUD, "ui_undo_afford", with_512=True)

    clean = draw_line("clean")
    blocked = draw_line("blocked")
    save(clean, HUD / "ui_line_clean.png")
    save(blocked, HUD / "ui_line_blocked.png")

    print("== digits ==")
    atlas, reads = draw_digits()
    save(atlas, HUD / "ui_hud_digits.png")
    print("digit OCR:", "".join(reads))

    print("== contact sheet ==")
    ordered = [
        icon_128["ui_icon_hidden"],
        icon_128["ui_icon_exposed"],
        icon_128["ui_icon_no_hide"],
        icon_128["ui_icon_ducked"],
        icon_128["ui_icon_ducking_next"],
        icon_128["ui_icon_watch_spent"],
        icon_128["ui_icon_watch_friendly"],
        phase_y,
        phase_t,
        bleed,
        undo,
        path_tile,
        reserve_shot,
        reserve_watch,
    ]
    sheet = contact_sheet(ordered, cols=5, gap=12)
    save(sheet, HUD / "ui_hud_contact_sheet.png")
    print("done")


if __name__ == "__main__":
    main()
