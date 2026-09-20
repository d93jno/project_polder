# Project Polder — Graphical Asset Inventory

**Version:** 0.2 — retargeted to GDD v1.8 and UI/UX v0.4. The v0.3 review was accepted in full, so every surface previously marked *review-pending* is now locked UI and cited as such. UI section numbers were remapped; v0.4 expanded 12 sections to 19. (0.1: first inventory, tracking GDD v1.7 / UI/UX v0.3.)
**Tracks:** GDD v1.8, UI/UX v0.4.

**Versioning.** The version lives in this header, not in the filename. `Game_Design_Document.md` and `UI_UX_Document.md` follow the same rule.

This document owns **what must be drawn**. It does not own rules (GDD), how the player touches the game (UI/UX), how it looks as a style (art direction, not yet written), or how it sounds (audio, not yet written). When those documents disagree with a count or a look described here, they win.

Art direction will later decide medium, palette, and silhouette language. Until then, every item below is a production slot: a mesh, a texture set, a shader look, an icon, or a state variant that the current design already requires.

Citations: *GDD §x.y*, *UI §x*. Items marked *working default* are starting points, not locks. Nothing here is review-pending any more: `UI_UX_Review_Findings.md` was accepted in full and its findings live in UI/UX v0.4, so this document cites the UI document directly.

---

## 0. Scope

**Owns:** the closed list of graphical assets the game needs to ship the loop in GDD §3, at the presentation the UI document specifies.

**Does not own:** audio; animation timing as gameplay; exact poly/texel budgets; final grid size; the art-direction document.

**Engine.** Godot 4.7, Forward+, GDScript. Tactical view is **3D geometry on a data grid**, not sprite isometric (UI §2). Blockout is `GridMap`; shipped density may move to `MultiMeshInstance3D` (UI §17). Water is **one plane per bowl**, step-driven shader, height from data. A levee map holds two planes. Floors are separate nodes so cutaway is a visibility toggle.

That choice is the cost driver. 3D raises per-asset art cost and pushes production toward **modular kits** reused across bowls, water steps, and both cameras (UI §17). This inventory is written as kits, not as one unique mesh per street.

**Two cameras, one basin** (UI §1, GDD §3.1). Squad mode and table mode look at the same authored world. Do not author a second geoscape. Table-scale work is LOD, overlays, and the Citadel interior — not a different country.

---

## 1. Production constraints the art must obey

These are not style notes. They are filters. An asset that fails one of them is wrong even if it looks good.

| Filter | Source | What it means for assets |
| --- | --- | --- |
| One bowl, authored once, played at four water steps | UI §3, GDD §6.3 | Buildings, streets and interiors are **not** duplicated per step. Water height and surface look change. Weathering and debris can swap. The mesh kit does not. |
| Falling never reads as Flooded | UI §3 | Two water looks, plus debris and motion, must survive greyscale and reduced motion (UI §14). Colour cannot be the only difference. The exposure read backstops it in words — *hidden* against *no hide* (UI §4.2) — so the surfaces carry the lesson but are not its only carrier. |
| Same grammar in every water step | UI §1 | HUD, cones, previews and icons do not change costume when the floor dries. |
| No faction chrome until research names them | UI §4, GDD §6.5 | First Vanguard contact uses the same cone language and no unique colour, tag, or banner. Identity is silhouette, kit, and cone length. |
| Gold-rush third body is a rival party | UI §4, GDD §6.3 | A second hostile group on the same map cannot read as “more Drifters.” |
| Occupants are always there; fog decides the draw | UI §7, GDD §3.1 | No spawn-in animation. Reveal is “they were simply there.” |
| Staleness is ageing, not a number | UI §6 | Known-quiet has a weathering look that gets quieter. No day-count badge. |
| Water is current, people are not | UI §6 | A known-quiet street can show today’s water and nobody. That split must be visible. |
| No meters | UI §1, GDD §4.2 | Currencies, health, wear, warmth, research, endings: counts, states, or the world. Never a bar, pip track, or score. |
| No founder VIP mark | UI §4, §16 | The player finds their own founder by **name**, on the unit and in the fireteam strip (UI §4.10). Not a crown, not a clothing tell, not a colour-only outline. No art is owed here beyond a legible name plate. |
| No ridge marker | UI §7, §16 | The Citadel on the horizon is a mesh in the skybox/far field, never a compass pip. |
| World text is a surface | UI §12, GDD §2 | Hybrid Dutch–English lives on plates, signs, graffiti. HUD stays English. No translation toggle. |
| Tile memory persists | UI §3 | Wrecks, dropped crates, scarred walls, ruined fields are placeable overlays, not a reset. |
| Told in play | GDD §1, UI §1 | No cutscene art, no required codex illustrations, no briefing paintings. The campaign poster is looking down from the dome (GDD §2). |
| Colour never carries a load-bearing read | UI §14 | Cones, water steps, fog ageing, exposure, Pinned, pump upkeep and band warmth need a second channel: value, motion, shape, or text. Reduced motion is a supported setting, so nothing that only animates may be a state's sole carrier. |

**Shared skeleton.** All humanoids — founder, roster, factions, roof people, bands — share one rig. Kit is meshes on sockets. Class is training plus kit (GDD §8), not a new body. Faction is silhouette, cloth, and weapon, not a different skeleton.

**Shared cover language.** Material is the only cover (GDD §5.4). Every cover mesh carries a material tag the line preview can name: plank/crate (stops pistol, not rifle), masonry, metal, deployed barrier, smoke. The hover read is UI; the mesh must make the class guessable before the hover.

---

## 2. Formats and folder layout

*Working default* until the Godot pipeline document says otherwise.

| Kind | Format | Notes |
| --- | --- | --- |
| World meshes | glTF 2.0 (`.glb`) | Y-up, meters, origin at tile centre / footprint. No baked ground shadow. |
| Characters | `.glb` + shared skeleton | One humanoid, retargeted. Attach sockets: hand_r, hand_l, back, head. |
| Animations | Godot `AnimationLibrary` on that skeleton | Cycles loop. Water-step locomotion is the same clip retargeted or a variant, not a new rig. |
| Textures | PNG source → imported VRAM-compressed | Albedo, normal, roughness/metallic packed. No text in albedo except world-plate textures, which are authored as text. |
| Water / fog / cones | Godot Shader Material | Data-driven. Not a unique mesh per step. |
| Decals | Godot `Decal` + texture | Ageing, scorch, oil, graffiti, leaks. |
| UI chrome | Godot Theme + 9-slice `StyleBoxTexture` | No lettering in the texture. Games localize; this game also forbids meters. |
| Icons | SVG or 64/128 PNG, one style contract | Must read at 32px (UI icons). Uniform padding. |
| Fonts | One HUD face, one world-plate face | HUD: readable English. World: municipal / stencil / weathered campus (GDD §2). World plates may be texture, not live font, if the hybrid glyphs need drawing. |
| Skies | Sky shader or panorama | Three dusk looks (UI §7). No weather gating of the ridge. |

