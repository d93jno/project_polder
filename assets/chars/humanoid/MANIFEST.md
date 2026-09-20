# P0 humanoid — concept pack

Shared skeleton concepts. Kit is clothes + sockets, not unique hero meshes. All images edit-chained from `assets/_style/char_style_lock.png`. Isolation: keyable mint void, no ground plane, no cast shadow. Style: grounded cinematic 3D game art, weathered cloth, overcast North Sea light.

**Founder:** `char_face_01.png` only. Name/face/kit is the only founder customisation — no crown, no unique coat colour, no VIP mark.

**Machete hand:** character's **right** in every view. Fingers wrap the handle.

## Side-map (unclassed turnaround)

Canonical: rusty machete gripped in the **right** hand; Dutch tricolor on the **left** upper arm; left hand in coat pocket; mustard elbow patches.

| View | File | Machete (right hand) appears | Flag (left arm) appears | Facing |
| --- | --- | --- | --- | --- |
| front | `char_kit_unclassed_front.png` | viewer's **left** | viewer's **right** sleeve | camera |
| right | `char_kit_unclassed_right.png` | **near** side, along the hip | **hidden** (far arm) | left frame edge |
| back | `char_kit_unclassed_back.png` | viewer's **right** | viewer's **left** sleeve | away |

Blind-checked against this table. Hand and flag sides match. See defects for smear leftovers.

## Files

| File | What |
| --- | --- |
| `char_body_light.png` | Light adult build, same clothes language as the lock |
| `char_body_mid.png` | Mid adult build (lock body). Same image as idle |
| `char_face_01.png` | **FOUNDER.** Wet dark chin-length hair, lock woman |
| `char_face_02.png` | Roster adult, wet dark short hair, stubble |
| `char_face_03.png` | Roster adult, wet brown hair in a low knot |
| `char_face_04.png` | Roster adult, greying buzz, sparse beard |
| `char_kit_unclassed_front.png` | Unclassed basin kit, orthographic front |
| `char_kit_unclassed_right.png` | Unclassed, strict right profile |
| `char_kit_unclassed_back.png` | Unclassed, true back |
| `char_kit_drifter_a.png` | Drifter cloth A — torn tarp poncho, rope belt, CQB machete |
| `char_kit_drifter_b.png` | Drifter cloth B — olive oilskin, life-vest scrap, CQB machete |
| `char_kit_pistol.png` | Isolated weathered compact sidearm, no hand |
| `char_kit_machete.png` | Isolated rusty machete, no hand |
| `char_pose_idle.png` | Unclassed rest (identical to `char_body_mid.png`) |
| `char_pose_watch.png` | Still Watch — pistol aimed, covering a cone |
| `char_pose_flinch.png` | Pin-flinch, ducked, machete still in the right hand |
| `char_pose_downed.png` | Bleeding out, not a ragdoll. Body in the mint void |

No files under `assets/chars/anims/` this pass.

## Defects

