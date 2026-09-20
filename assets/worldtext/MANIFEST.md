# World text P0 plates

Load-bearing Opening plates for the first terrace bowl. Terrace / observatory mouth. Each plate reports **its own machine and its own bowl**, never the ring (GDD §6.1, UI §12, assets §11 / §15).

Letters were **not** drawn by an image model. Blank weathered plate albedos were generated empty; exact glyphs were composited in code (`_build_plates.py`, PIL, OFL faces). Hover will enlarge these in-game — they have to read.

**Mouth:** terrace / observatory — more English, instrument labels, weathered campus / municipal stencil (GDD §2). Hybrid Dutch–English lives on the surface. HUD stays English.

**Not in this pack:** UI icons, characters, meshes, `env_decal_waterline_dirt.png` (Flooded dressing stain; texture-agent slot, was empty, not this job). The painted knowability mark is `worldtext_waterline_paint.png`.

Format: 2048×1024 PNG, sRGB. World-plate face: Barlow Condensed Black (campus), Anton (municipal).

---

## Verification

Per-glyph IoU against the source ink, plus Tesseract on the **text-only** mask (icons excluded). Then each file was re-opened and read, character by character.

| File | Intended string | Glyphs in order | OCR (text mask) | Role |
| --- | --- | --- | --- | --- |
| `worldtext_gauge3_do_not_cycle.png` | `GAUGE 3 — DO NOT CYCLE` | G A U G E ` ` 3 ` ` — ` ` D O ` ` N O T ` ` C Y C L E | `GAUGE3-DONOTCYCLE` | This bowl's gauge. Campus instrument. Do not cycle. |
| `worldtext_pomp_dood.png` | `POMP DOOD` | P O M P ` ` D O O D | `POMP DOOD` | This pump is dead. |
| `worldtext_sluis_niet_openen.png` | `SLUIS 4 — NIET OPENEN / NOT OPEN` | S L U I S ` ` 4 ` ` — ` ` N I E T ` ` O P E N E N ` ` / ` ` N O T ` ` O P E N | `SLUIS4NIETOPENEN /NOTOPEN` | This sluice. Bilingual terrace model. Own gate only. |
| `worldtext_sector_override.png` | `OVERRIDE` | O V E R R I D E | `OVERRIDE` | This machine's override. Campus English. Not a ring / sector label. |
| `worldtext_pump_held.png` | `ON` | O N | `ON` | This pump is ON / holding. Handwheel icon = running (not colour-only). |
| `worldtext_pump_thin.png` | `THIN` | T H I N | `THIN` | This pump's upkeep is THIN. Wrench-goes-here. |
| `worldtext_pump_failing.png` | `FAILING` | F A I L I N G | `FAILING` | This pump's upkeep is FAILING. Down-chevrons = dropping. |
| `worldtext_grade_terrace.png` | `TERRACE` | T E R R A C E | `TERRACE` | Levee mark: high-shoulder / terrace grade. Triangle-on-bar = high. |
| `worldtext_waterline_paint.png` | *(none — painted line)* | — | — | Human-painted waterline on a wall. Opening knowability. Not HUD. Not a digit. |
| `worldtext_plate_blank.png` | *(none)* | — | — | Blank weathered campus plate albedo. Reuse. No glyphs. |

OCR collapses spaces and may render `—` as `-`. Letter-and-digit sequence matches the intended string in every row.

**Visual pass (re-opened pixels):** every listed character is present, in order, unmerged, with no extra letters. `3` is a three, `4` is a four, both `D`s in `DOOD` are D, both `O`s in `ON`/`DOOD` are O, `OVERRIDE` has two R's.

---

## Iconography (not extra sentences)

Upkeep and state are marks beside the word, so colour is never the only channel (UI §14).

| Plate | Mark |
| --- | --- |
| `ON` | Six-vane pump handwheel |
| `THIN` | Open-end wrench, jaws up |
| `FAILING` | Three down-chevrons |
| `TERRACE` | Survey bench-mark: filled triangle on a bar (mass at the top = high shoulder) |
| waterline | Cream/ochre brush band, drips, left datum tick. No numbers. |

---

## Rebuild

```
python3 assets/worldtext/_build_plates.py
```

Needs the OFL fonts in `/tmp/polder_fonts` and the empty plate albedos used as backgrounds. Glyphs always come from PIL, never from an image model.