Proposed `res://` layout (create when art lands; do not invent empty stubs for their own sake):

```
assets/
  env/kits/          # GridMap mesh libraries
  env/hero/          # unique buildings, Citadel, ridge, causeway
  env/decals/
  chars/humanoid/    # shared skeleton, bodies, faces, kit
  chars/anims/
  vehicles/
  props/
  vfx/
  ui/theme/
  ui/icons/
  ui/table/
  worldtext/
  shaders/
```

Naming: `kind_kit_piece_variant`, lowercase, no spaces. Example: `env_levee_straight_a`, `char_kit_speargun`, `ui_icon_food`.

---

## 3. Priority cuts

Produce in this order. Later acts reuse earlier kits.

### P0 — First playable bowl (walk plus one fight)

UI §18. One Flooded roof map and one Dry street for the camera test. Free move until contact. One fight.

| Slot | Why it blocks |
| --- | --- |
| Terrace street + roof kit, two floors, cutaway | The bowl is the game |
| Water plane: Flooded look | Swim, dive, boat |
| Water plane: Dry look (same geo) | Camera test; Falling is P1 |
| Player boat as extract / home object | GDD §3.1, UI §4 |
| Unclassed basin-folk fireteam (4) + founder face | Phase 0 has no classes |
| Drifters (one hostile kit) | First fight |
| Cover set: crate, plank, masonry corner | Line preview names the blocker |
| Pump house + one sluice/gauge | Objectives are machines |
| Watch cone, spent tick, line preview, move preview, selection | Combat has no dice; the preview is the art |
| Exposure read: hidden / exposed / no hide, per unit and per path tile | UI §4.2. Blocks the first fight — diving and smoke are guesswork without it |
| Height-on-tile read | “Is that roof above the water?” |
| Ridge as far-field silhouette from terrace | Horizon object, no marker |
| Dusk look A (high light) | Day is spent by walking; one look is enough to start |
| Minimal tactical HUD chrome (no meters) | AP pool and per-action cost (UI §4.1), hit-state pips (UI §4.3), exposure (UI §4.2) and the bleeding-out count are all specified now, and the first fight cannot ship without them. Placeholder geometry is allowed; the reads are not optional. |

### P1 — Opening, end to end

| Slot | Why |
| --- | --- |
| Falling water look (never Flooded) | Teaches the dive is gone |
| Mud look (can be a cheap cousin of Dry + pools) | Optional in P1 if the first bowl never leaves Flooded; needed before a ring drops |
| Dusk looks B and C (long shadows, then dark) | Three named looks (UI §7). Look C waits on GDD §10 after-dark rule — do not paint a rule that is not written. Until then, look C is lighting only. |
| Neighbouring-bowl seam / levee wall | Travel is a place, not a load screen |
| Marked-roof states: unseen / slept once / marked | Shelters persist |
| Knock / meeting / hostile-roof occupants | Same people, fog hides them |
| Boat camp dressing (tents, crates, people who are not the fireteam) | Home until the dome |
| World plates on pumps and levees | Phase 0 knowability. GDD §6.1 (1.8) says the right to read water does not begin with the dome, so plates carry step, grade, pump state and upkeep until instruments wake (UI §12). Bounded by what a plate could know: its own machine and bowl, never the ring. |
| Tile-memory overlays: wreck, dropped crate, scarred wall | Return visits |

### P2 — Act I (penthouse, first table)

| Slot | Why |
| --- | --- |
| Citadel exterior: dome, upper labs, slope, car park still wet | Found by walking |
| Citadel interior: dome glass, dark gauges, one hall | Instruments start dead |
| Table overlay kit (graph, labor, mail marks, dispatch) | UI §8 |
| First Gauge firing picture (map change + squad react) | GDD §8.3, UI §4 |
| Wake-Riders + their boats | Flooded specialists |
| Purifiers + wrench / pulpit | Hold-the-ring |
| Class kits on the shared body: Frogman, Pioneer (early) | Workshop is later; Frogman is survival + kit |
| Roof-eyes / watch post dressing | Live vision from a posting |

### P3 — Act II (descent, mud, gold rush)

| Slot | Why |
| --- | --- |
| Mud water + double-cost walk body language | GDD §5.8 |
| Gold-rush crate / cache (rival-readable) | Third party on the map |
| Muckraker kit + winch VFX | Mud class |
| Pioneer barricade, smoke, oil, stun-dart | Deployables |
| Citadel lower floors: mold, dredge, hydroponics stopgap | Phase 2 |
| Workshop, med-bay, ammo press as interior/facility props | Hard penthouse choices |
| Dry-tile start: empty, field-promise, road | After the terrace ring |

### P4 — Act III (compound, Vanguard, ending)

| Slot | Why |
| --- | --- |
| Vanguard infantry, armor, APC / truck, FOB, causeway growth | Unnamed at first contact; chrome only after research |
| Overwatch kit, kinetic cover, anti-armor charge | Dry streets |
| Compound: tents and steel on the dry slope, garage, munitions | Phase 3 |
| Fields, posts, forward camps, ruined fields | Dry tile states |
| Watchtower, radio mast, radar heading overlay | Vision research |
| Town ambient: people on the slope, kids, harvest | The ending is the town you can see (GDD §6.6) |
| Ending basin looks: working / hollow / bitter / civic-lose | No score screen; the map is the credits |

---

## 4. Environment kits

Author **once**. Swap water, debris, ageing, and dry-tile dressing. GridMap-friendly: even footprint, origin at cell, few unique hero meshes.

### 4.1 Kit A — Terrace polder (P0)

The first geography (GDD §2). High shoulder, few pumps, water has somewhere downhill to go. Dutch-flat, geometric, diked, built below the water that wanted it.

