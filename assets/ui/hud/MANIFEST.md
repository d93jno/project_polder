# P0 combat HUD chrome

Overlay **art**, not rule code. Style contract: `assets/ui/icons/MANIFEST.md`. Edit-chain from `ui_icon_food_512.png`. Rebuild: `python3 assets/ui/hud/_build_hud.py`.

Mint key **`#00FFAA`** `(0, 255, 170)` on icons, pips, path marks. Selection and line strokes use alpha instead. No lettering in any texture. Colour never carries — shape does.

Canonical HUD size is **128**. Squint copies `_64` / `_32` are Lanczos from a 512 (or 128) master. Contact sheet of the new 128s: `ui_hud_contact_sheet.png` (PIL, not an image model).

Hit circle and AP diamond **already exist** in `assets/ui/theme/` (`ui_pip_hit`, `ui_pip_ap`). Confirm frame already exists (`ui_confirm_frame`). Do not duplicate them.

---

## Icons (`assets/ui/icons/`)

| File | Shape | Means | Do not confuse with |
| --- | --- | --- | --- |
| `ui_icon_hidden.png` | puffy smoke cloud (closed blob) | no enemy has a clean line — smoke or deep water | `ui_icon_no_hide` (hollow arch). Hidden is mass; no-hide is empty. |
| `ui_icon_exposed.png` | open eye, almond lid, round iris | at least one enemy has a line | a heat map, a score, or a count. The count is a **number the engine draws**. |
| `ui_icon_no_hide.png` | empty inverted-U doorway, mint through the opening | Falling / open Dry — hiding is not available | hidden. Words also show in-engine (UI §4.2). |
| `ui_icon_ducked.png` | rust-iron **V**, point down | pinned, done for **this** phase | `ui_icon_ducking_next`. Same family, opposite meaning. |
| `ui_icon_ducking_next.png` | rust-iron **arrow**, point right (3 o'clock) | pinned, owes the **next** phase | ducked; a rewind clock; `ui_pip_ap`. |
| `ui_icon_watch_spent.png` | vertical iron tally-stick (I) | Watch spent; tick on the unit, **no volume** | `ui_pip_hit` (circle), `ui_pip_ap` (diamond), `ui_pip_bleed` (teardrop). |
| `ui_icon_watch_friendly.png` | filled pie-wedge / cone-seed | friendly Watch at rest — the small marker, not the volume | a cone volume, a faction crest, an outline set. Filled, to stay on the icon contract. |

Each has `_512` / `_64` / `_32`. ~14% padding. Greyscale: blob / almond / arch / V / arrow / I / wedge.

---

## Theme chrome (`assets/ui/theme/`) — new files only

Existing `ui_panel_9slice`, `ui_pip_hit`, `ui_pip_ap`, `ui_confirm_frame` were not replaced.

| File | Size | Shape / use | Do not confuse with |
| --- | --- | --- | --- |
| `ui_selection_frame.png` | 512 RGBA | four rust L-brackets, empty centre, **no crown** | `ui_confirm_frame` (jagged, ugly-on-purpose). Same frame for founder and everyone. |
| `ui_fireteam_slot.png` | 256×384 RGB | empty portrait slot, 9-sliced from the panel, margin **72** | a named plate. Name is engine text. |
| `ui_phase_yours.png` | 128 mint | filled rust **square** plaque | `ui_pip_ap` (diamond), `ui_path_tile` (light cream cell). Fight only; squad mode has no End Turn. |
| `ui_phase_theirs.png` | 128 mint | filled rust **triangle** plaque | phase_yours (square). Shape, not words. |
| `ui_pip_bleed.png` | 128 mint | filled **teardrop**, tip at 6 o'clock, dried-blood rust | `ui_pip_hit` (cream circle), `ui_pip_ap` (iron diamond). Count of remaining rounds, not a bar. |
| `ui_fuel_count_frame.png` | 256 RGB | empty 9-slice count frame, margin **72** | a gauge / fuel bar. Engine writes the number. `ui_fuel_count_frame_128.png` for a tight HUD. |

Phase `_512` / `_64` / `_32` and bleed `_64` / `_32` sit next to the canonical files.

---

## Strip / path / line (`assets/ui/hud/`)

| File | Size | Shape / use | Do not confuse with |
| --- | --- | --- | --- |
| `ui_line_clean.png` | 256×32 RGBA | solid cream-iron rail, 16px stroke, tileable on X | a hit-chance bar. Overlay stroke for a **clean** shot. |
| `ui_line_blocked.png` | 256×32 RGBA | **dashed** rail, 16px on / 16px off, same cream-iron | `ui_line_clean`. Shape (dash), not red. Tiles at 32px. |
| `ui_path_tile.png` | 128 mint | cream rounded-square cell plate | phase_yours (dark rust square). Move-path cell. `_64` / `_32`. |
| `ui_path_reserve_shot.png` | 128 mint | iron **T-bar** | `ui_path_reserve_watch` (wedge), `ui_pip_ap` (diamond). Mark where the **shot** stops being affordable. |
| `ui_path_reserve_watch.png` | 128 mint | iron **wedge** (same family as friendly Watch) | reserve_shot (T). Mark where a **Watch** stops being affordable. |
| `ui_undo_afford.png` | 128 mint | work-boot lifting off a wet-slate tile | a rewind clock, a save-scum loop. Reversible-move affordance (UI §5). `_512` / `_64` / `_32`. |
| `ui_hud_digits.png` | 640×64 mint | ten 64px cells, **0 1 2 3 4 5 6 7 8 9** left to right | baked image-model text. Glyphs are PIL, Barlow Condensed Black, cream fill, iron drop-shadow. Height-on-tile / HUD counts. Engine may also draw in the HUD font. |
| `ui_hud_contact_sheet.png` | 712×432 mint | 14 new 128s, 5×3, PIL | production art. Review only. |

Line 9-slice: treat as a three-patch strip (8px ends are the same rail as the middle). Blocked must stay dashed if sliced — do not stretch a single dash into a solid.

---

## Digit atlas — character-by-character

Re-opened `ui_hud_digits.png`. Cells left to right, 64px each:

| Cell | Glyph |
| --- | --- |
| 0 | **0** (closed round) |
| 1 | **1** (single stem) |
| 2 | **2** |
| 3 | **3** |
| 4 | **4** (open, not a closed A) |
| 5 | **5** |
| 6 | **6** (bowl + stem) |
| 7 | **7** |
| 8 | **8** (two closed loops) |
| 9 | **9** (loop on top) |

Order is `0123456789`. No extra letters, no merges. Tesseract on mint (and on a white flatten) is unreliable with this condensed face; the atlas is font-drawn, not an image model.

---

## Greyscale notes

Load-bearing pairs that must survive greyscale (UI §14):

| Pair | Channel that carries |
| --- | --- |
| hidden / exposed / no hide | blob vs almond vs hollow arch |
| ducked / ducking next | V-down vs arrow-right (direction) |
| watch spent / watch friendly | I vs wedge |
| phase yours / theirs | square vs triangle |
| hit / AP / bleed | circle vs diamond vs teardrop |
| line clean / blocked | solid vs dash |
| reserve shot / reserve watch | T vs wedge |
| path tile / phase yours | light cream plate vs dark rust square |

Value reinforces (cream vs rust iron vs dried-blood). Hue is never the only difference.

---

## Anti-goals (not in this pack)

Hit chance, exposure score, threat heat map, dusk bar, Founder Away, “will break” badge, faction crests, meters, founder crown, baked English, a rewind clock.

Watch **volumes** (live enemy cone, unresolved-apex variant) are shader work, not this pass.

---

## Defects

- `ui_undo_afford` is more photoreal than the tin-lock icons (same class of defect as fuel / scrap). Silhouette (boot on a tile) is the carrier.
- `ui_pip_bleed` is smoother/more rendered than `ui_pip_hit`. Shape (teardrop) is the carrier.
- `ui_icon_no_hide` reads thin at 32px (two posts + lintel). The hollow inverted-U still differs from the smoke blob; UI §4.2 also puts the words on the unit.
- `ui_icon_watch_friendly` is a filled wedge, not a stroke outline, so the set does not mix outline-fill. “Outline marker” in UI §4.4 means *not the full cone volume*.
- `ui_path_reserve_watch` shares the wedge silhouette with `ui_icon_watch_friendly` on purpose (cone-seed family). They sit in different slots (path vs unit).
- Fireteam slot and fuel count frame reuse the 9-slice rails, so edge texture is the clean extrusion, same as the panel.
- Icon contact shadows are baked. Key `#00FFAA` with a small tolerance; do not key the shadow away. Selection transparent pixels are `(0,0,0,0)`.