- **Idle/walk cycle skipped.** `image_to_video` is blocked under ZDR. FLAG: no `char_idle_####.png` frames.
- **Light vs mid build is modest.** `char_body_light.png` keeps lock clothes; the silhouette delta is a hanging left hand and a slightly opener coat, not a distinct mesh. Stronger slim attempts drifted clothes or added a ground shadow and were discarded.
- **Mint is the style-lock green (~`#5ED7A1`), not neon `#00FFAA`.** Faces were rekeyed toward the lock. Hair edges may show a thin green fringe.
- **Front/back right-sleeve smear.** A duplicate Dutch patch on the right arm was painted out on the front; a dark dirt mark remains there and shows on the back (viewer's right). Not a second flag.
- **Back hair** is tied; front/right is loose wet hair.
- **Right-profile blade** points forward along the facing line instead of hanging straight down as in front/back.
- **Watch pistol** is a 1911-ish held gun; `char_kit_pistol.png` is a different compact service silhouette. Treat the isolated mesh as the object; the pose is the Watch read.
- **Drifter A machete** is a shorter blade than the unclassed/isolated machete.
- **Downed face** reads slightly younger than the lock woman. Isolation holds (no floor).
- **Dutch tricolor** is lock clothes language on unclassed/bodies, not a founder tell and not Vanguard chrome. Drifter variants drop it.

Not in this pack (later): Frogman / Pioneer / Overwatch, Vanguard, faction crests, children, unique hero meshes, heavy body.

---

## 3D — shared humanoid (P0)

glTF 2.0 `.glb`, Y-up, metres. Built in Blender 5.2.2 (not Mixamo). Rest pose **A-pose**. Origin between the feet. Faces **+Y** in the Blender authoring file (glTF Y-up maps that to Godot **−Z** forward). Height **1.70 m** (mesh crown ≈ 1.73 m with hair).

Rebuild:

```
/snap/bin/blender --background --python assets/chars/humanoid/_build_humanoid.py
```

| File | What |
| --- | --- |
| `char_humanoid.glb` | Unclassed basin kit. Mesh + armature + sockets + all clips |
| `char_humanoid_drifter_a.glb` | Drifter cloth A — tarp poncho, hood, rope belt. Same skeleton/sockets/clips. No flag |
| `char_humanoid_drifter_b.glb` | Drifter cloth B — olive oilskin, orange vest scrap. Same skeleton/sockets/clips. No flag |
| `char_kit_machete.glb` | Held machete, origin at grip |
| `char_kit_pistol.glb` | Held compact sidearm, origin at grip |
| `../anims/char_humanoid_anims.glb` | Same skeleton + clips (AnimationLibrary-friendly duplicate) |
| `_build_humanoid.py` | Headless rebuild of unclassed |
| `_build_drifter.py` | Headless rebuild of Drifter A/B |

`char_humanoid_light.glb` is **not** shipped. The concept light/mid delta is a hanging left hand and a slightly opener coat, not a distinct mesh. FLAG.

No founder mark, no crown. Dutch tricolor on the **left** upper arm is unclassed clothes language. Drifter A/B drop the flag (salvage, not basin-folk kit). Rebuild:

```
/snap/bin/blender --background --python assets/chars/humanoid/_build_drifter.py
```

Weapons are **not** skinned onto the body. Engine instances them on `hand_r`.

### Bones (21)

Godot Humanoid names, no spaces. Hips is the armature root (no extra Root bone).

```
Hips
  Spine → Chest → Neck → Head
  Chest → LeftShoulder → LeftUpperArm → LeftLowerArm → LeftHand
  Chest → RightShoulder → RightUpperArm → RightLowerArm → RightHand
  Hips → LeftUpperLeg → LeftLowerLeg → LeftFoot → LeftToes
  Hips → RightUpperLeg → RightLowerLeg → RightFoot → RightToes
```

### Sockets (Empty extras)

Bone-parented empties. Origin is the parent bone **tail**. Extras: `polder_socket`, `polder_bone`.

| Name | Parent bone | Role |
| --- | --- | --- |
| `hand_r` | RightHand | Machete / pistol attach |
| `hand_l` | LeftHand | Off-hand |
| `back` | Chest | Slung kit |
| `head` | Head | Headwear |

Weapon convention (Blender authoring): origin at grip, barrel/blade along **+Y**, handle along **−Z**. Engine parents to `hand_r` with identity; pose orients the hand.

### Clips

Embedded in both `char_humanoid.glb` and `char_humanoid_anims.glb`. Root motion **in place**. 30 fps. Loops: last keyed pose = first.

| Name | Loop | Duration | Notes |
| --- | --- | --- | --- |
| `idle` | yes | 2.00 s | Low energy, breathing, weight shift |
| `walk` | yes | 1.07 s | Dry, in place, two steps |
| `swim` | yes | 1.33 s | Flooded, body pitched, in place |
| `climb` | yes | 1.33 s | In-place pull; engine translates up |
| `watch` | yes | 2.00 s | Still aim + tiny breathing |
| `aim_pistol` | yes | 2.00 s | Tighter / more extended than Watch |
| `melee` | **no** | 0.77 s | One-shot machete slash |
| `flinch` | **no** | 0.50 s | One-shot pin; ends ducked |
| `downed` | yes | 3.00 s | Bleeding out, not an explosion |
| `boat_sit` | yes | 2.00 s | Sit + breathe (included; cheap) |

Godot import should mark the `yes` rows as looping.

### Material

Principled blockout, lock palette: wet-slate teal coat, ochre/cream knit, khaki scarf, rust-brown boots, ochre elbow/knee patches, Dutch flag on left sleeve. No albedo bake from the concept front.

### Defects (3D)

- **Blockout, not a film sculpt.** ~700 verts / 14 material primitives. Readable from the elevated tactical camera. Hands are mittens.
- **Coat is a tapered hull**, not an open-front cloth sim. Knit placket sits on +Y. Shoulder/armpit weights can crease on extreme raises (climb, swim).
- **No light body mesh.** See FLAG above.
- **Downed** offsets Hips so the body lies on the tile; standing AABB does not apply.
- **Watch vs aim_pistol** share two-hand language; Watch is the slightly more crouched cover pose.
- Isolation mint is **not** on the 3D asset (engine composites).
- Concept PNG defects above still apply to the 2D pack; those files were not overwritten.