| Piece | Count *working default* | Notes |
| --- | --- | --- |
| Road / street slab | 3 albedo variants | Wet and dry material variants, same mesh |
| Curb / sidewalk | 2 | |
| Canal wall / quay | 2 heights | Walkable rim |
| Levee / dike: straight, inner corner, outer corner, slope, gate | 1 of each + 1 fill | Neutral lighting so pieces rotate (see tileset rotation economy). Text and pumps are **not** rotated. |
| Building shell, 2-storey terrace house | 4 footprints | Gable / brick / rendered. Interior floor plates separate. |
| Building shell, 3–4 storey block | 3 | Roof always walkable |
| Industrial shed / workshop | 2 | Gold-rush later |
| Roof deck (flat) | 4 | Shanty frames snap on |
| Shanty add-on: tarp, pallet wall, water tank, plot box | 6 | Rooftop farms, sleeping, lookouts |
| Stair, ladder, fire escape, hatch | 1 each, 2 rotations if not symmetric | Climb grammar |
| Interior floor plate + wall set per storey | 1 kit | Cutaway hides storeys above N (UI §2) |
| Door: shut, open, boarded | 1 set | Knock resolve in P0 is a **data flag on approach tiles**, not window meshes (UI §18). Doors are dressing. |
| Roof deck read as a place with sightlines | 1 dressing pass | GDD §3.1 splits deck from interior: deck occupants see the approaches, interior occupants see nothing until the knock. Once the tile is Live the deck must look like somewhere with a view (UI §7). It never says who is on it. |
| Window: intact, dark, boarded | 1 set | Same |
| Overpass pier + deck | 1 kit | High-point shelter |
| Parking deck slab | 1 | |
| Pump house (hero) | 1, plus damaged / dead dressing | States: on / damaged / dead (GDD §6.1). Upkeep is a separate, locked read — **kept / thin / failing** (UI §8, GDD §6.1) — so three wear looks, not reserved slots. *Thin* is the one that matters: it is where a Purifier wrench goes. |
| Sluice / gauge (hero, animated) | 1 | First Gauge and redirection play here. Gate must move. |
| Pier / boat dock | 1 | Extract point |
| Street furniture: lamp, bench, bollard, rail | 4 | Cover-or-not must be tagged. Rails that look like cover but are not will break principle 1. |
| Vegetation: reeds, drowned hedge, terrace tree | 3 | Sparse. This is not a forest. |

**Water-step dressing (same kit):**

| Step | Extra |
| --- | --- |
| Flooded | Floating debris decals, drowned-car hint, waterline dirt on walls |
| Falling | Chest-line stain, more debris, no dive volume |
| Mud | Pool decals, ruts, silt, stranded boats |
| Dry | Puddle decals at most, dust, open sightlines, fields later |

Waterline dirt is a **decal or material parameter**, not a unique building mesh per step.

### 4.2 Kit B — Floor polder (P2–P3)

Ordinary reclaimed towns and industrial parks (GDD §2). Same grammar, larger footprints, longer streets (fatal funnel).

| Piece | Notes |
| --- | --- |
| Wider street / avenue slabs | Dry sightlines |
| Shop / municipal building shells | Ugly useful. More Dutch on plates. |
| Warehouse / corporate block | Gold-rush interiors |
| Subway entrance + short tunnel (Dry only) | GDD §6.3 |
| Basement interiors | Exposed when Dry |
| Field tile, barley / plot, ruined field | Dry tile states |
| Road tile, camp tile, post tile, forward-camp tile | Table and tactical dressing |
| Burned field / drowned barley | Hangover, hollow/bitter read |

### 4.3 Kit C — Sump (P3–P4)

True low bowls, old peat, rusted loot (GDD §2). Preservation gradient: longest underwater, worst caches.

| Piece | Notes |
| --- | --- |
| Peat / sludge ground | |
| Heavier rust and mold material set | Same shells as Kit A/B, worse wear |
| Citadel cellars (flood from below until sump drops) | Hero interior |

### 4.4 Kit D — Far rim / highland edge (P4)

Seen, not marched on. Pristine caches. Wall of dry land (GDD §2). Vanguard country as a horizon and as FOBs that enter the basin — not a playable highland campaign.

| Piece | Notes |
| --- | --- |
| Dry rim escarpment / wall of land | Far field |
| Causeway under construction, 3+ growth stages | Table object, grows day by day (GDD §3.2, UI §8) |
| Vanguard FOB kit | Place on the map, a target, not a cutscene (UI §8). Also half the push-has-broken check (GDD §6.6), so their absence must be visible without a win-condition readout. |

### 4.5 Hero environment

| Asset | When | Notes |
| --- | --- | --- |
| The ridge / Citadel exterior | P0 far field, P2 walk-on | Low moraine / sandy ridge / research hill. Survivors call it a mountain. It is not. Silhouette should look like a lie people would tell (UI §7). Glint on glass or a mast, often just a darker pile. Visibility by grade: clear from terrace, smudge from floor, nothing from sump. **Art-pass rule:** bowls must not all frame it dead centre. |
| Dome and upper labs (penthouse) | P2 | Civilian research station, not a fortress (GDD §2, §4.1). Glass, a view, dark gauges. |
| Descent floors | P3 | Moldy, dredged, sanitized over time. Cutaway of the building is the same mechanism as tactical floors (UI §9): the base view and the water graph are the same picture from different ends — the floors that opened are the bowls that dried. |
| Compound on the dry slope | P4 | Tents and steel facing the polders. No siege dressing on the glass. |
| First-contact land bridge / authored sluice street | P4 | Always has a usable gauge (GDD §6.5). Trucks that stop being trucks. |

### 4.6 Persistent overlays (tile memory)

Placeable, remain across visits (UI §3).

| Overlay | Notes |
| --- | --- |
| Wreck (car, boat, bike) | Cover-tagged |
| Dropped crate / gold-rush crate | Rival-readable when a third party is present |
| Scarred wall / impact | |
| Ruined field | |
| Oil slick (tile state) | Known extent before the throw (UI §3) |
| Surface fire | Same |
| Stun-dart shock zone | Ankle-deep; grounds out in deep (GDD §5.9) |
| Stranded boat on Mud/Dry | Wake-Rider leftover |

---

## 5. Water, sky, time

### 5.1 Water surface (one shader, four looks)

Not four meshes. One plane per bowl; a levee map holds two (UI §3, §17). Height from data.

| Look | Player must see at a glance | Channels besides colour |
| --- | --- | --- |
| **Flooded** | Swim tiles vs boat tiles; where a unit can dive out of sight | Deep, dark, **moving**. Dive volume. Reflections of roofs. |
| **Falling** | No hiding. Deep enough to slow, too shallow to vanish | Chest-deep, murky, **debris**. Motion quieter than Flooded. Waterline stain. |
| **Mud** | Double move cost, visible per tile in the move preview | Wet ground, standing pools. Walk splashes, not a swim surface. |
| **Dry** | Long open lines. Street feels exposed before a cone is drawn | Ground, puddles at most. |

