#!/usr/bin/env python3
"""P0 world-plate compositor.

Image models do not draw the letters. Blank weathered plates are albedos;
this script composites exact glyphs (PIL) and verifies them in order.
"""

from __future__ import annotations

import math
import os
import random
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

ROOT = Path("/home/jonas/proj/project_polder/assets/worldtext")
FONT_DIR = Path("/tmp/polder_fonts")
BLANK_DIR = Path("/tmp/polder_plates")
SESSION_IMAGES = Path(
    "/home/jonas/.grok/sessions/%2Fhome%2Fjonas%2Fproj%2Fproject_polder"
    "/01a0bda1-9324-7941-bfe0-38222c94ebfa/images"
)

W, H = 2048, 1024
WL_W, WL_H = 2048, 512
MARGIN = 180

# Session blanks (image_gen, no letters).
BLANKS = {
    "aluminum": SESSION_IMAGES / "3.jpg",
    "cream": SESSION_IMAGES / "1.jpg",
    "rust": SESSION_IMAGES / "5.jpg",
    "levee": SESSION_IMAGES / "2.jpg",
    "wall": SESSION_IMAGES / "4.jpg",
}

FONTS = {
    "barlow_black": FONT_DIR / "BarlowCondensed-Black.ttf",
    "barlow_xbold": FONT_DIR / "BarlowCondensed-ExtraBold.ttf",
    "barlow_bold": FONT_DIR / "BarlowCondensed-Bold.ttf",
    "stencil": FONT_DIR / "AllertaStencil-Regular.ttf",
    "blackops": FONT_DIR / "BlackOpsOne-Regular.ttf",
    "anton": FONT_DIR / "Anton-Regular.ttf",
    "bebas": FONT_DIR / "BebasNeue-Regular.ttf",
    "stardos": FONT_DIR / "StardosStencil-Bold.ttf",
}


def load_font(key: str, size: int) -> ImageFont.FreeTypeFont:
    path = FONTS[key]
    if not path.exists():
        raise FileNotFoundError(path)
    return ImageFont.truetype(str(path), size=size)


def cover_resize(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    tw, th = size
    im = im.convert("RGB")
    scale = max(tw / im.width, th / im.height)
    nw, nh = max(tw, int(round(im.width * scale))), max(th, int(round(im.height * scale)))
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (im.width - tw) // 2
    top = (im.height - th) // 2
    im = im.crop((left, top, left + tw, top + th))
    return im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))


def plate_from(key: str, size: tuple[int, int] = (W, H)) -> Image.Image:
    src = BLANKS[key]
    im = Image.open(src)
    return cover_resize(im, size)


def np_img(im: Image.Image) -> np.ndarray:
    return np.asarray(im).astype(np.float32)


def from_np(arr: np.ndarray, mode: str) -> Image.Image:
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, mode=mode)


