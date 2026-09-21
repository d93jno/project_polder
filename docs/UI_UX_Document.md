# Project Polder — UI/UX Document

**Version:** 0.15 — matched to GDD 1.16: a floor above the water is dry ground and reads as open Dry, not as the step's water. (0.14: the extract dock rides the water on its guide piles, so the extract place is on the map at every step. 0.13: section 3 says how depth is drawn: from the rules' two depth classes, told by whether the bottom shows and where a body floats, never by a number. 0.12: housekeeping: scope cites GDD 1.15, and section 18 ticks the items the code now builds. Break's on-screen counts, bleed-out previews and First Gauge stay open. 0.11: section 2's height read records why the level digits were cut: nobody in the world reads an exact height or depth off a tile. 0.10: cut the per-tile level digits; the height read's mechanism is open. 0.9: matched to GDD 1.14: fog is drawn from what each unit and the squad know; exposure marks are located by what a unit can locate; intel from a lost squad arrives aged; the MEDEVAC preview says when no route is known; stacked Watches resolve oldest first. 0.8: matched to GDD 1.13: Watch previews show entry and qualifying-action reactions, including the fixed order for stacked cones. 0.7: wall fade (plan 3.1): tall pieces between the camera and a friendly ease to ~25 % opacity so the silhouette stays; only friendlies trigger it. 0.6: camera lock (plan 2.5): perspective 25° FOV and hold-to-peek are decided; orthographic is diagnostic only. 0.5: matched to GDD 1.9: break's terms are defined, so the telegraph draws what the rule counts (guns on the unit against friends near it, cover in reach, a loaded long cone); Agoraphobia waives kit, training and terrain; a break lands the moment it is true. 0.4: review findings applied in full. New: AP and actions, exposure, health, commit policy, the base, roster and scars, research and the handoff, bands, the ending, accessibility, teaching. Corrected: the line preview names *pins*, Pinned is two states, break clause 2 is telegraphed as a condition and not a verdict, prisoner joins the off-ramp, cones from hidden watchers resolved. 0.3: matched to GDD 1.7; Pinned cancels a live Watch; broken beats Pinned; dusk is three looks. 0.2: Model C, table surface, cone stacking, ageing fog. 0.1: first draft.)

**Versioning.** The version lives in this header, not in the filename. This file stays `UI_UX_Document.md` for the life of the project so links, citations and git history follow one path. `Game_Design_Document.md` follows the same rule.

## 0. Scope

This document owns how the game is shown and how the player touches it. The Game Design Document (GDD 1.15) owns what the rules are. When the two disagree about a rule, the GDD wins. When they disagree about how a rule is drawn, this document wins.

**Owns:** camera, views, input, previews, overlays, how water, fog, cones and time are drawn, how in-world text is rendered, what the table shows, what commits and what does not.

**Does not own:** any rule, number or ending condition. If a UI idea needs a rule to work, the rule is raised to the GDD (section 18). It is never shipped as "just UI." This document holds working defaults for those raises only so prototypes can run.

Art direction gets its own document. Audio gets its own document, with one standing brief from here: several reads in this document are **events, not pictures** — contact starting, dusk turning over, a cone going live, a bleed-out round ticking, mail arriving. Audio owns those, and this document will not pretend a picture covers them.

Citations like *GDD §5.4* point at the mechanics document. Items marked *working default* are prototype starting points. Vocabulary follows GDD 1.15: **Pinned** is the combat state, a **band** is a nomad group, a **marked roof** is a shelter, a **squad** is the units on one tactical map, and the up-to-four bodies you deploy are the **fireteam** (GDD §5.1).

## 1. Principles

Combat has no dice (GDD §5.4). Tension comes from information. The UI's first job is to make every rule readable before the player commits.

1. **Legibility replaces dice.** If the preview says a shot lands, it lands. A preview that disagrees with the rule function is a bug, not a balance issue.
2. **Show capability, not intent.** The player sees where enemies are, what they can see, and where their Watch is loaded. A drawn Watch cone is a loaded gun the enemy already paid for (GDD §5.2), not a thought. The player never sees what an enemy plans to do next.
3. **Capability points both ways.** The same rule that draws enemy cones outward draws the player's own exposure inward. Whether a body can be shot is a fact in a deterministic game, so it is a glance, not a guess (section 4.2). Intent stays hidden; facts do not.
4. **Knowable water.** Anything the GDD says the player has a right to know about water is one glance or one hover away (GDD §6.1). That right does not begin with the dome — through the Opening the world carries it (section 12). Fog may hide people. It never hides water.
5. **Readable time.** The day is part of the people/time currency (GDD §4.2). How much day is left must be readable enough to plan a dusk around. It is shown by the world, not a bar, but it is never a surprise.
6. **No meters.** No score, karma, reputation, morale or happiness bar. Currencies are counts. Hidden counts stay hidden (GDD §6.6).
7. **Capability, not a bestiary.** The UI names only what the player's people could name. The Vanguard are unnamed until research names them (GDD §6.5).
8. **Told in play.** No cutscenes, no required codex, no briefing that finishes a thought. The world is the text.
9. **Same grammar in every water step.** One set of previews and overlays from Flooded to Dry. The floor changes. The interface does not.
10. **Two cameras, one basin.** The tactical camera walks one bowl. The table sees the basin. Coming home is the switch (GDD §3.1).
11. **A loss is a decision the player made.** Ironman is the default (GDD §8.2). The interface owes the player certainty about what committed and what did not (section 5).

## 2. Tactical view

The tactical map is 3D geometry on a data grid. The camera rests at a fixed, elevated pitch where dikes and roofs read clearly. It is not sprite isometric. How it looks is the art document's job.

**Why 3D.** The water surface is a height that moves between days (GDD §6.3). Roofs, piers and diving are core grammar (GDD §3.1, §5.9). Sprite isometric would need art per water step and a painful height pipeline.

**Camera.**

- Rest pose: fixed pitch, rotation snaps in 90° steps.
- Peek yaw: hold-to-peek (MMB or Alt+drag), springs back when released. Without it, diagonal dikes and canals would be authored on grid axes because the camera punished anything else. That would be a camera constraint authoring the basin — rejected (plan 2.5).
- Zoom between set levels (*working default*: 3). No free zoom.
- Projection: low-FOV perspective (**locked**: 25° FOV). Orthographic is a diagnostic toggle only; it is not the fight or authoring default. Locked after Flooded-roof + Dry-street checks (plan 2.5 / UI §18) — roof freeboard and water height stay readable under perspective; ortho flattened them.
- Walls between the camera and a friendly unit fade to about 25 % opacity (plan 3.1). The silhouette and top edge stay as a non-colour channel (section 14). Fade is presentation-only: it never changes LOS, cover tags, or the hover word. Only friendlies trigger it; a hostile behind a wall is never revealed by fade.

**Floor cutaway.** A level selector hides everything above level N. Roof shelters, flooded interiors and overpass decks are unreadable without it.