Mid-fight water does not change except a chosen redirection. When a sluice opens, the change plays **tile by tile**, never a fade-to-black (UI §3). That is an animation of the existing plane, not a new asset pack.

**Redirection preview** is locked (UI §8, GDD §6.4). Before the sluice is spent the player sees which bowls step wetter and by how much, whether creep reaches the next bowl, roughly how long the target hangs wet, and what of theirs is standing in it — roads, fields, camps, posts. So: a ghost-water overlay look, plus a way to mark the player's own tiles inside it. Precision follows the ring, so the overlay needs a *this is a range* variant for a half-fixed outer bowl.

### 5.2 Skies and dusk

Three named looks on the day clock (UI §7). No dusk bar. Readable before leaving the boat.

| Look | Lighting | Notes |
| --- | --- | --- |
| High light | Hard, high | Default day |
| Long shadows | Low sun, long raking shadows | Second look. Makes dikes and canals read. |
| Dark | Night | Third look. **Do not invent Wake-Rider night chrome** until GDD §10 says what changes after dark. Lighting and a worse-fight mood only. |

No weather that gates the ridge (UI §7). No seasonal sky set — there are no calendar seasons (GDD §3.2).

Fog states are **not** weather (UI §6):

| Fog | Drawn | Hidden |
| --- | --- | --- |
| Unknown | Nothing | Everything |
| Known-quiet | Terrain and water step, ageing | All actors, including bands |
| Live | The present | Only what line of sight hides |

Ageing on known-quiet: dust, flatter colour, colder marks. A gradient of looks, not a digit. Hover may use words the game already has (“not seen since your last visit”).

---

## 6. Characters

One humanoid. Variation is body, face, cloth, kit, scar, and state. Named roster members are palette + face + kit, not unique heroes (GDD §4.3 forbids per-citizen clicking; the roster is the fireteam pool).

### 6.1 Shared body

| Asset | Count *working default* | Notes |
| --- | --- | --- |
| Humanoid skeleton | 1 | Walk, swim, climb, prone, boat-sit |
| Body meshes | 3 (light / mid / heavy) | Heavy is Vanguard armor and late plating, not a second species |
| Founder faces | 6–8 | Customization is name, face, starting kit type (GDD §8.2, UI §5). No secret highland loadout, no stat spread. The creation screen must not read as a class pick. |
| Roster faces | 12–16 | Recycled. Roof meetings put a face on the bench. |
| Hair / headwear | 8 | Including wet-slick, hood, helmet |
| Hands that grip | — | Weapons must be held, not floating (character-consistency). Same hand across views. |

**Founder read for the player** (UI §4.10): the founder is identified the way every other unit is — by **name**, on the unit and in the fireteam strip. No clothing tell, no crown, no colour-only outline. GDD §5.10 is a rule about AI targeting, not about drawing; the art owes nothing here but a legible name.

### 6.2 Player kits (equipment on sockets)

Class is training plus kit (GDD §8). Phase 0 is unclassed. Everyone swims.

| Kit | Weapons / gear | Silhouette | When |
| --- | --- | --- | --- |
| Unclassed basin folk | Sidearm or machete, wet weather clothes | Boat-camp | P0 |
| Frogman | Speargun, suppressed sidearm, no heavy | Wetsuit / salvage dive | P2 |
| Muckraker | Shotgun, sledge, winch / grapple | Heavy CQB, mud cleats | P3 |
| Pioneer | Sidearm, barricade pack, smoke, traps | Tool harness, charges | P2–P3 |
| Overwatch | Long gun or sniper, spotter scope | Dry-land, long silhouette | P3–P4 |

Founder may wear any of these. Identity is not a unique gun (GDD §8.2).

**Weapon meshes** (held + ground pickup + UI icon of the same object):

| Weapon | Stops / notes |
| --- | --- |
| Pistol / suppressed sidearm | Two clean hits drop (GDD §5.4). Usable in deep water. |
| Machete | CQB |
| Pneumatic speargun | Makeshift armory (GDD §7.1) |
| Shotgun | Muckraker |
| Sledgehammer | Muckraker |
| Rifle / LMG | Excavation / Advanced Ballistics. Not in deep water. |
| Sniper | Overwatch. Cannot fire treading water or deep mud. |
| Pipe-bomb | Makeshift |
| Smoke grenade | Breaks line |
| Oil flask | Surface fire combo |
| Stun dart | Shock in ankle-deep |
| Anti-armor charge | Vanguard heavy |
| Deployable barricade / kinetic cover | Pioneer; later excavation upgrade |
| Trauma kit | Stops bleed-out clock |
| Winch / grappling hook | Muckraker |

Consumables are items, not a fifth bar (GDD §4.2). Each needs a world mesh and an icon.

### 6.3 Factions

Finite basin people except the Vanguard, who come from outside (GDD §1, §2). No respawn art. A cleared roof stays cleared of those people.

| Faction | Kit | Read | When |
| --- | --- | --- | --- |
| **Drifters** | Mixed salvage, CQB, rooftop | Desperate, opportunistic. Panic on Dry (stick to edges, wrong guns). Off-ramp: peel or talk. | P0 |
| **Wake-Riders** | Dive kit, speargun, boats | Water-adapted. Useless on dry. May take the boat from a roof. Truce is territorial. | P2 |
| **Purifiers** | Cult cloth, wrench, pulpit | Sermon look. Almost never an off-ramp. Sabotage a thin pump. | P2 |
| **Vanguard** | Highland military, armor, long guns | Masters of Dry. First contact: unnamed, no faction chrome, same cone language, longer than anything seen. Later: pieces dislodge (yield, wait, refuse). Prisoner variant after research. | P4 |
| **Rival gold-rush party** | Drifter-cousin or mixed | Must read as a **third party**, not more of the same enemy (UI §4). | P3 |
| **Roof people / meeting** | Civilian basin | A meeting, not a loot screen. Possible recruit. | P1 |
| **Band (nomad group)** | Boat, roof-clan, or walking family | One face stands for the group. Warm/cold is a map fact, not a portrait meter (GDD §5.12, UI §8). | P2 |
| **Town ambient** | Labor clothes, kids on a slope | Ending read. Not clickable citizens. | P4 |

Vanguard vehicles are in §7. Vanguard FOB and causeway are environment.

**Help-gamble / second meeting:** wrecked boat, sick on a deck — dressing variants of people the player already spared, not a new faction.

### 6.4 States on the body

