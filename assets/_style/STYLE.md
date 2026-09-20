# Style lock (working default)

Art direction is unwritten. This folder is the **temporary contract** so P0 production does not drift. When an art-direction document exists, it wins.

## Files

| File | Role |
| --- | --- |
| `env_style_lock.png` | World look, palette, light, camera height |
| `char_style_lock.png` | Humanoid look, cloth, isolation |
| `icon_style_lock.png` | UI icon contract |

Every later image of the same kind is an `image_edit` from the matching lock, never a fresh `image_gen`.

## Look

- **Medium:** grounded cinematic 3D game art, physically based weathered surfaces. Not cel-shaded, not anime, not photoreal photograph, not heroic fantasy, not zombie-green apocalypse.
- **Light:** overcast North Sea, high and flat. No golden hour. Levee pieces that must rotate get **non-directional** lighting.
- **Palette:** wet-slate teal water, ochre brick, rust iron, dirty cream plaster, dark water. Colour reinforces; it never carries a load-bearing read.
- **Place:** mundane flooded Dutch polder. Geometric, diked, flat. One low ridge, never Alps.
- **People:** basin folk who have always lived wet. Tired working clothes. No highland kit, no crowns, no faction crests on P0.

## Isolation

Characters, held weapons, and props: flat mint `#00FFAA` background, clean silhouette, no baked ground, no cast shadow.

## Camera for concepts

Elevated three-quarter, matching the tactical rest pose. Orthographic turnarounds for modeling. Tileable albedos are top-down / flat-on, seamless, no landmark motifs.

## Accessibility

Falling vs Flooded must survive greyscale and reduced motion. Value, debris, and motion differ — not hue alone.