**Height reads.** The player always knows: is that roof above the water, and can I reach it this phase? The mechanism is open, and it carries no exact numbers. Someone living in this world cannot read a height or a depth off a tile by looking at it, so the interface does not either (Principles 7 and 8: it names only what the player's people could name, and the world is the text). Per-tile level digits were built and cut on that ground (plan 3 review). They were also a lattice of identical zeros on a mostly flat bowl, and they drew over cells the squad had not seen.

**Orientation.** 90° snap plus cutaway on a bowl large enough to walk will lose people. The ridge does the work: it is a horizon object in the middle of the basin (GDD §2, section 7 here), visible from terrace bowls, and it orients without being the compass objective section 16 forbids. Where the ridge is not visible — floor and sump bowls — orientation falls back on the water itself, which always runs downhill, and on the levee lines, which are the basin's grid. No compass rose. If playtests show this failing in the sump, that is a real finding, not a reason to add a minimap.

## 3. Water on the tactical map

**One bowl, authored once, played at four steps.** Each bowl's streets, roofs and interiors are built once. The water step sets the height and state of the water surface. The player swims a street in Act I and walks it in Act II. That return is how "rooftops feel taller" (GDD §6.3) gets told in play.

| Step | Surface read | What the player must see at a glance |
| --- | --- | --- |
| Flooded | Deep, dark, moving | Which tiles are swim, which are boat, where a unit can dive out of sight |
| Falling | Chest-deep, murky, debris | No hiding. Deep enough to slow, too shallow to vanish (GDD §5.8) |
| Mud | Wet ground, standing pools | Double move cost, visible per tile in the move preview |
| Dry | Ground, puddles at most | Long, open lines. The street feels exposed before a cone is drawn |

**Falling must never look like Flooded.** Non-negotiable. The step exists to punish a player who expects to dive. If the two surfaces read alike, the rule reads as a trick. Because it is non-negotiable it cannot rest on colour or motion alone — see section 14. The exposure read (4.2) is the backstop: a unit standing in Falling says *no hide* where the same unit in Flooded says *hidden*, in words, whatever the surface looks like.

**Depth is drawn from the rules' two classes, and never printed.** Flooded is deep water: the surface stands above a head, so a body under it is hidden (GDD §5.4), and the water is close to opaque, so the street is gone. Falling is chest-deep: the surface stops short of the shoulders, a body still shows above it, and the water is murky but translucent, so the street shows through. Whether the bottom shows is a channel that is neither colour nor motion (section 14). A floor above the water is dry ground and is drawn and read as Dry, whatever the step (GDD §5.8). A body in deep water floats on the surface; that surface is the plane its tile is drawn on and the plane a click lands on. In chest-deep water it stands on the bottom. Mud is a film on the ground. A bowl's authored `water_z` is the level whose floor the water stands on, and the step sets how deep.

**Two bowls on one map.** A levee map can hold two water surfaces at two steps, one per bowl. The levee between them is the visible edge.

**Surface hazards are tile states.** Oil, surface fire and a stun-dart shock zone (GDD §5.9) are shown on tiles with the same preview grammar as material. Their extent is known before the throw. Never a VFX surprise.

**Mid-fight water.** Water does not change mid-fight except a chosen redirection (GDD §3.1). When the player opens a sluice, the change plays on the map tile by tile. Never a fade-to-black. What the sluice will *do* is previewed before it is spent, at the table and on the gauge — see section 8.

**Tile memory.** Wrecks, dropped crates, scarred walls and ruined fields persist across visits. The player should recognise a street they fought in.

## 4. Combat legibility

Every deterministic rule gets a preview. The player never learns a rule by losing to it.

### 4.1 AP and actions

One pool per person per phase, spent by move, shoot, interact, swim, deploy cover, smoke, winch, First Gauge and Echo Call (GDD §5.3). Exact digits are prototype work; the interface is not.

- **The pool is a count, not a bar.** Pips on the selected unit. Principle 6.
- **Every action prices itself before commit.** Hovering an action shows what it costs and what would be left. A shot the unit can no longer afford is drawn as unaffordable, with its cost, not hidden.
- **The reserve read is the important one.** The question a player asks more than any other is *if I move here, can I still shoot — can I still set a Watch?* The move path answers it directly: along the path, the point where the shot stops being affordable is marked, and so is the point where a Watch stops being affordable. Walk to the mark and the shot is still yours. One tile further and it is not.
- Mud doubles move cost (GDD §5.3) and the path shows it per tile, not as a total surprise at the end.

Without this there is no preview for the most common decision in the game, and Principle 1 has nothing to be true about.

### 4.2 Exposure — who can see me

Because combat is deterministic, whether a body can be shot is a fact. Facts are drawn (Principle 3).

**Per unit.** A selected unit shows its own exposure in three states:

| State | Means | Drawn |
| --- | --- | --- |
| Hidden | No enemy has a clean line. Smoke or deep water is breaking it (GDD §5.4) | On the unit, with what is hiding it |
| Exposed | At least one enemy has a clean line | On the unit, with the count and where from |
| No hide | Standing where hiding is not available — Falling, open Dry, or any floor above the water without shelter (GDD §5.8) | On the unit, in words |

**Where from is what this unit can locate.** The count is every enemy with a clean line, seen or not. The *from* marks are the ones this unit can locate: those it sees itself, and those a teammate within earshot sees (GDD §3.1). Locate is by sight and knowledge, not the unit's weapon line — a plank does not hide a shooter the squad can see over. A shooter only a distant teammate can see is counted and not located: *seen by 2, from 1*. The gap is the hidden watchers, and the interface says so in words.

**Per tile.** The move path carries the same three states tile by tile, so a player can see the step where cover ends before taking it. This is the read that makes diving (GDD §5.9) a decision rather than a hope, and it is how a player learns that Falling took the dive away without losing a unit to find out (section 15).

**No percentages, no threat heat map.** Exposure is binary per enemy and counted, never scored. "Seen by 2" is a count. "68% exposed" is a meter and does not ship.

### 4.3 Line preview (GDD §5.4)

Hovering a target shows clean line or blocked. Never a percentage.

A blocked line names the blocker: material ("crate stops pistol"), smoke, deep water, or no sight.

A clean line names the outcome, and there are three, because GDD §5.4 locks that any non-drop hit pins and there is no suppression weapon class:

| Outcome | Preview says |
| --- | --- |
| The hit does not drop them | **pins** — and, on a watcher, *pins: cancels watch* |
| The hit drops them | **drops to Bleeding Out** |
| The target is already bleeding | **kills** — and this one confirms (section 5) |

*Pins* is the most common outcome in the game. A preview that does not say it is not a preview.

**Material reads.** Hovering cover shows which weapon classes it stops. A plank that stops a pistol and not a rifle says so before anyone hides behind it.

**Health.** A body shows how many hits it has left, as pips, for both sides. Health is low by design — one clean rifle shot drops, two clean pistol hits drop (GDD §5.4) — which makes "how many hits from Bleeding Out" the number the whole fight is played on. The line preview keys off it: the same rifle reads *pins* on a fresh body and *drops to Bleeding Out* on a hurt one, and the player can see why.

**Move preview.** The path shows AP cost per tile, exposure per tile (4.2), where the unit ends, and every enemy Watch that will react to a cone entry, in its fixed resolution order (oldest Watch first).

### 4.4 Watch cones and stacking (GDD §5.2)

Cones are the most important overlay and the easiest to turn into soup.

| Cone | At rest | Full volume when |
| --- | --- | --- |
| Friendly Watch | Outline marker on the watcher | That unit is selected, or a move preview crosses it |
| Enemy Watch, Live | Full volume | Always. These are the lesson |
| Spent Watch (either side) | A tick on the unit, no volume | Never |

Where volumes overlap, the preview names the count and weapon class ("2 watches: rifle, pistol"). No colour-per-cone rainbow. The player should be reading the street, not solving an overlay.

**Reaction preview.** Before a unit commits a qualifying action inside one or more hostile cones—shoot, interact, throw, deploy utility, First Gauge, or Echo Call—the action preview names every Watch that will fire and its fixed order, oldest Watch first, which says nothing about where a hidden watcher stands. It also says when the first reaction will stop the action. Moving inside a cone, turning, setting Watch, and ending a phase do not draw a reaction. The preview uses the same words for a path crossing and an in-cone action; it never makes the player infer a different Watch rule from the icon.

**Long is a word, not a colour.** Rifle, LMG and sniper cones are long; pistol, shotgun, melee and speargun cones are short (GDD §5.5). A long cone says so in its label ("rifle, long"), because break reads it (4.6) and the player has to be able to tell which cones are the frightening ones without colour. Only a loaded Watch is a cone. A rifle with a clean line and no Watch draws nothing here, and it breaks no one.

**A cone whose watcher you cannot see.** Live cones are always drawn, including when smoke or deep water is hiding the body throwing them — but then the cone is drawn **without its apex resolved**. The volume is there; the hand is not. A loaded gun is capability and the player has a right to it (Principle 2); the watcher's tile is something line of sight is hiding and the cone must not give it away (section 6). This matters most at first contact, where GDD §6.5 puts long Vanguard cones across a street before the player can read what is throwing them.

**First contact wears no chrome.** Vanguard cones use the same cone language as a Drifter Watch, only longer than anything the player has seen. No faction tag, no unique colour, no name, until research names them (GDD §6.5). The geometry must be unmissable. The identity must not be given away.

**Counting cones is a real read.** GDD §5.4 notes that pinning does not open a street at first contact, because a column has more cones than the squad has spare lines. The player can only feel that if cones and their own available shots are both countable. They are: cones name their count, and 4.1 makes the squad's remaining actions a count too.

### 4.5 Pinned (GDD §5.4)

Pinned is one rule with two shapes, and they mean opposite things for how the player repositions. They are drawn as two states, not one.

| Hit | What it costs | Read on the unit |
| --- | --- | --- |
| In its own phase (reaction fire) | The rest of this phase | **ducked** — done for now, plan around it this phase |
| In the opponent's phase | Its next phase; a live Watch cancels at once | **ducking next** — it owes a phase, plan around it next phase |

A cancelled cone drops to the spent tick at once. One hit costs one phase at most (GDD §5.4), so a unit that is already ducked does not read as more ducked when hit again — it reads as hurt, which it is (4.3).

### 4.6 Break (GDD §5.5)

Break is deterministic, so it is telegraphed. But its clauses are not all the same kind of thing, and the interface must not pretend otherwise. GDD 1.9 defines every term the rule leans on, and each is something the player can count off the screen.

| Clause | Telegraph |
| --- | --- |
| The last friend in its squad on this map has dropped | **Unconditional.** Knowable now |
| It is pinned and outnumbered in the open | **Conditional.** *If hit here, breaks* |
| Unadapted, CQB kit, on Dry, under a long cone | **Unconditional.** Knowable now |
| Agoraphobia: under a long cone in the open | **Unconditional**, on any ground and whatever the kit or training |

**What is counted.** These are the ingredients, each one a number or a word already on screen:

| Ingredient | Read | Drawn from |
| --- | --- | --- |
| **Guns on you** | A count of standing hostiles with a clean line on the unit | The exposure count (4.2), leaving out anyone bleeding out, who cannot fire |
| **Friends near you** | A count of standing friends within 3 tiles, the unit itself included | A ring of that radius on the selected unit or a previewed tile. Downed units count for neither side |
| **Outnumbered** | Guns on you is greater than friends near you. Shown as the two numbers, "2 on you, 1 near you" | Both counts |
| **Cover in reach** | Whether any tile the unit can reach with the AP it holds is free of a clean line from every gun on it | The per-tile exposure the move preview already draws (4.2). Reachable tiles that are free of every gun are marked. In the open means none is marked, and it says so in words: *no cover in reach* |
| **Under a long cone** | Whether the tile sits inside a loaded, unspent long Watch cone of a hostile | The cone label (4.4): "rifle, long" |

Cover in reach is weapon-aware because material is the only cover (GDD §5.4). The material hover already says a plank stops a pistol and not a rifle, so the same plank marks a tile as cover against one gun and not against another. The answer also moves with the AP the unit holds, which is exactly why the reserve marks (4.1) sit on the same path: spend the AP and cover falls out of reach.

**Clause 2 is a condition, never a verdict.** It requires the unit to *be* Pinned, which requires an enemy to choose to shoot it. That choice is intent, and this document does not draw intent (Principle 2). So for a unit that is outnumbered and has no cover in reach but is not Pinned, the preview says exactly that and states the condition: *outnumbered, no cover in reach: if hit here, breaks.* For a move, the same counts are taken at the destination tile with the AP left after the move. It never promises the outcome. A "this unit will break" badge would be a lie dressed as legibility.

**It lands the moment it is true.** Break is checked after every action and at each phase start (GDD §5.5). The telegraph is therefore not a warning about next turn; it is what happens on this click. A move that ends under a loaded long cone breaks an unadapted CQB unit on Dry as it arrives. A shot that pins a unit that is already outnumbered and in the open breaks it in the same action, and a player unit that breaks mid-phase loses the rest of that phase.

**Scars change the telegraph.** Agoraphobia ("breaks when a long cone sees them in the open," GDD §8.5) is the third clause with the kit, training and terrain conditions taken off. The unit carrying it breaks under a loaded long cone with no cover in reach, on Mud or Falling as much as on Dry, for the rest of the campaign. The unit shows the scar (section 10), and its move preview says so before the click. A scar that silently changes when a unit breaks would be the exact failure Principle 1 exists to prevent.

**Broken.** A broken unit shows its broken move: the tiles that end closer to cover or to extraction, which is all GDD §5.5 allows it. A unit that is both Pinned and broken shows the broken move, not a duck. Units inside The Call's radius show that they cannot break, and that overrides every clause above, Agoraphobia included.

### 4.7 Bleeding out

A downed unit shows its remaining rounds (GDD §5.5: 3, *working default*; a round is one player phase plus one enemy phase), for either side. A stabilised unit shows that its clock has stopped. Shooting a downed unit needs a confirm. It is never a misclick.

**Awaiting MEDEVAC.** Before a Trauma Kit is committed, the preview shows the extraction route and the window it starts (GDD §8.5). The route is drawn only over ground the squad knows. If none is known, the preview says so in words, *no known route — 1 round*, and still offers the kit. It is never a hidden roll.

### 4.8 Off-ramp and knocks

When a broken enemy drops the gun or peels, the options appear on that unit (GDD §5.11):

- **let them go**
- **take the meeting**
- **take the prisoner** — Vanguard only, and only after research into them has begun
- **shoot**

The prisoner option not existing earlier is doing work: the first time it appears on a broken Vanguard soldier is the player finding out that research changed something, on the street, without a notification. That is section 11's handoff grammar applied to a different sentence.

Roof knocks and help-gambles use the same three-beat: commit, cost shown, outcome. No dialogue tree.

### 4.9 Deployables and utility

Line, material, move and watch are not the only deterministic rules. Everything that changes a line gets the same grammar (GDD §8.1):

| Tool | Preview shows |
| --- | --- |
| Pioneer barricade | Footprint, and which weapon classes it stops — the same material read as any cover |
| Smoke | The volume, and which existing lines it cuts |
| Oil, stun dart | Extent as tile states, before the throw (section 3) |
| Muckraker winch | Arc, reach, and where the target lands |

Deployed cover that the player cannot price before placing is a deterministic rule the player has to learn by losing, which section 4's first line forbids.

### 4.10 The rest of the map

**Gold rush.** A third body on the map reads as a rival party, not as more of the same enemy (GDD §6.3). The player can tell at a glance who is racing whom.

**MEDEVAC and extract.** The boat or marked roof that extracts is a place on the map, drawn where it is (GDD §3.1). The extract dock is a floating dock on guide piles: it rides the water, so it stands clear of the surface at every step and is never under it. A body on it stands on the deck and does not swim. Founder-down switches the mission type on screen (GDD §8.5). There is no VIP icon on the founder from turn one. What the extract will *cost in time* is known before deploying, not discovered while bleeding — see section 8.

**The boat.** It is a place on the map (GDD §3.1): where the squad started, where MEDEVAC leaves from, where dusk is spent if no roof is marked. Wake-Riders can take it from a roof (GDD §5.11), so it is drawn as a thing that can be lost, and the fuel aboard is readable from it.

**Founder abilities.**

- First Gauge shows available or used this fight. When it fires, the map visibly changes: a sluice slams, a path opens, a pump turns over (GDD §8.3). This is the answer to GDD §10's question about how visible the trait is: a map change the player can see, plus the squad reacting. The myth needs a picture.
- The Call is a radius around the founder. Witness pulse shows remaining turns. Echo Call shows available or used.
- **Finding your own founder.** Nothing tags the founder for the enemy, because enemies do not read the interface — GDD §5.10 is a rule about AI targeting. But the player still has to find their own body in a four-person fireteam where the founder carries any kit the roster can (GDD §8.2). The founder is identified the way every other unit is: by name, on the unit and in the fireteam strip. No special marker, no crown, no VIP icon before they are down (section 16).

**No priority markers.** The UI does not rank threats or suggest targets.

## 5. The founder, the save, and what commits

Ironman is the default and the game writes the save (GDD §8.2). With no dice anywhere in combat (GDD §5.4), a misclick is pure loss and nothing random justifies it. So the interface states plainly what is reversible.

Movement is the interesting case. Moving reveals nothing random — but it does reveal *things*, and that is the line.

| Tier | What | Rule |
| --- | --- | --- |
| Free | Camera, cutaway, hover, previews, selection, planning a path | Costs nothing, commits nothing |
| Reversible | A move, up to the point it produces information | Undoable until the unit crosses a Watch, enters an enemy line, peels fog, or acts |
| Committed | Everything past that point | Stands |
| Confirmed | Irreversible and ugly: shooting a bleeder, spending First Gauge, opening a sluice, dispatching, ending the day | One confirm, stating the cost |

The reversible tier is not generosity. In a deterministic game, a move that revealed nothing could have been planned perfectly with full information the interface already owed the player, so taking it back costs the game nothing. The moment it reveals something, it stands.

**Making the founder.** Name, face, and starting kit type (GDD §8.2). That is the whole of it — there is no secret highland loadout, no stat spread, no background that buys a bonus, because the founder's power is literacy and The Call and neither is a number (GDD §8.3). The kit choice is a kit choice, the same one the roster makes every mission, and the screen should not imply it is a class pick. The one thing worth saying plainly here, before a player has anything to lose: this is the save, and it is written once.

**The save.** One save, written by the game. The interface never implies otherwise: no save button that suggests a branch, no quickload. What the squad has learned about a bowl is part of that save and is written when a fight ends, never during one, so abandoning a fight never keeps its scouting. When a campaign ends it says so and it means it (section 13).

## 6. Fog

The three fog states (GDD §3.1) look different at every scale, tactical and table.

| State | What is drawn | What is hidden |
| --- | --- | --- |
| Unknown | Nothing | Everything |
| Known-quiet | Terrain and water step, ageing | All actors, including bands (GDD §3.1) |
| Live | The present | Only what line of sight hides |

**Staleness is ageing, not a number.** A known-quiet tile gets quieter the longer it goes unseen: dust, flatter colour, colder marks. No day count. A digit becomes a schedule the player optimises ("scout every 3 days"). Hover may say it in words, using only things the game has: "not seen since your last visit," "before the pump came back." Never weather.

**Water is current, people are not.** Once instruments wake, water steps on known bowls update from the dome (GDD §3.1). A tile can show today's water and no people at all. That split must be visible, so a street with nobody drawn never reads as a safe one.

**Reveal is not arrival.** Two different events, drawn differently:

- An enemy walks into the player's Live vision: show the walk.
- The player's vision reaches a tile where someone already was: they are simply there. No entrance, no pop. A reveal that plays like a spawn turns the finite basin into a spawn table (GDD §1).

**The squad's picture.** The map shows everything any squad member sees or has seen. What one unit knows, its own sight plus what is shared within earshot (GDD §3.1), decides that unit's reads, chiefly where its exposure marks point (4.2). Switching units never changes the map.

**Memory across visits.** A bowl the squad has walked opens Known-quiet, aged by how many visits have passed since it was last seen. Same rule as above: dust and colour, never a count. Hover may say "not seen since your last visit".

**A lost squad's intel.** When a later squad's sight reaches the tile where an earlier squad fell, what that squad had seen is simply there, already aged. It is a reveal, not an arrival: no pop.

## 7. Squad mode: walking the bowl

**Model C: bowl-scale walk, table-scale basin.** The tactical camera is the explorer. In Phase 0 the fireteam walks, swims and boats through the current bowl on the same geometry it will fight on. Neighbouring bowls are edges you travel to, not icons on a globe. After the dome, the table is the only basin-scale view. A dispatch still travels, but home to that bowl, not geoscape to instance.

An overworld with a drop is allowed as a blockout stand-in only. Shipped as the feel, it trains the Opening wrong and invites bowls authored as throwaway missions, which breaks the finite basin (GDD §1).

**Free movement until contact.** Squad mode has no End Turn (GDD §3.1). Walking is free: no AP coin, no Watch volumes, the same camera. Phases start on the same geometry when contact happens. Phased exploration is ruled out; GDD 1.7 locks this (§3.1, §9).

**Contact (GDD §3.1, working default).** Seeing is never contact. Contact starts when:

- a hostile gets a clean line on a squad body; or
- the player acts: fires, knocks a shelter, or starts a machine on a tile with a Live hostile.

Once phases start they run until extract, until no hostile holds the street, or until dusk forces a camp. A friendly roof meeting is never contact.

**Why one-sided.** If the squad's own line started fights, contact range would depend on loadout, and players would scout with pistols to see further. Spotting a camp and turning the boat around must stay a real choice (GDD §3.1).

**Degenerate reads the rule must kill:**

| Exploit | Killed by |
| --- | --- |
| Circle a hostile roof, park on every stair, then knock | Deck occupants have sight. Circling in their line is contact. You can only surround people who cannot see you |
| Peek Live, map every cone, back off, repeat | Allowed. Scouting from outside their sight is Overwatch's job. It costs the day. Starting a machine on a Live-hostile tile is contact |
| Tour three bowls in one day | Travel spends the day: boat legs cost fuel and daylight, walking costs daylight (GDD §4.2) |
| Any Live actor starts a fight | Contact is hostiles and contested machines, never faces |

Occupants are data-placed and always there. Known-quiet hides them (GDD §3.1). At the knock they were always there.

**Deck versus interior.** GDD §3.1 splits them: people on a roof deck see the approaches, people inside see nothing until the knock. So the two are different gambles and the map says which one it is *once the tile is Live* — a deck is a place with sightlines and it is drawn as one. It does not say who is on it. Surrounding an interior is legal and spends daylight; walking into a deck's line is contact before any knock.

**Fuel and the way home.** GDD §4.2 makes a leg's fuel cost and whether the remaining fuel still reaches home knowable before committing. In squad mode that lives on the boat: the leg's cost when a destination is chosen, and the plain read of whether the fireteam can get back. Running dry is a decision the player made, not a surprise on the way home.

**Dusk is three looks, not a countdown.** High light, long shadows, then dark. The looks follow the day clock, which walking, boat legs, knocks and fights all spend (GDD §3.1). Dusk is as knowable as Falling: a named state with a surface read. If a player cannot tell which look they are in before they leave the boat, the picture failed. The third look is drawn only once GDD §10 says what changes after dark. Worse fight is locked; what Wake-Riders do is not. Do not paint a rule nobody has written.

**The ridge on the horizon.** Phase 0 has no table and no instruments (GDD §4.1). The ridge is a horizon object seen from inside the bowl: a low shoulder, sometimes a glint on glass or a mast, often just a darker pile in the wet. Survivors call it a mountain. The silhouette should look like a lie people would tell.

- No marker, compass objective or nameplate. Never the word CITADEL.
- Visibility is grade and distance: clear from terrace bowls, a smudge from the floor, nothing from the sump. Weather never gates it.
- It is found by walking onto it (GDD §3.2). The rumour is a picture you could have ignored.
- Art-pass rule: bowls must not all frame the ridge dead centre, or the Opening becomes a beeline.

**Finding the dome.** Opening → Act I is the largest interface event in the game, and it has to happen without a cutscene (Principle 8). The beat is the building: walking in, climbing, and the view from the dome — GDD §2's *"Look down from the dome: the real polders, still full. That is the campaign poster."* The table is that view, from that room, and the first time the player sees it, it is a room they walked into rather than a screen that opened. Instruments are dark (GDD §4.1); what the glass shows is what eyes show. Everything the table later gains, it gains by section 8's rule: the interface grows because the building did.

## 8. Table mode

The table is the other half of the game from Act I (GDD §4.2). If a table day has no decision that changes tomorrow's map, the UI has failed filter 10. This is the minimum surface. It is not a civ overlay.

| Surface | Shows | Never shows |
| --- | --- | --- |
| Currencies | Food, fuel, scrap, people as plain counts, and what surplus can be spent on | Bars, targets, goal pips, a "healthy pantry" state |
| Labor board | A short list of job buckets with a count each: pumps / ring watch, posts, research, workshop / dredge, fields, roster (GDD §4.3) | Individual people, houses, per-person clicking |
| Water graph | Per known bowl: step, grade, pump state, pump upkeep, feeders, which feeders pour, whether the step is walking and roughly when (GDD §6.1) | Litres, hidden math, anything the player could not have known |
| Dispatch | One slot: up to four from the bench, one bowl, with that bowl's conditions and the fireteam's kit | A second fireteam, auto-resolve |
| Mail and bands | Rumours as marks on the map where they were heard, arriving late until radio; the bands themselves as people in places (GDD §5.12) | A quest log, a reputation bar |
| The morning read | What moved overnight on known bowls | A newsfeed, a popup that interrupts |
| Day end | One explicit commit | An End Turn with nothing decided |

The verbs on that surface are GDD §4.2's: dispatch, read the graph, move labor, answer mail, archives, route the wounded, refuse the sluice. The UI adds none.

**Waking instruments is the tutorial.** In Act I the table starts almost empty: glass, a view, dark gauges (GDD §4.1). Graph overlays appear bowl by bowl as instruments wake. The interface grows because the building did, not because a menu unlocked.

**Pump upkeep is on the graph.** GDD §6.1 covers wear, because a pump that fails with no warning is the design bug that clause names. Upkeep is a state, never a bar: **kept / thin / failing**. *Thin* is also the read that tells a player where a wrench will go, since Purifiers prefer a pump that is already thin (GDD §6.2).

**Surplus is spendable.** GDD §4.3 makes it spendable in every act — sit a day, stretch MEDEVAC, fund a help-gamble, dredge faster, keep a fireteam from turning back for soup. Those spends live next to the count, not in a menu somewhere else. And the tell stays visible: if food is a mountain and the labor board is thin, the player can see both at once, because they are next to each other. No prompt says it. The layout says it.

**Reach.** Supply, MEDEVAC and threat are one picture, not three (GDD §4.2, §8.5). The table draws how far the network currently reaches, and a bowl that crept wetter shows its road slowed and its boat late — before a dispatch, which is the only moment the information can change a decision.

**Dispatch is a choice about terrain, so it shows terrain.** GDD §5.8 makes kit-against-water-step the central strategic call, and GDD §8.5 names the failure: *"Sending only Overwatch onto a street you just redirected is how the hangover gets personal."* The dispatch surface therefore leads with the bowl — water step, grade, known hostiles, reach, the fuel and daylight the leg costs — and only then the four bodies and their kit. Consumables (ammo, trauma kits, smoke, barricade charges) are items crafted from scrap (GDD §4.2), counted and carried, never a bar.

**Redirection is previewed before it is spent.** The highest-consequence button in the game (GDD §6.4, §6.5, §6.6). GDD §6.1 now covers water the player is about to cause, so before committing the preview names: which bowls step wetter and by how much, whether creep can reach the next bowl, roughly how long the target hangs wet, and what of the player's own is standing in it — roads, fields, camps, posts. Precision follows the ring: a mature network previews tightly, a half-fixed outer bowl previews as a range and says it is a range. The tile-by-tile play-out (section 3) is the aftermath. This is the decision.

**The morning read.** Creep, fields, the Vanguard march and research all tick at day end (GDD §3.1). The consequences are shown the next morning on the table, in the ageing-and-marks grammar section 6 already uses: bowls that moved, work that finished, mail that arrived. Not a newsfeed, not a popup, and not a thing the player has to reconstruct by re-scanning the basin every day.

**Empty-chair tax shows on the verbs.** When the founder is deployed, the slowed things say so where they are: research not ready, radio late, dispatch thinner (GDD §4.2). No "Founder Away" bar.

**Radar is a heading, not a face.** Roof eyes and watchtowers give Live vision on their tiles. Radar draws a movement vector on Known-quiet land, never a blip that becomes a model (GDD §3.1).

**Bands are people in places.** GDD §5.12 gives each band one job (eyes / food / name on the bench / warn), caps them per ring, charges a table day to change a job, and calls warm-or-cold *"Map fact, not a bar."* So it is drawn as a map fact: a band is where it was last seen, with the job it holds, and warmth is visible in what the map is getting from it. A warm band's eyes are on the map and its marks are fresh. A band that has gone cold stops reporting and its marks age out like any other stale tile (section 6). Nobody draws a meter on a face. The player notices a part of the basin went quiet, which is what going cold actually is.

**Enemy structures are table objects.** The causeway is visible while the Vanguard build it and grows day by day (GDD §3.2). Vanguard FOBs get the same treatment (GDD §6.3): places on the map, visible, targets. They are also half of the push-has-broken check (GDD §6.6), so the player must be able to see that there are none without being told a win condition is met.

**Coming home is the switch.** Squad mode to table happens when the fireteam returns, never from a button mid-mission.

## 9. The base

The Citadel's vertical evolution (GDD §4.1) is three phases of building and had no interface before this version.

**The base is a cutaway, not a menu.** It uses the same per-floor cutaway as the tactical view (section 2), and it grows the way the building grows: the penthouse at the top, floors appearing below as the water falls and they are dredged, the compound spreading onto dry ground in Phase 3. The base view and the water graph are the same picture from different ends — the floors that opened are the bowls that dried.

| Phase | What the player sees | What they choose |
| --- | --- | --- |
| 1 — Penthouse | The dome and the upper labs. Visibly cramped | Which few facilities the space allows (GDD §4.1: med-bay versus ammo press) |
| 2 — Descent | Floors below, exposed, mouldy, closed until dredged | What to dredge and sanitise next |
| 3 — Compound | Ground outside the footprint | Garages, heavy munitions, horizontal expansion |

**Space is the constraint and it is shown as space.** GDD §4.1's "agonizingly limited" is a fact about a building, so the player sees a building that is full, not a counter that says 4/4.

**Work is hands and scrap, which are counts.** GDD §4.1 gates waking the Citadel on people as much as on scrap — *"Halls stay dark because nobody can spare the day."* So a facility under construction shows the hands and scrap assigned to it, drawn from the same pools as everything else. No build queue bar, no timer pip, no progress percentage (section 16). A hall that is dark because nobody was spared should read as exactly that, since it is the humanist throughline in a floor plan.

## 10. People: roster, kit, scars

GDD §8 makes class training plus kit, caps trainees at the barracks, and makes scars permanent known penalties that change the next mission. None of that had a surface.

**The roster is the bench, not the town.** Population is one number on the table (GDD §4.3). The roster is the subset who deploy — names, class, kit, scars. Per-citizen management is forbidden (GDD §4.3, section 16); this is the fireteam pool and it stays short.

**Where people come from is visible in it.** A name from a roof meeting, a tired rider who was let go and came back (GDD §5.11) — the roster is where the humanist throughline lands somewhere the player can see it. It is a list of people you did not finish.

**Scars ride on the unit and change its previews.** This is the part that matters. A scar is a known penalty, never a chance (GDD §8.5), so the interface treats it as a rule about that person:

| Scar | Where the player meets it again |
| --- | --- |
| Agoraphobia | That unit's break telegraph, unconditionally, under a long cone with no cover in reach, on any ground (4.6) |
| Lung damage | That unit's AP costs in water (4.1) |
| Any scar | On the unit, in the roster, and in the preview it changes |

A scar the player has to remember is a scar that will kill someone. A scar that shows up in the preview is the mission changing, which is what GDD §8.2 means by *"no winch, no swim flank, an Overwatch who will not enter an open street."*

**The founder.** Same roster, same rules, any kit (GDD §8.2). Recovery shows the days they cannot deploy and that the table verbs still work (GDD §8.5).

## 11. Research and the handoff

Two branches (GDD §7.1 foundational, §7.2 excavation), where excavation unlocks on artifacts found in the mud and not on time spent.

**A find is a thing you carry home, not a popup.** A Eureka (GDD §7.2) is an object recovered on a map. It opens its node when it reaches the table. The player learns what it opened at the table, where the decision lives — never as a lore interrupt mid-fight (section 16).

**No completion read.** Research shows what hands are on it and what is available (GDD §4.3's labor board already counts the hands). No percentage, no tech-tree progress bar, no "3 of 12 unlocked."

**The handoff landing.** GDD §7.1 asks this document for something by name:

> *"When the first Pioneer can complete a hatch the founder used to own, the UI should say so. That is the handoff landing."*

It says so on the hatch. The interact that used to read *founder only* now names the Pioneer who can do it, and the first time that happens it happens on a real hatch, on a real map, on a day the founder may not even be there. Nothing announces it. The player reaches for a machine expecting to need the one person they cannot replace, and finds that the town can do it now.

That is the whole arc of GDD §8.3 in one prompt: the workshop teaches the possible, and First Gauge stays the impossible. The interface should let it land quietly and not put a banner on it.

## 12. In-world text

The rusted Dutch–English hybrid lives on the world, never on the interface (GDD §2).

- **World:** plates, signs, levee marks, graffiti, rendered as surfaces in the scene. Hovering one shows it larger, never translated.
- **Interface:** HUD, previews, tooltips, table labels and squad lines stay plain English.
- **First Gauge bonus read:** with the founder on the map, hovering a plate can add one line the founder understands. The plate reads `POMP DOOD`; the founder's line reads "Dead. The leak is the east feeder, not this one." A bonus, never the only route to an objective.
- **No translation toggle.** An English-only player gets about 70% alone. Icons and water carry the rest.

**Plates carry the water right before the instruments do.** GDD §6.1 (1.8) says knowability does not begin with the dome: through the Opening and through Act I's dark halls, the basin itself carries step, grade, pump state and upkeep — levee marks, gauge faces, pump plates, a line someone painted on a wall. This is the one place the hybrid text is load-bearing rather than flavour, and it is why the Opening is playable without a table.

Bounded by what a plate could know: a plate reports its own machine and its own bowl, never the ring. The ring is what the dome adds, and that is why finding it is life-altering rather than convenient.

| Where | Plate |
| --- | --- |
| Terrace / observatory | `GAUGE 3 — DO NOT CYCLE` |
| Floor polder | `SLUIS 4 — NIET OPENEN / NOT OPEN` |
| Wake-Rider canal | `GEEN BRUG. ZWEM.` |
| Purifier wall | `HET WATER WAST` |
| Vanguard map | `SECTOR 12 — GRID OBSOLETE` |

## 13. The ending

GDD §6.6 computes the ending from hidden counts and is explicit: *"There is no score screen and no UI for them. The ending line is the town the player can see."*

So the last thing the player looks at is the basin, at the table, one more time. The five outcomes differ by what is *on the map*, and the map already draws all of it:

| Outcome | What the basin shows |
| --- | --- |
| Working win | Fields holding on the inner tiles. Posts staffed. The observatory still a farm and a gauge |
| Hollow win | The map looks like victory. The labor board is rifle posts. Fields thinner than the dry ground allows |
| Bitter win | People eat, and a ditch you made is still on the map |
| Civic lose | The column on the terrace, or the low ring walked back while you were at the wall |
| Personal lose | The founder did not come back |

No score, no tally, no breakdown of the counts that decided it (GDD §6.6, section 16). The player is not told which ending they got in those words. They are shown the basin they made and the ending line names the town, not the grade.

This is the hardest thing in this document to get right and it will need playtests. The failure mode to watch for is not opacity — opacity is the design (Principle 6). It is a player who cannot tell a hollow win from a working one *while looking at the difference*, which would mean the map stopped showing fields, posts and people honestly somewhere earlier.

## 14. Accessibility

Several reads in this document are load-bearing, and the obvious way to draw each one is colour. That is not good enough for reads the game is decided by.

- **Colour reinforces. It never carries.** Every state that changes a decision is separable without hue: cone volumes, the four water surfaces, fog ageing, exposure, Pinned, pump upkeep, band warmth. Shape, value, pattern, position or a word does the work first.
- **Falling versus Flooded is the test case.** Section 3 calls it non-negotiable, and the surfaces are described as "deep, dark, moving" against "chest-deep, murky, debris" — colour, value and motion, two of which a player may not have. A third channel needs neither: whether the street shows through the water, and how far up a body it comes. The exposure read (4.2) is the backstop, in words: *hidden* against *no hide*. If the surfaces alone cannot carry it for a player with reduced motion and no colour discrimination, the words still do.
- **Reduced motion.** Water motion, fog ageing and reveal animations have a reduced setting. Nothing that only animates may be the sole carrier of a state.
- **Text scale**, and no interface text below the scale floor. The plates in section 12 are world objects and scale with zoom; the hover that enlarges them is the accessibility path and also the design.
- **Audio is a real channel, not decoration.** Section 0's standing brief. Contact, dusk, a cone going live, a bleed-out tick — a player who cannot separate two surfaces may be separating two sounds.

Controller support stays out of the first camera test (section 18), but nothing here should be designed in a way that assumes a mouse forever.

## 15. Teaching

No cutscenes, no briefing, no required codex (Principle 8). The table teaches itself by waking (section 8). Combat has to teach itself too, because Principle 1 says the player never learns a rule by losing to it.

**The previews are the teacher.** Every rule in section 4 is legible before the click, which means a player learns the rule by hovering rather than by burying someone. That is the whole plan and it covers most of the game.

It does not cover everything. Two rules cannot be taught by a preview, and they need naming so they get a real answer:

- **Contact is one-sided** (section 7). Nothing on screen distinguishes "I can see them" from "they can see me" until the player has been on both sides of it once. The read that helps is exposure (4.2) — the player's own line and the enemy's are visibly different things — but the rule is still learned by living through it.
- **Falling removed the dive.** The player learns it by reaching for something that was there yesterday. The exposure read says *no hide* before the reach, and the surface is non-negotiably different (section 3), so the lesson can land as "I can see why" rather than "the game cheated." That is the whole reason section 3 calls it non-negotiable.

## 16. Anti-goals

The interface will never show:

- A hit chance, dodge chance or any percentage in combat
- An exposure score, threat heat map or safety rating
- A morale, karma, reputation, loyalty or happiness bar, including for bands
- A band warmth meter of any kind
- A score, ending tracker, or "you are on the hollow path" hint, even if endings feel opaque in playtests
- An ending screen that tallies the hidden counts
- A day count on known-quiet tiles
- A dusk bar, or a dusk that arrives unreadably
- Currency bars with targets
- A "Founder Away" bar
- A build queue bar, construction timer pip or progress percentage
- A research completion percentage or tech-tree progress read
- An enemy intent arrow or suggested target
- A "this unit will break" badge, where the rule only supports a condition
- Faction names, tags or colours the player's people could not yet know
- A reveal staged as an entrance
- A founder marker, or a VIP icon before the founder is down
- A waypoint, compass objective or nameplate on the ridge
- A codex the player must read, or a lore pop-up that interrupts play
- A per-citizen list, house or zoning view (GDD §4.3)
- A cinematic that takes the camera during a player phase

If a feature can only be explained with a meter, it does not ship.

## 17. Implementation notes (Godot 4)

Cost notes beside the design. None of these change a rule.

- **Rules run on data, scenes only draw.** A `BowlMap` resource holds cells: level, height, material, shelter flag, deck flag, occupants. Line of sight, cones, contact, break checks, exposure and move costs are pure functions over that data, unit-tested with no scene loaded.
- **Line of sight never uses physics raycasts.** A 3D grid line walk checks material against weapon class. Meshes only show the result. A raycast will one day hit a balcony rail the preview ignored, and principle 1 breaks.
- **Exposure is the same function, run backwards.** "Who can see me" is the line-of-sight function evaluated from each hostile to the unit. One implementation, two directions — if they can ever disagree, Principle 3 is a lie.
- **Free move and phases are one scene.** The switch is a state flag on the squad controller, not a second mode. The contact check is a pure function run after each free-move step.
- **Undo is a command log, not a save-state.** Section 5's reversible tier needs the move to be replayable and revocable up to its information boundary. Cheaper if actions are commands from the start than retrofitted later.
- **Occupants are data from the start.** They sit on their roof in `BowlMap` the whole campaign. Fog decides whether they are drawn. Nothing spawns at the knock. Deck vision is a flag on approach tiles, not window meshes.
- **Water is one plane per bowl.** A step-driven shader handles Flooded, Falling and Mud; the level comes from data and the step sets the depth. Bodies and clicks share one play plane, so what is drawn is what is picked. A levee map holds two planes.
- **Floors are separate nodes from day one,** so cutaway is a visibility toggle per floor — for the tactical map and for the base view (section 9), which is the same mechanism.
- **Blockout with `GridMap`;** move to `MultiMeshInstance3D` if draw calls hurt. The data grid does not change when the renderer does.
- **Camera tests are cheap.** Projection is one property on `Camera3D`. Peek yaw is a tween from the snap pose and back.
- **Engine-shaped choices, made on purpose:** 3D raises per-asset art cost and pushes art toward modular kits. The 90° snap pushes authoring toward grid axes; hold-to-peek is the chosen counter so that push stays optional, not an accident (plan 2.5).

## 18. Decisions and open questions

**Decided:**

- Tactical view is 3D on a data grid, fixed-pitch rest pose, 90° snap, set zoom levels, per-floor cutaway. The ridge and the water orient; no compass rose.
- **Projection is perspective (25° FOV).** Orthographic is diagnostic only. Locked on Flooded roof + Dry street (plan 2.5).
- **Peek is hold-to-peek** (springs back), not 90°-only — so diagonal levees stay authorable.
- Each bowl is authored once; the water step drives its water surface. Falling never reads as Flooded, and the exposure read backstops it in words.
- Every deterministic rule has a preview, including AP costs, deployable footprints and the winch. Show capability, not intent — and capability points both ways, so the player's own exposure is always drawn.
- The line preview names three outcomes: pins, drops to Bleeding Out, kills. Health is pips on every body, both sides.
- Live enemy Watch cones are always drawn; a cone whose watcher is hidden is drawn without its apex. Friendly and spent cones follow the stacking table. A pinned watcher's cone shows spent at once.
- Pinned is two reads: ducked, and ducking next.
- Break clauses 1 and 3 are telegraphed unconditionally; clause 2 is telegraphed as a condition, never a verdict, because its trigger is intent. Scars change the telegraph, and Agoraphobia waives kit, training and terrain.
- Break's ingredients are drawn as counts and words the player can read: guns on the unit against friends within 3 tiles, whether cover is in reach with the AP the unit holds, and whether a loaded long cone covers the tile. A break lands the moment it is true.
- Long is a word on the cone, not a colour.
- The off-ramp has four options; take the prisoner is Vanguard-only and appears only after research.
- Commit policy: free, reversible until a move produces information, committed, confirmed. Ironman is never implied to be otherwise.
- Founder creation is name, face and starting kit type. Nothing on that screen reads as a class pick or a stat spread.
- No faction chrome before research names a faction.
- Staleness is ageing, never a day count. Reveal is never staged as arrival.
- Squad mode is Model C. Walking is free until contact (GDD §3.1). Overworld-and-drop is a blockout stand-in only.
- Dusk is three named looks on the day clock. No bar.
- The ridge is a horizon object with no marker. The dome is found by walking into it, and the first table is the view from that room.
- Table mode carries the surface in section 8, including pump upkeep, reach, the morning read, the redirection preview, bands as map facts and FOBs as table objects.
- The base is a cutaway that grows as the building does. Work is hands and scrap; no queue bar.
- Scars ride on the unit and change its previews.
- The handoff landing is the hatch prompt naming a Pioneer.
- The ending is the basin, looked at one more time. No score, no tally.
- Colour reinforces and never carries. Reduced motion and text scale are requirements, not options.
- In-world hybrid text on the world only; no translation toggle. Plates carry the water right before instruments wake.
- Rules live in data and pure functions; line of sight never uses physics; exposure is that function run backwards.

**Paper (done in GDD 1.7, 1.8 and 1.9):**

- [x] Squad-mode walking is not phased
- [x] Contact and the knock, as working default
- [x] Bleed-out 3 rounds, as working default
- [x] Pinned cancels a live Watch; broken beats Pinned
- [x] Pump upkeep is knowable; knowability does not begin with the dome
- [x] A redirection is knowable before it is spent
- [x] Fuel legs are knowable
- [x] Take the prisoner is a named option
- [x] The boat is a place on the map
- [x] Break is defined: outnumbered, in the open, long cone and CQB kit, as working defaults

**Blocking the first playable bowl (walk plus one fight):**

- [x] AP pool, per-action costs and the reserve read. The tactical HUD does not exist without it. Built (plan 2): pips on the unit, per-tile cost, shot and Watch reserve marks on the path.
- [x] Exposure, per unit and per tile, as the line-of-sight function run backwards. Built (plan 2); locating a source moved onto knowledge in plan 4.3.
- [x] Health pips and the three-outcome line preview, keyed off them. Built (plan 2): pins / drops to Bleeding Out / kills a bleeder.
- [x] Cone apex behaviour when the watcher is hidden. Built; fog (plan 4.3) is what now drives it.
- [x] Peek yaw or 90° only. Decide before a second bowl is authored. **Hold-to-peek** (plan 2.5).
- [x] Projection test on that bowl: one Flooded roof, one long Dry line. **Perspective 25°** (plan 2.5).
- [ ] Walk pace and boat handling in one bowl, on mouse and keyboard.
- [x] Contact in code as a pure function, not a feeling. `Contact`, over `Vision` (plan 4.1). Still a working default in the GDD.
- [ ] Bleed-out clock and Pinned × Watch in code, with their previews.
- [ ] Break's ingredients as readable counts: guns on the unit, friends within 3 tiles, cover in reach, a loaded long cone. Cover in reach moves with AP, so it shares the path with the reserve marks.
- [x] Commit policy: the information boundary for undo, in code, before it is a habit. `RevealResult` (plan 4.5). The undo chrome itself is not built.
- [ ] First Gauge placeholder: a visible map change plus the squad reacting. Plate reads are a separate, cheaper item.

**Blocking the Opening end to end:**

- [ ] Day burn numbers (GDD §10).
- [ ] Dusk's three looks, readable before leaving the boat. The third waits on the after-dark rule (GDD §10).
- [ ] Plates carrying step and pump state, since the Opening has no table (GDD §6.1).
- [ ] The ridge from terrace bowls only.
- [ ] The seam to a neighbouring bowl: how travel is shown, with its fuel and daylight cost.
- [ ] Knock resolve: deck vision as a data flag on approach tiles, not window meshes.
- [ ] Finding the dome: the walk in, the climb, the view. The one beat that cannot be a cutscene.

**Act I:**

- [ ] The water graph picture on the table, with upkeep states.
- [ ] Instruments waking bowl by bowl; the empty-chair tax on the verbs.
- [ ] Dispatch and loadout, leading with the bowl's conditions.
- [ ] The morning read.
- [ ] The base cutaway, Phase 1 only.
- [ ] Roster and scars, with scars visibly changing one preview.
- [ ] First Gauge picture, second pass.

**Act II and later:**

- [ ] The redirection preview. High consequence, so it wants a real pass, not a tooltip.
- [ ] Research, the Eureka beat, and the handoff landing on a hatch.
- [ ] Bands on the table; warmth as a map fact without a meter.
- [ ] Reach: supply, MEDEVAC and threat as one picture.
- [ ] FOBs and the causeway.
- [ ] Map facts against fog: how survey marks, staged material, a building causeway and FOBs read over Unknown / Known-quiet / Live, and whether a fact's progress ages. Needs a GDD rule first (GDD §10); leaning is current where the dome reaches a known bowl, last-seen elsewhere.
- [ ] The base, Phases 2 and 3.
- [ ] The ending. Needs playtests more than it needs a spec.

**Can wait:**

- [ ] The ridge from floor and sump bowls, and whether orientation holds there without one.
- [ ] Cone stacking beyond two volumes.
- [ ] Controller support. Keep it out of the first camera test.
- [ ] Downed-body lines and bodies in deep water (GDD §10; working default: bodies do not block, deep water still hides).

**Waiting on the GDD:**

- [ ] What changes after dark.
- [ ] Day burn numbers.
- [ ] Contact and the knock locked, once they survive one bowl.
- [ ] Break's thresholds locked, once they survive one bowl: the 3-tile friend radius, which classes are long, and whether Agoraphobia keeps a Dry condition (GDD §10).
- [ ] What a taken boat costs (GDD §3.1).
- [ ] How tightly a redirection previews in a half-fixed ring (GDD §6.4) — where a range stops being useful and starts being noise.