Every combatant, both sides, needs these reads. Counts, not bars. Chrome is small; the body does the work.

| State | How it should read | Source |
| --- | --- | --- |
| Idle / walk / swim / wade / climb / boat | Locomotion | |
| Watch loaded | Pose + cone (see §8) | GDD §5.2 |
| Watch spent | Tick on the unit, no volume | UI §4 |
| Pinned this phase (**ducked**) | Down, not acting. Done for now | GDD §5.4, UI §4.5 |
| Pinned next phase (**ducking next**) | Visibly distinct from ducked. It owes a phase | GDD §5.4, UI §4.5 |
| Broken (enemy: flee or gun on the floor) | Gun-drop mesh, peel move | GDD §5.5, §5.11 |
| Broken (player: must move to cover/extract) | Same body, different move; not auto-flee | GDD §5.5 |
| Pinned + broken | Broken move wins — do not show a duck | GDD §5.5 |
| Hit but not dropped | Pips down by one. Any non-drop hit pins (GDD §5.4), so this state and *ducked* arrive together | UI §4.3 |
| Hit-state | Remaining hits as pips, **both sides** | UI §4.3 |
| Bleeding Out | Downed, remaining rounds as a count | UI §4, GDD §5.5 |
| Stabilised | Clock stopped | UI §4 |
| In The Call radius | Cannot break; a quiet presence, not a mood halo | GDD §8.4 |
| Hidden (smoke / dive) | Body gone from line. The unit also carries its own exposure read — **hidden / exposed / no hide** (UI §4.2) | GDD §5.9 |
| No hide (Falling, open Dry) | Standing where hiding is not available. Said in words, so it survives greyscale | UI §4.2, §14 |
| Scar | Permanent, known, on the unit — and it changes that unit's previews | GDD §8.5, UI §10 |

**Scar variants** (examples the GDD already names — not a full medical atlas):

| Scar | Visual | Mechanical reminder |
| --- | --- | --- |
| Lung damage | Breathing / chest | Reduced AP in water |
| Agoraphobia | None that looks like cowardice chrome | Breaks when a long cone sees them in the open. Telegraph rides on that unit’s previews. |
| Founder | Body scars only | Never Agoraphobia; literacy never scars off |

**Off-ramp prompts** sit on the unit, no dialogue tree (UI §4.8): let them go / take the meeting / **take the prisoner** / shoot. Take the prisoner is locked (GDD §5.11, 1.8), Vanguard-only, and appears only after research into them has begun — the first time it shows up is the player learning that research changed something, on the street, with no notification. Art: the option itself, plus a prisoner state on the body.

Shooting a downed unit needs a confirm (UI §4). That is UI chrome, plus the downed body.

### 6.5 Animation set (shared)

One library. Factions and classes pick subsets.

**Locomotion:** idle stand, idle crouch, walk Dry, walk Mud (slow, heavy), wade Falling, swim Flooded, climb ladder/hatch, enter/exit boat, dive, surface.

**Combat:** aim + fire per weapon class (pistol, long gun, shotgun, spear, melee), throw, Watch pose, pin-flinch, break/flee, gun-drop, downed idle, stabilise (medic), winch pull, place barricade, knock-on-hatch.

**Social / world:** meeting idle, hands-up, labor (pump, field) for ambient only.

Cycles must loop. Swim and walk in place for the engine to root-motion or not as the controller decides. No unique death explosions — people bleed out.

---

## 7. Vehicles

| Asset | Owner | When | Notes |
| --- | --- | --- | --- |
| **Player boat (camp)** | Player | P0 | Home until the Citadel. Extract point. MEDEVAC. Small and wet. A bad place to spend dusk with a casualty (GDD §3.1). Dressing: tents, crates, a still later. **It is a place on the tactical map** (GDD §3.1, 1.8) and Wake-Riders can take it from a roof (GDD §5.11) — so it needs a pilot socket, a taken/crewed-by-someone-else state, and a readable fuel load on it. What a taken boat costs is still tuning (GDD §10). |
| Wake-Rider boat / skiff | Wake-Riders | P2 | Boarding. Nested at roofs. |
| Wrecked boat | Help-gamble | P2 | |
| Player late vehicle | Player | P4 | Garage unlock. Dry travel. |
| Vanguard truck / APC | Vanguard | P4 | Column. First contact: “trucks stop being trucks” when the sluice fires (GDD §6.5). Needs a drowned/stuck variant. |
| Vanguard column extras | Vanguard | P4 | Enough to read as a column, not a patrol. |

Fuel is a count (GDD §4.2). A **field fuel read is locked**: GDD §4.2 (1.8) makes a leg's cost and whether the remaining fuel still reaches home knowable before committing, and UI §7 puts that read on the boat. It is a number, never a gauge bar.

---

## 8. Overlays, VFX, and combat chrome

These are the most important graphics after the street. Combat has no dice (GDD §5.4). Tension is information (UI §1). A preview that disagrees with the rule function is a bug.

Prefer **shader volumes and decals** over particle soup. No colour-per-cone rainbow (UI §4).

### 8.1 Watch cones

| Cone | At rest | Full volume when |
| --- | --- | --- |
| Friendly Watch | Outline marker on the watcher | That unit selected, or a move preview crosses it |
| Enemy Watch, Live | Full volume | Always |
| Spent Watch | Tick on the unit, no volume | Never |

Overlap: the preview **names** the count and weapon class (“2 watches: rifle, pistol”). Do not solve it with more colours.

First contact: same language, longer geometry, no faction tag (UI §4).

**Cones from watchers you cannot see** (smoke, dive) are decided (UI §4.4): the cone is always drawn, but **without its apex resolved**. The volume is there; the hand is not. So the cone shader needs a mode where the near end dissolves rather than converging on a tile — a loaded gun is capability the player has a right to, and the watcher's position is something line of sight is hiding. This matters most at first contact, where long Vanguard cones cross a street before the player can read what is throwing them.

### 8.2 Previews (P0 unless noted)