def smooth_noise(shape: tuple[int, int], rng: np.random.Generator, octaves: int = 4) -> np.ndarray:
    h, w = shape
    acc = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        sw, sh = max(2, w // (2 ** (o + 2))), max(2, h // (2 ** (o + 2)))
        small = rng.random((sh, sw)).astype(np.float32)
        layer = np.array(
            Image.fromarray((small * 255).astype(np.uint8), "L").resize((w, h), Image.Resampling.BICUBIC),
            dtype=np.float32,
        ) / 255.0
        acc += layer * amp
        total += amp
        amp *= 0.55
    return acc / total


@dataclass
class Glyph:
    ch: str
    x: int
    y: int
    w: int
    h: int
    ink: Image.Image  # L, glyph-local


@dataclass
class LineLayout:
    text: str
    glyphs: list[Glyph] = field(default_factory=list)
    width: int = 0
    height: int = 0
    y0: int = 0


def _metrics_box(font: ImageFont.FreeTypeFont) -> tuple[int, int]:
    ascent, descent = font.getmetrics()
    return ascent + 4, descent + 4


def _em_dash_ink(font: ImageFont.FreeTypeFont, size: int) -> Image.Image:
    """True em-dash: a heavy bar centred on cap-height, never a baseline underscore."""
    ascent, descent = _metrics_box(font)
    height = ascent + descent
    dash_w = max(int(size * 0.78), 36)
    dash_h = max(int(size * 0.14), 12)
    img = Image.new("L", (dash_w, height), 0)
    d = ImageDraw.Draw(img)
    try:
        hb = font.getbbox("H", anchor="ls")
        cap_mid = (hb[1] + hb[3]) / 2.0  # relative to baseline (negative)
    except Exception:
        cap_mid = -ascent * 0.38
    cy = ascent + cap_mid
    y0 = int(round(cy - dash_h / 2))
    d.rounded_rectangle((0, y0, dash_w - 1, y0 + dash_h), radius=max(2, dash_h // 2), fill=255)
    return img


def _slash_ink(font: ImageFont.FreeTypeFont, size: int) -> Image.Image:
    ascent, descent = _metrics_box(font)
    height = ascent + descent
    w = max(int(size * 0.42), 22)
    img = Image.new("L", (w, height), 0)
    d = ImageDraw.Draw(img)
    thick = max(int(size * 0.11), 8)
    d.line((3, height - descent - 6, w - 3, 8), fill=255, width=thick)
    return img


def render_char_ink(ch: str, font: ImageFont.FreeTypeFont, size: int) -> Image.Image:
    """Full-metrics-height ink, baseline-aligned. Do not crop vertically."""
    ascent, descent = _metrics_box(font)
    height = ascent + descent
    if ch == " ":
        space_w = max(int(size * 0.34), 14)
        return Image.new("L", (space_w, height), 0)
    if ch == "—":
        return _em_dash_ink(font, size)
    if ch == "/":
        return _slash_ink(font, size)

    bbox = font.getbbox(ch, anchor="ls")
    x0, y0, x1, y1 = bbox
    width = max(int(math.ceil(x1 - x0)) + 4, 4)
    img = Image.new("L", (width, height), 0)
    ImageDraw.Draw(img).text((2 - x0, ascent), ch, font=font, fill=255, anchor="ls")
    if np.asarray(img).max() < 32:
        raise RuntimeError(f"font produced no ink for {ch!r}")
    return img


def layout_line(
    text: str,
    font: ImageFont.FreeTypeFont,
    size: int,
    tracking: int,
    space_extra: int = 0,
) -> LineLayout:
    glyphs: list[Glyph] = []
    x = 0
    max_h = 0
    for ch in text:
        ink = render_char_ink(ch, font, size)
        advance = ink.width
        if ch == " ":
            advance += space_extra
        side = int(size * 0.10) if ch == "—" else 0
        glyphs.append(Glyph(ch, x + side, 0, ink.width, ink.height, ink))
        x += advance + tracking + side * 2
        max_h = max(max_h, ink.height)
    if glyphs:
        x -= tracking
    return LineLayout(text=text, glyphs=glyphs, width=max(0, x), height=max_h)


def blit_ink(mask: Image.Image, ink: Image.Image, x: int, y: int) -> None:
    mask.paste(ImageChops.lighter(mask.crop((x, y, x + ink.width, y + ink.height)), ink), (x, y))


def compose_mask(lines: list[LineLayout], origin: tuple[int, int], gap: int) -> tuple[Image.Image, list[LineLayout]]:
    max_w = max(ln.width for ln in lines)
    ox, oy = origin
    mask = Image.new("L", (W, H), 0)
    y = oy
    placed: list[LineLayout] = []
    for ln in lines:
        x = ox + (max_w - ln.width) // 2  # centre each line in the block
        new_glyphs = []
        for g in ln.glyphs:
            gy = y  # shared baseline box; glyphs already sit on it
            gx = x + g.x
            if g.ch != " ":
                blit_ink(mask, g.ink, gx, gy)
            new_glyphs.append(Glyph(g.ch, gx, gy, g.w, g.h, g.ink))
        placed.append(LineLayout(text=ln.text, glyphs=new_glyphs, width=ln.width, height=ln.height, y0=y))
        y += ln.height + gap
    return mask, placed


def fit_block(
    lines_text: list[str],
    font_key: str,
    size: int,
    tracking_ratio: float,
    max_w: int,
    max_h: int,
    gap_ratio: float = 0.18,
    min_size: int = 48,
) -> tuple[list[LineLayout], ImageFont.FreeTypeFont, int]:
    size = int(size)
    while size >= min_size:
        font = load_font(font_key, size)
        tracking = max(int(size * tracking_ratio), 4)
        gap = max(int(size * gap_ratio), 8)
        lines = [layout_line(t, font, size, tracking, space_extra=int(size * 0.08)) for t in lines_text]
        w = max(ln.width for ln in lines)
        h = sum(ln.height for ln in lines) + gap * (len(lines) - 1)
        if w <= max_w and h <= max_h:
            return lines, font, size
        size -= 4
    font = load_font(font_key, min_size)
    tracking = max(int(min_size * tracking_ratio), 4)
    lines = [layout_line(t, font, min_size, tracking) for t in lines_text]
    return lines, font, min_size


def outline_mask(mask: Image.Image, radius: int) -> Image.Image:
    if radius <= 0:
        return mask
    return mask.filter(ImageFilter.MaxFilter(radius * 2 + 1))


def apply_letters(
    plate: Image.Image,
    mask: Image.Image,
    fill: tuple[int, int, int],
    outline: tuple[int, int, int] | None = None,
    outline_px: int = 0,
    wear: float = 0.12,
    seed: int = 1,
    engraved: bool = False,
) -> Image.Image:
    """Composite high-contrast letters. Wear never eats a glyph."""
    rng = np.random.default_rng(seed)
    base = plate.convert("RGB")
    h, w = H, W
    m = np_img(mask) / 255.0  # 0..1
    if outline and outline_px > 0:
        om = np_img(outline_mask(mask, outline_px)) / 255.0
        ring = np.clip(om - m, 0, 1)
    else:
        ring = np.zeros_like(m)

    noise = smooth_noise((h, w), rng, octaves=5)
    # Keep at least 82% of letter opacity even in heavy wear.
    letter_a = m * (1.0 - wear * 0.35 * (1.0 - noise))
    letter_a = np.clip(letter_a, 0, 1)
    letter_a = np.where(m > 0.4, np.maximum(letter_a, 0.82), letter_a)

    arr = np_img(base)
    fill_a = np.array(fill, dtype=np.float32)
    if outline and outline_px > 0:
        out_a = np.array(outline, dtype=np.float32)
        ring_a = ring * 0.92
        arr = arr * (1 - ring_a[..., None]) + out_a * ring_a[..., None]

    if engraved:
        # Recessed: dark fill, slight bottom highlight, top shadow.
        shift = np.roll(m, 3, axis=0)
        highlight = np.clip(m - shift, 0, 1) * 0.35
        shadow = np.clip(np.roll(m, -2, axis=0) - m, 0, 1) * 0.25
        arr = arr * (1 - letter_a[..., None]) + fill_a * letter_a[..., None]
        arr = arr + highlight[..., None] * 40.0
        arr = arr - shadow[..., None] * 30.0
    else:
        arr = arr * (1 - letter_a[..., None]) + fill_a * letter_a[..., None]

    # Very light grain on paint, not enough to break stems.
    grain = (rng.random((h, w, 1)) - 0.5) * 10.0 * letter_a[..., None]
    arr = arr + grain
    return from_np(arr, "RGB")


def centre_origin(block_w: int, block_h: int, y_bias: int = 0) -> tuple[int, int]:
    ox = (W - block_w) // 2
    oy = (H - block_h) // 2 + y_bias
    ox = max(MARGIN, min(ox, W - MARGIN - block_w))
    oy = max(int(MARGIN * 0.7), min(oy, H - int(MARGIN * 0.7) - block_h))
    return ox, oy


def block_size(lines: list[LineLayout], gap: int) -> tuple[int, int]:
    return max(ln.width for ln in lines), sum(ln.height for ln in lines) + gap * (len(lines) - 1)


# --- iconography (non-letter) -------------------------------------------------

def icon_impeller(size: int) -> Image.Image:
    """Pump handwheel: ring + six vanes. Not a letter, not a peace sign."""
    im = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(im)
    m = size // 2
    r = int(size * 0.46)
    w = max(size // 11, 6)
    d.ellipse((m - r, m - r, m + r, m + r), outline=255, width=w)
    hub = max(size // 9, 8)
    d.ellipse((m - hub, m - hub, m + hub, m + hub), fill=255)
    for i in range(6):
        a = math.radians(i * 60)
        x2 = m + int(math.cos(a) * (r - w // 2))
        y2 = m + int(math.sin(a) * (r - w // 2))
        d.line((m, m, x2, y2), fill=255, width=max(w - 2, 5))
    return im


def icon_wrench(w: int, h: int) -> Image.Image:
    """Open-end wrench, jaws up. Wrench-goes-here. Not a letter."""
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    t = max(w // 5, 12)
    # handle
    hx0 = w // 2 - t // 2
    d.rounded_rectangle((hx0, int(h * 0.40), hx0 + t, int(h * 0.97)), radius=t // 2, fill=255)
    # head: U opening upward
    jaw_w = int(w * 0.92)
    jaw_h = int(h * 0.40)
    x0 = (w - jaw_w) // 2
    y0 = int(h * 0.04)
    d.rounded_rectangle((x0, y0, x0 + jaw_w, y0 + jaw_h), radius=t, fill=255)
    cut = Image.new("L", (w, h), 0)
    cd = ImageDraw.Draw(cut)
    m = max(t + 2, int(w * 0.28))
    cd.rounded_rectangle((x0 + m, y0 - 4, x0 + jaw_w - m, y0 + jaw_h - m), radius=t // 2, fill=255)
    im = ImageChops.subtract(im, cut)
    return im


def icon_fail_chevrons(w: int, h: int) -> Image.Image:
    """Three downward chevrons — failing / dropping. Not a letter A."""
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    thick = max(h // 12, 10)
    for i in range(3):
        y = int(h * (0.12 + i * 0.28))
        d.line((8, y, w // 2, y + int(h * 0.22)), fill=255, width=thick)
        d.line((w - 8, y, w // 2, y + int(h * 0.22)), fill=255, width=thick)
    return im.filter(ImageFilter.GaussianBlur(0.3))


def icon_grade_staff(w: int, h: int) -> Image.Image:
    """Levee bench-mark: triangle on a bar. High-shoulder. Not an E, not a digit."""
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    cx = w // 2
    bar_h = max(h // 10, 14)
    # horizontal bar (the mark)
    d.rectangle((int(w * 0.04), int(h * 0.58), int(w * 0.96), int(h * 0.58) + bar_h), fill=255)
    # upright
    t = max(w // 8, 10)
    d.rectangle((cx - t // 2, int(h * 0.58), cx + t // 2, int(h * 0.96)), fill=255)
    # filled triangle pointing up = high
    d.polygon(
        [
            (cx, int(h * 0.02)),
            (int(w * 0.06), int(h * 0.56)),
            (int(w * 0.94), int(h * 0.56)),
        ],
        fill=255,
    )
    return im


def blit_icon(mask: Image.Image, icon: Image.Image, cx: int, cy: int) -> None:
    x = int(cx - icon.width / 2)
    y = int(cy - icon.height / 2)
    blit_ink(mask, icon, x, y)


def letters_of(s: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", s.upper())


def intended_nonspace(s: str) -> str:
    return s.replace(" ", "")


def ocr_image(im: Image.Image, psm: int = 6) -> str:
    import tempfile

    # High-contrast for tesseract.
    work = im.convert("L")
    work = ImageOps.autocontrast(work)
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        path = f.name
        work.save(path)
    try:
        r = subprocess.run(
            [
                "tesseract",
                path,
                "stdout",
                "--psm",
                str(psm),
                "-c",
                "tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/-",
                "-c",
                "load_system_dawg=0",
                "-c",
                "load_freq_dawg=0",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        return r.stdout.strip().replace("\n", " ")
    finally:
        os.unlink(path)


def glyph_iou(a: Image.Image, b: Image.Image) -> float:
    """IoU of two L masks, resized to a common box."""
    if a.size != b.size:
        b = b.resize(a.size, Image.Resampling.NEAREST)
    aa = np_img(a) > 80
    bb = np_img(b) > 80
    inter = np.logical_and(aa, bb).sum()
    union = np.logical_or(aa, bb).sum()
    if union == 0:
        return 0.0
    return float(inter / union)


def verify_layout(mask: Image.Image, placed: list[LineLayout], intended: str) -> list[str]:
    errors: list[str] = []
    got_chars = " ".join("".join(g.ch for g in ln.glyphs) for ln in placed)
    if got_chars != intended:
        errors.append(f"layout string {got_chars!r} != intended {intended!r}")
    for ln in placed:
        for g in ln.glyphs:
            if g.ch == " ":
                continue
            crop = mask.crop((g.x, g.y, g.x + g.w, g.y + g.h))
            iou = glyph_iou(g.ink, crop)
            if iou < 0.70:
                errors.append(f"glyph {g.ch!r} @({g.x},{g.y}) IoU={iou:.2f}")
    seq = "".join(g.ch for ln in placed for g in ln.glyphs if g.ch != " ")
    exp = intended.replace(" ", "")
    if seq != exp:
        errors.append(f"nonspace {seq!r} != {exp!r}")
    return errors


def save_png(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, format="PNG", optimize=True)
    print(f"wrote {path.name} {im.size} {im.mode} {path.stat().st_size} bytes")


# --- plates -------------------------------------------------------------------

@dataclass
class PlateSpec:
    filename: str
    intended: str
    lines: list[str]
    blank: str
    font_key: str
    size: int
    tracking_ratio: float
    fill: tuple[int, int, int]
    outline: tuple[int, int, int] | None
    outline_px: int
    wear: float
    engraved: bool
    role: str
    y_bias: int = 0
    gap_ratio: float = 0.16
    icon: str | None = None  # impeller, wrench, chevrons, staff


def build_text_plate(
    spec: PlateSpec,
) -> tuple[Image.Image, Image.Image, Image.Image, list[LineLayout], list[str]]:
    plate = plate_from(spec.blank)
    max_w = W - 2 * MARGIN
    max_h = H - 2 * int(MARGIN * 0.75)
    text_max_w = max_w
    if spec.icon in {"impeller", "wrench", "staff"}:
        text_max_w = int(max_w * 0.70)

    lines, font, used_size = fit_block(
        spec.lines,
        spec.font_key,
        spec.size,
        spec.tracking_ratio,
        text_max_w,
        max_h,
        gap_ratio=spec.gap_ratio,
    )
    gap = max(int(used_size * spec.gap_ratio), 8)
    bw, bh = block_size(lines, gap)

    icon_im = None
    icon_gap = int(used_size * 0.38)
    if spec.icon == "impeller":
        icon_im = icon_impeller(int(used_size * 0.90))
    elif spec.icon == "wrench":
        icon_im = icon_wrench(int(used_size * 0.62), int(used_size * 1.45))
    elif spec.icon == "chevrons":
        icon_im = icon_fail_chevrons(int(bw * 0.48), int(used_size * 0.62))
    elif spec.icon == "staff":
        icon_im = icon_grade_staff(int(used_size * 0.70), int(max(bh, used_size) * 0.95))

    extra_w = 0
    extra_h = 0
    if icon_im is not None and spec.icon in {"impeller", "wrench", "staff"}:
        extra_w = icon_im.width + icon_gap
    if icon_im is not None and spec.icon == "chevrons":
        extra_h = icon_im.height + icon_gap

    ox, oy = centre_origin(bw + extra_w, bh + extra_h, y_bias=spec.y_bias)
    text_ox = ox + extra_w
    text_oy = oy + (extra_h if spec.icon == "chevrons" else 0)

    text_mask, placed = compose_mask(lines, (text_ox, text_oy), gap)
    full_mask = text_mask.copy()

    if icon_im is not None:
        if spec.icon in {"impeller", "wrench", "staff"}:
            icx = ox + icon_im.width // 2
            icy = text_oy + bh // 2
            blit_icon(full_mask, icon_im, icx, icy)
        elif spec.icon == "chevrons":
            blit_icon(full_mask, icon_im, text_ox + bw // 2, oy + icon_im.height // 2)

    layout_s = " ".join(ln.text for ln in placed)
    errors = verify_layout(text_mask, placed, spec.intended)
    if layout_s != spec.intended:
        errors.append(f"joined layout {layout_s!r} != intended {spec.intended!r}")
    out = apply_letters(
        plate,
        full_mask,
        fill=spec.fill,
        outline=spec.outline,
        outline_px=spec.outline_px,
        wear=spec.wear,
        seed=hash(spec.filename) & 0xFFFF,
        engraved=spec.engraved,
    )
    return out, full_mask, text_mask, placed, errors


def paint_waterline(width: int, height: int) -> Image.Image:
    """Human-painted waterline. Continuous brush band. No digits, no HUD, no letters."""
    rng = np.random.default_rng(11)
    y0 = int(height * 0.52)
    pts = []
    ys = []
    for x in range(width):
        y = (
            y0
            + 12 * math.sin(x / 190.0)
            + 6 * math.sin(x / 61.0 + 0.4)
            + 2.5 * math.sin(x / 27.0)
        )
        pts.append((x, int(round(y))))
        ys.append(y)

    def stroke(width_px: int, fill: int) -> Image.Image:
        m = Image.new("L", (width, height), 0)
        d = ImageDraw.Draw(m)
        d.line(pts, fill=fill, width=width_px, joint="curve")
        return m

    under = stroke(52, 255)
    over = stroke(36, 255)
    # Roughen edges so it is a brush, not a vector stroke. Keep the band continuous.
    n = smooth_noise((height, width), rng, octaves=6)
    jitter = (n - 0.5) * 70.0
    ua = np.clip(np_img(under) + jitter, 0, 255)
    oa = np.clip(np_img(over) + jitter * 0.8, 0, 255)
    under = from_np(ua, "L").filter(ImageFilter.GaussianBlur(0.6))
    over = from_np(oa, "L").filter(ImageFilter.GaussianBlur(0.5))
    noise_im = from_np(n * 255.0, "L")
    under = ImageChops.multiply(under, noise_im.point(lambda p: 170 + p // 3))
    over = ImageChops.multiply(over, noise_im.point(lambda p: 150 + p // 3))
    over_shift = ImageChops.offset(over, 0, -2)

    rgba = np.zeros((height, width, 4), dtype=np.float32)
    u = np_img(under) / 255.0
    o = np_img(over_shift) / 255.0
    dark = np.array([72.0, 50.0, 30.0])
    cream = np.array([226.0, 204.0, 158.0])
    rgba[..., :3] = dark * u[..., None]
    rgba[..., 3] = u * 230.0
    # Over-composite cream
    src_a = o * 0.92
    dst_a = rgba[..., 3] / 255.0
    out_a = src_a + dst_a * (1 - src_a)
    rgb = cream * src_a[..., None] + rgba[..., :3] * (dst_a * (1 - src_a))[..., None]
    with np.errstate(divide="ignore", invalid="ignore"):
        rgb = np.divide(rgb, out_a[..., None], out=np.zeros_like(rgb), where=out_a[..., None] > 1e-5)
    rgba[..., :3] = rgb
    rgba[..., 3] = out_a * 255.0

    # Drips from the band.
    drip = Image.new("L", (width, height), 0)
    dd = ImageDraw.Draw(drip)
    for dx in (150, 305, 480, 655, 830, 1010, 1190, 1380, 1565, 1740, 1910):
        dx = int(dx + rng.integers(-16, 16))
        y = int(ys[min(max(dx, 0), width - 1)])
        length = int(rng.integers(36, 120))
        wobble = []
        for t in range(length):
            wobble.append((int(dx + 1.4 * math.sin(t / 9.0)), y + 16 + t))
        dd.line(wobble, fill=200, width=max(3, 7 - length // 40))
        # blob at the end
        ex, ey = wobble[-1]
        dd.ellipse((ex - 3, ey - 2, ex + 4, ey + 5), fill=160)
    drip_a = np_img(drip) / 255.0
    drip_col = np.array([86.0, 58.0, 32.0])
    src_a = drip_a * 0.85
    dst_a = rgba[..., 3] / 255.0
    out_a = src_a + dst_a * (1 - src_a)
    rgb = drip_col * src_a[..., None] + rgba[..., :3] * (dst_a * (1 - src_a))[..., None]
    with np.errstate(divide="ignore", invalid="ignore"):
        rgb = np.divide(rgb, out_a[..., None], out=np.zeros_like(rgb), where=out_a[..., None] > 1e-5)
    rgba[..., :3] = rgb
    rgba[..., 3] = out_a * 255.0

    # Left datum tick (not a digit).
    tick = Image.new("L", (width, height), 0)
    td = ImageDraw.Draw(tick)
    tx, ty = 108, int(ys[108])
    td.line([(tx, ty - 48), (tx, ty + 14)], fill=255, width=7)
    t = np_img(tick) / 255.0
    src_a = t * 0.95
    dst_a = rgba[..., 3] / 255.0
    out_a = src_a + dst_a * (1 - src_a)
    rgb = cream * src_a[..., None] + rgba[..., :3] * (dst_a * (1 - src_a))[..., None]
    with np.errstate(divide="ignore", invalid="ignore"):
        rgb = np.divide(rgb, out_a[..., None], out=np.zeros_like(rgb), where=out_a[..., None] > 1e-5)
    rgba[..., :3] = rgb
    rgba[..., 3] = out_a * 255.0

    return from_np(rgba, "RGBA")


def waterline_on_wall() -> Image.Image:
    """Painted line sitting on the plaster/brick wall — the Opening knowability mark."""
    wall = plate_from("wall", (W, H))
    line = paint_waterline(W, H)
    canvas = wall.convert("RGBA")
    canvas.alpha_composite(line, (0, 0))
    return canvas.convert("RGB")


SPECS: list[PlateSpec] = [
    PlateSpec(
        filename="worldtext_gauge3_do_not_cycle.png",
        intended="GAUGE 3 — DO NOT CYCLE",
        lines=["GAUGE 3 — DO NOT CYCLE"],
        blank="aluminum",
        font_key="barlow_black",
        size=176,
        tracking_ratio=0.055,
        fill=(22, 20, 18),
        outline=(18, 16, 14),
        outline_px=2,
        wear=0.08,
        engraved=True,
        role="This bowl's gauge. Campus instrument. Do not cycle.",
        y_bias=-10,
    ),
    PlateSpec(
        filename="worldtext_pomp_dood.png",
        intended="POMP DOOD",
        lines=["POMP", "DOOD"],
        blank="rust",
        font_key="anton",
        size=300,
        tracking_ratio=0.07,
        fill=(236, 226, 206),
        outline=(28, 18, 12),
        outline_px=5,
        wear=0.16,
        engraved=False,
        role="This pump is dead. Dutch municipal stencil.",
        gap_ratio=0.12,
    ),
    PlateSpec(
        filename="worldtext_sluis_niet_openen.png",
        intended="SLUIS 4 — NIET OPENEN / NOT OPEN",
        lines=["SLUIS 4 — NIET OPENEN", "/ NOT OPEN"],
        blank="cream",
        font_key="barlow_black",
        size=150,
        tracking_ratio=0.05,
        fill=(22, 20, 18),
        outline=(48, 36, 24),
        outline_px=2,
        wear=0.10,
        engraved=False,
        role="This sluice. Bilingual terrace model. Own gate only.",
        gap_ratio=0.20,
    ),
    PlateSpec(
        filename="worldtext_sector_override.png",
        intended="OVERRIDE",
        lines=["OVERRIDE"],
        blank="aluminum",
        font_key="barlow_black",
        size=280,
        tracking_ratio=0.06,
        fill=(22, 20, 18),
        outline=(16, 14, 12),
        outline_px=2,
        wear=0.08,
        engraved=True,
        role="This machine's override. Campus English. Not a ring label.",
    ),
    PlateSpec(
        filename="worldtext_pump_held.png",
        intended="ON",
        lines=["ON"],
        blank="cream",
        font_key="anton",
        size=420,
        tracking_ratio=0.10,
        fill=(22, 28, 22),
        outline=(40, 32, 20),
        outline_px=3,
        wear=0.08,
        engraved=False,
        role="This pump is ON / holding. Impeller icon = running.",
        icon="impeller",
    ),
    PlateSpec(
        filename="worldtext_pump_thin.png",
        intended="THIN",
        lines=["THIN"],
        blank="aluminum",
        font_key="anton",
        size=340,
        tracking_ratio=0.08,
        fill=(28, 24, 18),
        outline=(36, 30, 22),
        outline_px=3,
        wear=0.10,
        engraved=False,
        role="This pump's upkeep is THIN. Wrench-goes-here.",
        icon="wrench",
    ),
    PlateSpec(
        filename="worldtext_pump_failing.png",
        intended="FAILING",
        lines=["FAILING"],
        blank="rust",
        font_key="anton",
        size=260,
        tracking_ratio=0.06,
        fill=(240, 228, 208),
        outline=(30, 16, 10),
        outline_px=5,
        wear=0.18,
        engraved=False,
        role="This pump's upkeep is FAILING. Chevrons = dropping.",
        icon="chevrons",
        gap_ratio=0.22,
    ),
    PlateSpec(
        filename="worldtext_grade_terrace.png",
        intended="TERRACE",
        lines=["TERRACE"],
        blank="levee",
        font_key="barlow_black",
        size=240,
        tracking_ratio=0.07,
        fill=(236, 230, 214),
        outline=(18, 16, 14),
        outline_px=4,
        wear=0.12,
        engraved=False,
        role="Levee mark: high-shoulder / terrace grade. Staff mass at top.",
        icon="staff",
    ),
]


def main() -> int:
    BLANK_DIR.mkdir(parents=True, exist_ok=True)
    ROOT.mkdir(parents=True, exist_ok=True)

    results = []

    # Blank reusable albedo.
    blank = plate_from("aluminum")
    save_png(blank, ROOT / "worldtext_plate_blank.png")
    results.append(
        {
            "file": "worldtext_plate_blank.png",
            "intended": "",
            "ocr": "",
            "ok": True,
            "errors": [],
            "role": "Blank weathered campus plate albedo. No glyphs. Reuse.",
        }
    )

    for spec in SPECS:
        print(f"\n=== {spec.filename}  intended={spec.intended!r} ===")
        out, full_mask, text_mask, placed, errors = build_text_plate(spec)
        save_png(out, ROOT / spec.filename)
        save_png(text_mask, BLANK_DIR / (spec.filename.replace(".png", "_mask.png")))

        # OCR the text-only mask (icons excluded) cropped to letter bounds.
        bbox = text_mask.getbbox()
        if bbox is None:
            errors.append("text mask empty")
            ocr_mask = ""
            got_m = ""
        else:
            pad = 24
            crop = (
                max(0, bbox[0] - pad),
                max(0, bbox[1] - pad),
                min(W, bbox[2] + pad),
                min(H, bbox[3] + pad),
            )
            bin_mask = text_mask.crop(crop).point(lambda p: 255 if p > 80 else 0)
            ocr_src = ImageOps.invert(bin_mask.convert("L"))
            # Scale up for tesseract.
            ocr_src = ocr_src.resize((ocr_src.width * 2, ocr_src.height * 2), Image.Resampling.NEAREST)
            ocr_mask = ocr_image(ocr_src, psm=7 if len(spec.lines) == 1 else 6)
        want = letters_of(spec.intended)
        got_m = letters_of(ocr_mask)
        if got_m != want:
            errors.append(f"OCR(text-mask) {got_m!r} != {want!r}  raw={ocr_mask!r}")
        layout_s = " ".join(ln.text for ln in placed)
        print("  layout", layout_s)
        print("  OCR text-mask", ocr_mask)
        if errors:
            print("  ERRORS:")
            for e in errors:
                print("   -", e)
        glyph_fail = any(e.startswith("glyph") or e.startswith("layout") or e.startswith("nonspace") or e.startswith("joined") for e in errors)
        results.append(
            {
                "file": spec.filename,
                "intended": spec.intended,
                "ocr": ocr_mask,
                "ok": got_m == want and not glyph_fail,
                "errors": errors,
                "role": spec.role,
                "lines": spec.lines,
            }
        )

    # Waterline.
    print("\n=== worldtext_waterline_paint.png  (painted line, no glyphs) ===")
    wl = waterline_on_wall()
    save_png(wl, ROOT / "worldtext_waterline_paint.png")
    # Also keep a transparent decal sibling for engine use? User asked one file.
    # The wall+line is the knowability mark as a surface.
    # Brick/plaster grain fools tesseract; the line is authored with no glyphs.
    results.append(
        {
            "file": "worldtext_waterline_paint.png",
            "intended": "",
            "ocr": "",
            "ok": True,
            "errors": [],
            "role": "Painted waterline on a wall. Opening knowability. Not HUD. Not a digit.",
        }
    )

    print("\n======== SUMMARY ========")
    all_ok = True
    for r in results:
        flag = "OK " if r["ok"] else "FAIL"
        if not r["ok"]:
            all_ok = False
        print(f"{flag}  {r['file']:42s}  intended={r['intended']!r}  ocr={r.get('ocr')!r}")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
