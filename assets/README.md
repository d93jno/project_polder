# Assets (`res://assets/`)

Slot map for graphical production. **What to draw** lives in [`docs/Project_polder_assets.md`](../docs/Project_polder_assets.md). Drop files into the matching folder; do not invent parallel trees.

## Layout

```
assets/
  env/kits/          # GridMap mesh libraries (terrace, floor, sump, rim)
  env/hero/          # unique buildings, Citadel, ridge, causeway
  env/decals/        # ageing, scorch, graffiti, waterline dirt
  chars/humanoid/    # shared skeleton, bodies, faces, kit meshes
  chars/anims/       # AnimationLibrary on that skeleton
  vehicles/          # boat, Wake-Rider skiff, Vanguard trucks, …
  props/             # cover, pump dressing, eureka objects, deployables
  vfx/               # muzzle, splash, smoke, oil fire, machine motion
  ui/theme/          # Theme + 9-slice StyleBoxTexture (no baked lettering)
  ui/icons/          # SVG or 64/128 PNG; must read at 32px
  ui/table/          # table overlay chrome on the same basin
  worldtext/         # plate / graffiti textures (hybrid Dutch–English)
  shaders/           # water, fog, cones, skies
```

## Formats (working defaults)

| Kind | Format |
| --- | --- |
| World / character meshes | glTF 2.0 (`.glb`), Y-up, meters, origin at tile centre / footprint |
| Animations | Godot `AnimationLibrary` on the shared humanoid |
| Textures | PNG source → Godot VRAM-compressed import |
| Water / fog / cones | Godot Shader Material under `shaders/` |
| Decals | texture here; `Decal` nodes authored in scenes |
| UI chrome | Theme + 9-slice under `ui/theme/` |
| Icons | SVG or PNG under `ui/icons/` |

## Naming

`kind_kit_piece_variant` — lowercase, no spaces.

Examples: `env_levee_straight_a.glb`, `char_kit_speargun.glb`, `ui_icon_food.svg`.

## Priority

Produce in P0 → P4 order from the inventory (§3 / §15). Empty folders are intentional; fill them when art lands, do not stub placeholder meshes.