| Preview | Shows | Never |
| --- | --- | --- |
| Line | Clean or blocked. Blocker named (material, smoke, deep water, no sight). Result named: **pins / drops to Bleeding Out / kills a bleeder** (UI §4.3). *Pins* is the most common outcome in the game | Percentages |
| Material hover | Which weapon classes this cover stops | “50% cover” |
| Move path | AP cost per tile, exposure per tile, end tile, each enemy Watch crossed, the one shot that crossing draws — plus the **reserve marks**: where the shot stops being affordable, and where a Watch does (UI §4.1) | Intent arrows |
| Break telegraph | Unconditional where the rule is state (last friend down; unadapted CQB on Dry under a long cone); conditional **“if hit here, breaks”** for pinned-and-outnumbered, because its trigger is intent (UI §4.6). A scar can make clause 3 unconditional for one unit | Enemy intent, or a “will break” badge |
| Placement: barricade | Footprint + which classes it stops | P2 |
| Placement: smoke | Volume + which lines it cuts | P2 |
| Winch | Arc + where the target lands | P3 |
| Redirection ghost | Which bowls step wetter and by how much, overshoot reach, how long it hangs, what of yours is in the water. A *this is a range* variant for a half-fixed ring | UI §8. P4 |
| First Gauge | Map change: sluice slams, path opens, pump turns over, arrow on the ring reverses (GDD §8.3) plus squad react. This is the settled answer to GDD §10's question about how visible the trait is (UI §4.10) | A superhero glow that marks the founder for enemies |
| The Call | Radius. Witness pulse remaining turns. Echo Call available/used | A weather effect on the whole map |
| Exposure “who can see me” | Per unit (hidden / exposed / no hide, with the count and where from) and per tile along the move path | UI §4.2. **P0** |
| Sluice fill | Tile by tile, never fade-to-black | A cutscene |
| Undo affordance | A move is reversible until it produces information — crosses a Watch, enters a line, peels fog, or acts (UI §5). The path needs to show where that boundary falls | A general rewind, or an undo that implies a reloadable save |

### 8.3 VFX budget (closed list)

| Effect | Notes |
| --- | --- |
| Muzzle / impact per weapon class | Deterministic hit. No miss sparkle. |
| Water splash (walk, wade, dive, boat) | |
| Dive bubbles / underwater hide | Flooded only |
| Smoke volume | Line-breaker, not pretty fog |
| Oil on water + surface fire | Floating denial |
| Stun-dart shock | Ankle-deep only |
| Pump start / fail / leak | Machine as character |
| Sluice gate motion + water walk | |
| Barricade deploy | |
| Winch line | |
| Trauma kit use | Small |
| Contact start | Event-shaped; audio owns the sting (UI §0 standing brief). Picture: phases begin, cones that were not there in free-move now exist. |
| Reveal vs arrival | Someone walking into Live vision: show the walk. Vision reaching a tile where they already were: no pop. |

Do not add hit-spark rainbows, level-up bursts, loot beams, or weather that is not water.

---

## 9. Citadel and table

The table is the other half of the game from Act I (UI §8). If a table day has no decision that changes tomorrow’s map, the UI has failed. Art follows that: this is a **water-board surface**, not a civ overlay and not a spaceship geoscape.

### 9.1 Table as a place

Waking instruments is the tutorial. Act I starts almost empty: glass, a view, dark gauges (GDD §4.1, UI §8). Overlays appear bowl by bowl because the building woke, not because a menu unlocked.

| Asset | Notes |
| --- | --- |
| Dome interior, looking out | Campaign poster: look down, the polders still full (GDD §2). Look out: another wall of dry land. |
| Dead gauges / waking gauges | Per-bowl, not a tech-tree unlock flash |
| Glass, table, chairs | Empty-chair tax is on the **verbs**, not a “Founder Away” sign (UI §4, §8) |
| Instrument hall, later | Research hands |
| Cutaway of the campus as water falls | UI §9: the building and the water graph are the same picture from different ends. Same per-floor visibility mechanism as the tactical cutaway |

### 9.2 Table overlay graphics

Drawn on the same basin. Never: bars, targets, goal pips, litres, hidden math, a quest log, a second squad, auto-resolve.

| Surface | Art | Never |
| --- | --- | --- |
| Currencies | Plain counts + icons: food, fuel, scrap, people — **and the spends** surplus can go to: sit a day, stretch MEDEVAC, fund a help-gamble, dredge faster (UI §8, GDD §4.3). They sit next to the count, not in another menu | Bars, “healthy pantry” |
| Labor board | Short list of buckets: pumps / ring watch, posts, research, workshop / dredge, fields, roster | Houses, per-person clicking |
| Water graph | Per known bowl: step, grade, pump state, **upkeep (kept / thin / failing)**, feeders, which pour, whether a step is walking and roughly when (UI §8, GDD §6.1) | Litres, hidden math, a wear bar |
| Dispatch | One slot. Leads with the **bowl** — water step, grade, known hostiles, reach, the fuel and daylight the leg costs — then four from the bench and their kit (UI §8) | A second fireteam, auto-resolve |
| Mail | Rumour marks where they were heard | Quest log |
| Radar | Movement **vector** on Known-quiet, never a blip that becomes a model | Faces |
| Causeway | Grows day by day | Cutscene |
| FOBs | Same treatment as the causeway: a place, visible, a target (UI §8) | A cutscene |
| Bands | People in places: last seen, the one job held (eyes / food / bench / warn), and warmth as a **map fact** — a warm band's marks are fresh, a cold band stops reporting and its marks age out like any stale tile (UI §8, GDD §5.12) | A warmth meter on a face |
| Reach | Supply, MEDEVAC and threat as **one picture**, not three (UI §8). A bowl that crept wetter shows its road slowed and its boat late — before dispatch, which is the only moment it can change a decision | Three separate overlays |
| The morning read | What moved overnight on known bowls, what finished, what mail arrived — in the ageing-and-marks grammar (UI §8) | A newsfeed, a popup that interrupts |

**Pioneer handoff beat** (GDD §7.1, assigned to UI by name; answered in UI §11): it lands **on the hatch**. The interact that used to read *founder only* now names the Pioneer who can do it, on a real map, on a day the founder may not even be there. So the asset is not an illustration or a table moment — it is the interact prompt plus a Pioneer working a hatch. Nothing announces it, and UI §16 still forbids a pop-up. Let it land quietly.

### 9.3 Base facilities (props / interiors)

Penthouse space is agonizingly limited (GDD §4.1). Each facility is a **place you can see**, not an icon on a build queue (UI §9: no timer pips).

Work is **hands and scrap**, both counts drawn from the same pools as everything else (UI §9). A hall that is dark because nobody could spare the day must read as exactly that. No build queue bar, no timer pip, no progress percentage. Space is the constraint and it is shown as space: a building that is visibly full, not a counter reading 4/4.

