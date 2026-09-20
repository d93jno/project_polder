# P0 UI icon contract and chrome

Style lock: `assets/_style/icon_style_lock.png`. Food was an `image_edit` of that lock (RATIONS lettering removed). Fuel, scrap, and people were edit-chained from food.

This file owns the **icon style contract**. Theme chrome lives in `assets/ui/theme/` and is listed here so the P0 pack is one record.

## Style contract

| Token | Value |
| --- | --- |
| Fill | Solid / filled painterly 3D. Not outline, not mixed outline-fill |
| Stroke | None. Painted edges share one visual weight |
| Padding | ~14% of canvas on each side after subject crop |
| Background | Mint key **`#00FFAA`** `(0, 255, 170)` — chroma-key, not a HUD tile |
| Palette on the subject | Ochre, dirty cream, rust iron, wet-slate. Overcast North Sea light |
| Camera | Elevated three-quarter, matching the lock tin |
| Lettering | **None.** Games localize; this game also forbids meters |
| Shadow | Small baked contact shadow (from the lock). Key the mint field, not the shadow |

Do not mix in a later outline set, a white plate, or a second key colour.

## 32px readability

Canonical HUD size is **128px** (`ui_icon_*.png`). Squint copies are `_64` and `_32`, downscaled with Lanczos from a 512 source.

| Icon | 32px read | Silhouette |
| --- | --- | --- |
| food | ochre can + cream loaf | box + second mass |
| fuel | cream jerry, handle and X-brace | tall can, handle hole |
| scrap | rust pile, elbow pipe + flange | irregular heap |
| people | two hooded coats | two vertical figures |
| hidden | puffy smoke mass | closed organic blob |
| exposed | open eye, almond lid | almond + round iris |
| no hide | empty doorway | inverted-U, hollow |
| ducked | iron chevron down | V |
| ducking next | iron arrow right | shaft + head at 3 o'clock |
| watch spent | vertical tally-stick | I |
| watch friendly | filled pie-wedge | triangle / cone-seed |

Colour reinforces; it does not carry. The four stay distinct in greyscale because the shapes differ. People is a count of hands — not a portrait, not a smile, not a warmth meter. Combat states use a second shape language (blob / almond / arch / V / arrow / I / wedge) so they do not collide with the currency set or with `ui_pip_hit` (circle) and `ui_pip_ap` (diamond).

## Currency icons (`assets/ui/icons/`)

| File | Size |
| --- | --- |
| `ui_icon_food.png` | 128 — ration tin + loaf, blank lid |
| `ui_icon_fuel.png` | 128 — diesel jerry can |
| `ui_icon_scrap.png` | 128 — twisted fittings, pipe, bolts |
| `ui_icon_people.png` | 128 — two basin-folk figures, hoods down |
| `ui_icon_*_64.png` / `ui_icon_*_32.png` | squint copies |
| `ui_icon_*_512.png` | authoring source |
| `ui_icon_currency_sheet.png` | contact sheet, four at 128, assembled in PIL |

No SVG rebuild: the lock is filled painterly, not a stroke set. PNG is the production format.

## Combat state icons (`assets/ui/icons/`)

Edit-chained from `ui_icon_food_512.png`. Same mint, padding, fill, camera. Count, names, and phase words are engine text — not in the PNG.

| File | Shape | Means |
| --- | --- | --- |
| `ui_icon_hidden.png` | smoke cloud | no enemy has a clean line (smoke / deep water) |
| `ui_icon_exposed.png` | open eye | at least one enemy has a line. Count is a number the engine draws |
| `ui_icon_no_hide.png` | empty inverted-U doorway | Falling / open Dry — hiding is not available |
| `ui_icon_ducked.png` | iron V, point down | pinned, done for **this** phase |
| `ui_icon_ducking_next.png` | iron arrow, point right | pinned, owes the **next** phase |
| `ui_icon_watch_spent.png` | vertical iron tick | Watch spent; no volume |
| `ui_icon_watch_friendly.png` | filled wedge | friendly Watch at rest (the cone-seed, not the volume) |

`_512` / `_64` / `_32` sit next to each 128. Rebuild: `assets/ui/hud/_build_hud.py`.

Do not confuse:

| This | Is not |
| --- | --- |
| hidden (blob) | no_hide (arch). Words also backstop (UI §4.2) |
| ducked (V down) | ducking_next (arrow right). Opposite meanings |
| watch_spent (I) | `ui_pip_ap` (diamond) or `ui_pip_hit` (circle) |
| watch_friendly (wedge) | a cone volume, a faction crest, or an outline set |

## Theme chrome (`assets/ui/theme/`)

### `ui_panel_9slice.png` (512)

Blank water-board panel. Ornament in **corners only** (mirrored rust L-brackets). Uniform metal rails on the edges. Empty glass centre — no gauges, no text, no meters.

Godot `StyleBoxTexture` on the 512 file:

- `texture_margin_left/right/top/bottom` = **90**
- stretch both axes (edges are a uniform rail on purpose)

Authoring source: `ui_panel_9slice_640.png`, margins **112**.

### Pips (shape carries)

Not a bar. Not a track. Remaining hits / remaining AP are counts of these.

| File | Shape | Value |
| --- | --- | --- |
| `ui_pip_hit.png` | filled circle | light cream |
| `ui_pip_ap.png` | filled diamond | dark iron |
| `ui_pip_bleed.png` | filled teardrop, tip down | dried-blood rust |

Same mint key. `_64` and `_32` sit next to them. Greyscale still separates: circle vs diamond vs teardrop. Bleed is a count of remaining rounds, not a bar.

### `ui_confirm_frame.png` (512, RGBA)

Ugly-on-purpose frame for shooting a downed unit (UI §4 / §5). Geometry only — no letters, no skull, no X. Jagged inner bevel; **not** 9-slice (mid-edge spikes would smear). Scale uniformly or use at native size. Outer field is alpha.

### Combat chrome added this pass (do not replace the 9-slice or existing pips)

| File | Notes |
| --- | --- |
| `ui_selection_frame.png` | 512 RGBA. Four rust L-brackets, empty centre, no crown. Same for founder and everyone. Transparent is `(0,0,0,0)`. Scale uniformly. |
| `ui_fireteam_slot.png` | 256×384. 9-sliced from the panel (margin **72**). Empty glass — name is engine text. |
| `ui_phase_yours.png` | filled rust **square** plaque. Fight only; squad mode has no End Turn. |
| `ui_phase_theirs.png` | filled rust **triangle** plaque. Shape, not words. |
| `ui_fuel_count_frame.png` | 256 empty count frame, 9-sliced from the panel (margin **72**). Engine writes the number. Not a gauge. `_128` next to it. |

## Anti-goals (do not add)

Bars, karma / dusk / warmth meters, founder VIP crown, baked English, research percentages, faction chrome.

## Defects

- Fuel and scrap sit slightly more photoreal than food and people. Palette, fill, padding, mint, and camera match; medium is not identical.
- 9-slice edge rails are a clean extrusion so they survive stretch. They do not carry the corners' rust texture. That is the 9-slice contract, not a missed paint pass.
- Icon contact shadows are baked. Key `#00FFAA` with a small tolerance; do not key the shadow away.
- Combat HUD defects live in `assets/ui/hud/MANIFEST.md`.