| Facility | Phase | Notes |
| --- | --- | --- |
| Rudimentary med-bay | 1 | Founder recovery later |
| Ammo press | 1 | Scrap into charges |
| Barracks | 1 | Caps trainees, not people |
| Hydroponics | 1–2 | Small, bad calories, dome-only, never a food win |
| Workshop | 2 | Teaches Pioneer; cannot copy First Gauge |
| Research / instrument halls | 2 | Hands in the old halls |
| Dredge / sanitise dressing | 2 | Newly exposed floors |
| Still (boat-side, then dry-side) | 1–2 | Scrap + time → fuel |
| Vehicle garage | 3 | Dry ground |
| Heavy munitions | 3 | |
| Watchtower | 2–3 | Built on a dry rim |
| Radio mast | 2–3 | Nails mail to a place |

No house placement, no zoning art, no shop interiors as a sim (GDD §4.3).

---

## 10. UI chrome and icons

Interface stays plain English (UI §12). No lettering in button/panel textures. 9-slice panels: ornament in corners, uniform edges. State variants (normal / hover / pressed / disabled) share geometry.

### 10.1 Tactical HUD

Closed set. If a feature can only be explained with a meter, it does not ship (UI §16).

| Element | Notes |
| --- | --- |
| Selection / current unit | Not a VIP pip on the founder. The founder is found by name (UI §4.10) |
| Fireteam strip | Up to four, by name, with hit-state and AP. Where the founder is identified |
| AP pool and action costs | Pips, not a bar. Every action prices itself before commit, and the move path carries the **reserve marks** — where the shot, and where a Watch, stops being affordable (UI §4.1). P0 |
| Hit-state pips | How many hits from Bleeding Out, on every body, both sides (UI §4.3). P0 |
| Exposure read | Hidden / exposed / no hide, per unit and per path tile (UI §4.2). P0 |
| Bleeding-out rounds remaining | Both sides |
| Phase banner (yours / theirs) | |
| Floor cutaway control | |
| Zoom level (set levels, *working default* 3) | No free-zoom widget that implies a slider-as-meter |
| End-phase control | Only once contact has started. Squad mode has no End Turn (GDD §3.1). |
| Confirm: shoot a downed unit | Ugly on purpose |
| Undo affordance on a reversible move | Free / reversible / committed / confirmed (UI §5). Ironman is never implied to be otherwise |
| Off-ramp options on the unit | Four: let go / meeting / prisoner (Vanguard, post-research) / shoot. No dialogue portraits required |
| Founder abilities: First Gauge available/used; Call radius; Witness pulse turns; Echo Call available/used | UI §4 |
| MEDEVAC / extract as a **place** | Drawn where it is. Founder-down switches mission type on screen; no VIP icon from turn one. |
| Height-on-tile numbers | With a unit selected, every tile shows its level (UI §2) |

**Anti-chrome** (do not draw): hit chance, dodge, any combat percentage, an exposure score or threat heat map, morale/karma/reputation/loyalty/happiness, a band warmth meter, score, ending tracker, an ending screen that tallies the hidden counts, day count on known-quiet, dusk bar, currency bars with targets, Founder Away bar, build queue bar or construction timer pip, research completion percentage, enemy intent arrow, suggested target, a “this unit will break” badge, faction names before research, waypoint on the ridge, lore pop-up, per-citizen list. Full list: UI §16.

### 10.2 Icon set (one style contract)

Uniform stroke, padding, no mixed outline/fill. Must read at 32px.

**Currencies:** food, fuel, scrap, people.

**Labor buckets:** pumps / ring watch, posts, research, workshop / dredge, fields, roster.

**Water step:** Flooded, Falling, Mud, Dry (shape + value, not colour alone).

**Pump:** on, damaged, dead. **Upkeep:** kept, thin, failing (locked — UI §8).

**Grade:** rim, floor, sump.

**Actions:** move, shoot, Watch, interact, swim, dive, deploy cover, smoke, winch, First Gauge, Echo Call, knock, extract, dispatch, refuse sluice.

**Items:** each weapon and consumable in §6.2.

**Fog:** unknown / known-quiet / live (optional; the world should already say this).

**Exposure:** hidden / exposed / no hide. **Pinned:** ducked / ducking next.

**Mail / rumour mark.** **Band job:** eyes / food / name on the bench / warn.

**Roof state:** unseen / slept once / marked.

**Dry tile:** empty / camp / field / ruined / road / post / forward camp.

No faction crests until the name is earned. No ending medals.

### 10.3 Screens that need chrome (not world)

| Screen | When | Notes |
| --- | --- | --- |
| Front end: name, face, starting kit | Ship | Ironman default: one save the game writes (GDD §8.2, UI §5). Must not read as a class pick or a stat spread. Commit is unmistakable. |
| Dispatch + loadout | Act I (UI §8) | Bowl first — water step, grade, known hostiles, reach, fuel and daylight cost — then the four and their kit. Kit against water is the choice (GDD §5.8). Consumables are counted items, never a bar. |
| Roster | Act I (UI §10) | Names, class, kit, scars. The bench, not the town. A scar must visibly change at least one preview. |
| Research / archives | Act II (UI §11) | Two branches: foundational vs excavation (find a cache → node). A Eureka is an object carried home that opens its node at the table. No lore pop-up, no completion percentage. |
| Base / facilities | Act I onward (UI §9) | A cutaway that grows downward as the water falls. Hands + scrap as counts. No build queue bar. |
| Day-end commit | Act I | One explicit commit (UI §8). |
| Ending | P4 (UI §13) | No score screen, no tally of the hidden counts. The player looks at the basin one more time (GDD §6.6). Five outcomes are five looks at the same map: fields that hold and the observatory still a farm and a gauge; ridge as fort / town as barracks / fields thinner than the dry ground allows; a ditch still on the map; a column on the terrace; the founder gone. The art job is that a hollow win and a working win must be **distinguishable while looking at the difference**. |

---

## 11. World text

Rusted Dutch–English hybrid on **surfaces in the scene** (GDD §2, UI §12). Hover shows it larger, never translated. First Gauge bonus read is an extra English line the founder understands, never the only route.

| Mouth | Example plate | Look |
| --- | --- | --- |
| Terrace / observatory | `GAUGE 3 — DO NOT CYCLE` | More English, instrument labels, weathered campus fonts |
| Floor polder | `SLUIS 4 — NIET OPENEN / NOT OPEN` | More Dutch, municipal, ugly useful |
| Wake-Rider canal | `GEEN BRUG. ZWEM.` | Water-words, boat slang |
| Purifier wall | `HET WATER WAST` | Sermon Dutch, drowned-bible cadence |
| Vanguard map | `SECTOR 12 — GRID OBSOLETE` | Dry clipped military English, leftover NATO-Dutch |

Also: street names, levee marks, graffiti, old receipts, pump plates. These are **decals or mesh labels**, not HUD.

A *working default* plate set for P0: 8 pump/levee plates on the first bowl, terrace mouth. Enough for the founder bonus-read beat.

---

## 12. Lighting, materials, preservation gradient

Not a style guide. A closed material family so kits mix.

| Family | Use |
| --- | --- |
| Wet masonry / brick | Polder buildings |
| Rendered wall / municipal | Floor towns |
| Rusted metal | Pumps, rails, boats |
| Wet wood / pallet | Shanties, crates (pistol cover) |
| Concrete / asphalt | Streets, overpasses (rifle may punch — tag honestly) |
| Glass / instrument | Dome, gauges |
| Mold / sludge | Descent, sump |
| Pristine highland coat | Vanguard kit, late caches, rim |
| Barley / dirt | Fields |
| Water (see §5.1) | |

**Preservation gradient** (GDD §6.3): sump = rust and sludge; terrace = middling rot in shallows; toward the far highlands = un-rusted kit. Same object, three wear materials. Observatory deep guts are high building, flooded from below.

Dynamic lights: dusk looks, interior cutaway, First Gauge machine motion. Do not bake a lightmap that assumes one water height.

---

## 13. What we are not making

Closed, so this list cannot grow sideways.

- Sprite-isometric character sheets or per-water-step 2D tilesets
- Cutscene storyboards, cinematic characters, lore paintings, a required codex
- House interiors as a city builder, zoning brushes, citizen family trees
- Faction reputation badges, karma icons, ending medals, score screens
- Weather VFX that gate the ridge (rain, snow, magic fog)
- Unique hero mesh per roster member
- A second overworld globe (blockout stand-in only, not shipped feel — UI §7)
- Alpine mountains
- Founder heirloom rifle / starting armor
- Allied Vanguard army set
- Per-cone rainbow materials
- UI lettering baked into panels
- Audio (separate document)

---

## 14. Open questions that change this list

Do not author around a guess. Hold a slot if the pipeline needs one.

Nine of the v0.1 entries closed when the review landed. What remains:

| Question | Owner | Asset impact |
| --- | --- | --- |
| Art direction (medium, palette, silhouette) | Unwritten art doc | Every texture. Kits stay valid. |
| After dark: what actually changes | GDD §10 | Dusk look C, possible Wake-Rider night kit |
| Grid size / character scale | Engine + art | Every mesh |
| Peek yaw vs 90° only | UI §18 | Does not add assets; may change how diagonal levees are authored |
| Perspective vs ortho | UI §2 | Does not add assets; test on Flooded roof + Dry street |
| Day burn numbers | GDD §10 | Dusk look pacing; how many looks a leg spends |
| What a taken boat costs | GDD §10 (new in 1.8) | Whether a hijacked-boat state needs a walk-home dressing pass |
| How tightly a redirection previews in a half-fixed ring | GDD §10 (new in 1.8) | Whether the ghost-water overlay needs one range variant or several |
| Incoming camps half-Drifter or yours | GDD §10 | Ambient dressing |
| Downed bodies block line? | GDD §10 *working default* no | Cover tag on corpses |
| Orientation in floor and sump bowls, where the ridge is not visible | UI §18 | Possibly nothing — water runs downhill and levees are the grid. Do not add a compass rose to find out |

**Closed since v0.1** (do not reopen without a document change): boat as a tactical object and fuel knowability (GDD §3.1, §4.2, locked 1.8); cone from an unseen watcher — apex unresolved (UI §4.4); the founder's player-read — by name, no clothing tell (UI §4.10); pump upkeep states (UI §8); exposure, AP and hit-state reads (UI §4.1–4.3); loadout, roster, base, research and band surfaces (UI §8–§11).

---

## 15. P0 SKU list (first playable bowl)

The concrete pack a first art pass can finish. Everything else in this document waits.

**Environment**

- [ ] Terrace GridMap kit: 3 street slabs, curb, canal wall, levee straight + 2 corners + slope, 4 house shells, 2 roof decks, 4 shanty pieces, stair, ladder, hatch, 2 interior floors, pump house, sluice/gauge, pier, 4 street-furniture pieces
- [ ] Wet + dry material variants for the street and walls (same meshes)
- [ ] Flooded water shader look
- [ ] Dry water/ground look on the same plane
- [ ] Ridge far-field mesh / sky silhouette
- [ ] 8 terrace world plates
- [ ] Cover-tagged crates and planks (3)

**Characters / vehicles**

- [ ] Shared humanoid + walk, idle, swim, climb, aim-pistol, melee, Watch pose, flinch, downed
- [ ] 2 body variants, 4 faces (one reserved founder)
- [ ] Unclassed basin kit: clothes, pistol, machete
- [ ] Drifter kit: 2 cloth variants, CQB weapons (can reuse pistol/machete)
- [ ] Player boat object + dock pose

**Combat chrome**

- [ ] Selection, and a fireteam strip that names all four
- [ ] Line preview (clean / blocked), naming the blocker and one of three outcomes: pins / drops to Bleeding Out / kills
- [ ] Move path with AP per tile, exposure per tile, and the two reserve marks (shot, Watch)
- [ ] Exposure read on the unit: hidden / exposed / no hide
- [ ] Enemy Live Watch volume + spent tick, with an **unresolved-apex** variant for a hidden watcher
- [ ] Friendly Watch outline
- [ ] Pinned, two states: ducked, ducking next
- [ ] Hit-state pips, both sides
- [ ] Bleeding-out round count
- [ ] Height-on-tile numbers
- [ ] Undo affordance up to the information boundary

Unstyled placeholders are fine for all of these. Missing ones are not: a fight without AP, exposure and hit-state is a fight the player is guessing at, which is the one thing the design forbids.

**UI**

- [ ] Blank 9-slice panel
- [ ] Phase control (only once contact has started — squad mode has no End Turn)
- [ ] Confirm on downed shot
- [ ] Icons: food, fuel, scrap, people (even if unused in P0, lock the contract)
- [ ] Fuel read on the boat: the leg's cost and whether it still reaches home

**Lighting**

- [ ] Day, high light
- [ ] One Flooded roof lighting test, one Dry street lighting test

When this pack exists, the other documents can argue about peek yaw, contact, and Falling on real pictures instead of on paper.

The accessibility contract (UI §14) applies from the first texture, not as a later pass: colour reinforces and never carries, every load-bearing state is separable in greyscale and with reduced motion, and nothing that only animates is a state's sole carrier. Retrofitting that into a finished kit costs more than authoring it.
