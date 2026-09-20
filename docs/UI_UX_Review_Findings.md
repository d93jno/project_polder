# UI/UX v0.3 — Review Findings

**Reviewed:** `UI_UX_Document.md` at v0.3, against `Game_Design_Document.md` at v1.7.
**Section references** are to v0.3's numbering, which v0.4 expanded and renumbered.
**Status:** accepted in full. Applied in UI/UX v0.4; the four raises were answered in GDD v1.8. Kept as the record of why v0.4 looks the way it does.
**Purpose:** triage list for v0.4. Every finding names the GDD rule it comes from and a proposed fix. Nothing here is a decision; §0 of the UI document still applies — a fix that needs a rule is a raise, not a ship.

## 0. What the review found

v0.3 is accurate. Every `GDD §x.y` in it resolves, and says what the citation claims. The four items it lists as "Paper (done in GDD 1.7)" really are in 1.7: contact and the knock (§3.1), Pinned duration and Watch cancellation (§5.4), broken-beats-Pinned and the 3-round bleed-out (§5.5). The §11 open-items list is genuinely synced with GDD §10, including the three raises it is waiting on.

So this is not a correction pass. It is a coverage pass.

v0.3 is deep on the things it chose — cones, fog, the four water surfaces, the ridge, contact — and silent on systems the GDD leans on. Three of those silences are internal contradictions with the document's own principles. Four block the first playable bowl and are not in §11. Two are whole pillars of the game with no interface at all. One is a requirement the GDD addresses to this document by name.

Findings are grouped by what blocks what, matching §11's convention.

| Group | What it is | Count |
| --- | --- | --- |
| A | Contradictions and corrections. Cheap. Do first | 7 |
| B | Load-bearing holes. Block the first bowl or the Opening | 12 |
| C | Missing surfaces. Screens the GDD assumes and neither document names | 10 |
| D | Craft and accessibility | 5 |
| E | Structure of v0.4 | — |

---

## A. Contradictions and corrections

### A1. The line preview's outcome vocabulary is stale

§4 says a clean line names "damage, or 'drops to Bleeding Out.'"

GDD 1.7 §5.4 locks: *any non-drop hit pins; there is no suppression weapon class.* Every shot that does not drop a unit costs it a phase of action. That is the most common outcome in the game and the preview that owns it does not say it.

**Fix.** A clean line names one of three: **pins**, **drops to Bleeding Out**, **kills a bleeder**. The third is the confirm case already in §4.

### A2. Pinned is two states drawn as one

GDD 1.7 §5.4 separates them:

| Hit | What happens | What the player needs to know |
| --- | --- | --- |
| In its own phase (reaction fire) | It stops. Rest of that phase gone. Clears at the end of it | This unit is done for now. Plan around it this phase |
| In the opponent's phase | A live Watch cancels at once and shows spent. It starts its **next** phase Pinned and spends it ducked | This unit owes a phase. Plan around it next phase |

§4 gives one state, "with when it clears." Those two read the same and mean opposite things for how you reposition.

**Fix.** Two reads on the unit: *ducked (this phase)* and *ducking next*. The cancelled cone already drops to the spent tick, which §4 has right.

### A3. Break cannot be telegraphed the way §4 claims

§4: "Break is predictable, so it is telegraphed before the click." It then names "a move that would leave a unit pinned and outnumbered in the open."

GDD §5.5's second clause requires the unit to **be** Pinned. Being Pinned requires an enemy to choose to shoot it. Principle 2 forbids showing what an enemy plans to do next. The verdict is therefore not knowable before the click. Only the ingredients are.

The other two clauses are fine — both are state, not intent:

| Clause | Telegraph |
| --- | --- |
| Last friend on this map has dropped | Unconditional. Knowable now |
| Pinned and outnumbered in the open | **Conditional only.** "If hit here, breaks" |
| Unadapted, CQB kit, Dry, under a long cone | Unconditional. Knowable now |

**Fix.** Change the telegraph from a verdict to a conditional for clause 2, and say in §4 why: the ingredients are capability, the trigger is intent, and this document does not draw intent. This is the sharpest internal contradiction in v0.3 and the fix strengthens Principle 2 rather than bending it.

### A4. Agoraphobia is a fourth break trigger with no UI

GDD §8.5 makes it permanent and per-unit: *"Agoraphobia: breaks when a long cone sees them in the open."* It is the player-side version of clause 3, and it can land on a trained veteran who would otherwise be immune.

§4's break telegraph names only the raw-recruit case. Nothing in v0.3 represents scars at all.

**Fix.** Scars ride on the unit and change that unit's previews. The Agoraphobia unit gets clause 3's unconditional telegraph for the rest of the campaign. See C3.

### A5. Prisoner is missing from the off-ramp

GDD §5.5 and §5.11: a prisoner is a broken Vanguard unit the player takes instead of shoots, once research into the Vanguard has begun. It yields one fact at the table.

§4 gives exactly three options on a broken enemy: let them go, take the meeting, shoot.

**Fix.** A fourth option that appears only on a broken Vanguard unit and only after research has begun — which is also a clean, diegetic way to show the player that research changed something. Plus where the one fact surfaces on the table. *Raise:* GDD §5.11's outcome list should name the option explicitly alongside flee / meeting / shoot.

### A6. Vocabulary drift: fireteam vs squad

GDD §5.1 calls the deployed up-to-four the **fireteam**. GDD §9 (locked 1.6) reserves **squad** for units fighting together on one tactical map. v0.3's §0 defines the word correctly — *"a **squad** is the units on one tactical map"* — then the body uses "squad" for the deployed four as well. The word "fireteam" appears nowhere in v0.3.

**Fix.** Sweep. "Squad mode" keeps its name — that is GDD §3.1's own term — but the four bodies you dispatch are the fireteam.

### A7. "Nothing marks the founder for enemies" answers the wrong question

Enemies do not read the interface. The rule is GDD §5.10, and it is a rule about AI targeting, not about drawing.

What this document owns is the **player's** read: how do you find your own founder at a glance, in a four-body fireteam where they carry any kit the roster can (GDD §8.2), without it becoming the VIP icon §9 forbids?

**Fix.** Ask and answer the real question. Keep the anti-goal.

---

## B. Load-bearing holes

These block the first playable bowl or the Opening. None of B1, B2, B5 or B12 is currently in §11.

### B1. The AP coin has no interface

GDD §5.3 is one pool per unit per phase, spent by: move, shoot, interact, swim, deploy cover, smoke, winch, First Gauge, Echo Call.

v0.3 mentions AP exactly once — "the path shows AP cost per tile" in the move preview. Missing:

- the pool itself, and what is left
- the cost of every non-move action, before commit
- the read the player makes more than any other: **if I move here, can I still shoot? Can I still set a Watch?**

Principle 1 says a preview that disagrees with the rule function is a bug. Right now there is no preview to disagree. This is the main decision surface of a game with no dice, and it blocks the first fight.

**Fix.** An AP and actions section: pool read, per-action cost shown before commit, and reserved-action feedback on the move path (walk this far and the shot is still yours; one tile further and it is not).

### B2. There is no "who can see me" read

v0.3 is thorough on capability pointed outward. It never answers the inverse: **is this unit exposed, and to whom?**

The GDD makes that question load-bearing three times over. §5.4: smoke and deep water hide a body, chest-deep Falling does not. §5.9: dive to break line of sight is a core verb. §6.3 and §8.1: the Frogman is built on it.

Because combat is deterministic, exposure is a fact, not an estimate. A fact the player cannot see is the one thing Principle 1 exists to forbid — and without it, diving and smoke are guesswork in a game that bans guesswork.

**Fix.** A per-unit exposure state (seen / hidden, and by whom), and per-tile exposure along the move path. This is the largest tactical gap in the document and it pairs with B1: the two together are the tactical HUD.

### B3. Redirection has no preview, only an animation

§3 says the sluice change plays out tile by tile, never a fade-to-black. That is the aftermath, and it is right.

The decision has nothing. GDD §6.4 makes redirection the rare card with a hangover; §6.5 makes it first contact's authored solution, with First Gauge on the gauge; §6.6 makes a still-hanging wet tile the Bitter-win trigger. Its constraints are explicitly previewable: the target walks one step wetter and stays for days, creep can overshoot into the next bowl if ignored, and the cost is shared — your own Overwatch kit and dry roads die with the APCs.

**Fix.** A redirection preview, table-side and on the tactical gauge: which bowls step wetter and by how much, overshoot risk into the next bowl, what of yours is in the water (roads, fields, camps, posts), and roughly how long it hangs. GDD §6.1's knowability clause already grants most of this. *Raise:* confirm §6.1's right-to-know extends to a redirection the player is about to cause, not only to one that happened.

### B4. Deployables and utility have no placement previews

GDD §8.1 gives the Pioneer deployable barricades (instant cover), smoke (breaks line), oil and stun-dart traps; the Muckraker a winch that pulls teammates out of danger and drags enemies out of cover.

§3 covers surface hazards as tile states with known extent — good, and the same grammar should carry the rest. But §4's "every deterministic rule gets a preview" names only line, material, move and watch. Nothing covers barricade footprint and which weapon classes it stops, smoke volume and which lines it cuts, or winch arc and where the target lands.

**Fix.** Extend §4 to placement and utility previews, reusing the material read already specified for cover.

### B5. Health has no read

GDD §5.4: health is low. A clean rifle or sniper shot drops a unit to Bleeding Out. Two clean pistol hits do the same.

So "how many hits is this body from Bleeding Out" is the core tactical number on every unit on the map, both sides — and it is what A1's line preview keys off. v0.3 specifies Bleeding Out and stabilised, and nothing above them.

**Fix.** A hit-state read on every unit. Counts, not a bar (Principle 5).

### B6. Phase 0 has no knowability surface for water

GDD §6.1 is unconditional: for a known bowl the player can **always** learn step, grade, whether the pump is holding, which neighbours feed it, which are still pouring, and — if a step is walking — that it is walking and roughly how soon. *"A bowl that changes with no way to have seen it coming is a design bug."*

v0.3 answers this entirely with the table's water graph (§7). The Opening has no table, and GDD §4.1 starts the instruments dead and wakes them piecemeal through Act I.

So a right the GDD grants without condition has nowhere to be read for the whole first act, and the gap closes only gradually across the second.

**Fix, three candidates:**

1. The world carries it before the instruments do — levee marks, gauge plates and pump plates as readable surfaces. §8 already has the vocabulary and the plate table; this would give those plates a job beyond flavour.
2. The founder carries it — GDD §8.3's veteran eyes, "a ghost of flow, a warning before a Purifier breach, a faster read on a lying levee, the tick before a step changes," is close to a written answer already.
3. Narrow the right: knowability begins when instruments wake, and Phase 0 knows only what it can see.

**This is a GDD raise either way.** (1) and (2) are presentation of an existing rule; (3) edits §6.1. Recommend (1) plus (2): it pays off §8's in-world text, gives First Gauge a Phase 0 job, and leaves §6.1 untouched.

### B7. Pump wear is invisible

GDD §6.2: *"Pumps die from wear if they are not kept. Posted hands + scrap [...] are the upkeep. Skip it long enough and the pump breaks."* Neglect is also what makes Purifier sabotage cheap — *"a watched, fed pump is boring to break."*

§7's water graph row shows "pump state." Wear is a clock, not a state, and a pump that fails with no warning is exactly the design bug §6.1 names.

**Fix.** Add upkeep to the water graph row as a named state, not a bar: **fed / thin / failing**. "Thin" is also the read that tells the player where a wrench will go.

### B8. Day end produces no report

GDD §3.1: creep, fields, the Vanguard march and research all tick at day end, never mid-fight.

§7's table gives "Day end: one explicit commit." That is the commit, not the consequences. Without a morning read the player re-scans the basin by hand every day, and §6.1's "roughly how soon" has nowhere to land.

**Fix.** A day-end result read: what moved on known bowls, what finished, what mail arrived. Built from the ageing and marks grammar §5 already establishes — not a newsfeed, and not a popup that interrupts (§9).

### B9. The dome moment is unspecified

Opening → Act I is the largest interface event in the game. The table is born; GDD §4.1 wakes the instruments piecemeal from there.

§7 has the right instinct — *"the interface grows because the building did, not because a menu unlocked"* — and §7 says coming home is the switch. But the first time, there is no home to come to. The switch has no origin beat.

**Fix.** Specify the transition. It is also the one moment where GDD §2's *"Look down from the dome: the real polders, still full. That is the campaign poster."* is a thing the player does, not a thing the design document says.

### B10. MEDEVAC reach is not drawn

GDD §4.2 and §8.5: extraction speed depends on the logistics network; a sector that crept wetter makes the boat late; delay means a worse scar, permadeath, or — for the founder — the end of the save.

§7 has the "route the wounded" verb and §4 draws the extract point on the map. Nothing shows reach **before** the fireteam deploys deep, which is the only moment the information can change a decision.

**Fix.** The MEDEVAC chain and its current reach on the table, and the target bowl's reach state at dispatch. Merges naturally with C10.

### B11. Vanguard FOBs have no representation

GDD §6.3 makes FOBs the Act III target — ignore them and organised assaults start against supply lines and the Citadel. GDD §6.6 makes "no Vanguard FOB" half of the push-has-broken check.

§7 draws the causeway as a table object that grows day by day, and stops there.

**Fix.** Same treatment as the causeway: a place on the map, visible, a target and not a cutscene.

### B12. Cones from watchers you cannot see — unresolved

§4's stacking table draws enemy Live Watch at full volume, **always**. §5 says Live shows the present, hiding "only what line of sight hides."

If a watcher is behind smoke or under deep water, its cone gives away a position line of sight is hiding. The two rules collide.

It bites hardest at first contact, where GDD §6.5 puts long Vanguard cones on a street before the player can read what is throwing them — and §4 requires that geometry to be unmissable while the identity stays hidden.

**Fix.** State the rule. Two honest options: the cone is drawn only when its watcher is visible (clean, but weakens the lesson), or the cone is always drawn with its origin left ambiguous (keeps the lesson, costs a little precision). The second fits "show capability, not intent" better — a loaded gun the enemy already paid for is capability whether or not you can see the hand.

---

## C. Missing surfaces

Screens the GDD assumes, that neither document specifies.

### C1. Pre-mission loadout

GDD §5.8 makes kit-against-water-step the central strategic choice. §8.1 spells out the failure: *"Sending only Overwatch onto a street you just redirected is how the hangover gets personal."* §7.1 and §4.2 make ammo, trauma kits, smoke and barricade charges crafted items, not a bar.

§7's dispatch row is one line: up to four from the bench, one bowl, or no dispatch. No kit. No consumables. And critically, **no water step for the target bowl** — without which the whole choice is blind, and §5.8's table is knowledge the player cannot act on.

**Fix.** A dispatch and loadout section. The bowl's water step, grade and known hostiles are the first thing on it.

### C2. Building the Citadel

GDD §4.1 is three phases of construction:

- **Phase 1:** the penthouse. *"Space is agonizingly limited. Hard choices about which basic facilities (rudimentary med-bay vs. ammo press) to build."* and limited by hands as much as scrap.
- **Phase 2:** the descent. Dredge and sanitise floors the falling water exposes, unlocking interior real estate.
- **Phase 3:** the compound. Horizontal expansion on dry ground — garages, heavy munitions.

§7's "minimum surface" has six rows and none of them is building. A pillar of the game with no interface.

It is also the one place the vertical-evolution fiction can be *shown* rather than described: the base as a cutaway that grows downward as the water falls, using the per-floor cutaway §2 already requires for tactical maps. The building and the water graph are the same picture.

**Fix.** A base section. Likely the largest single addition to v0.4.
**Anti-goal to carry with it:** no build queue bar, no timer pips. GDD §4.1 gates on hands and scrap, which are counts.

### C3. Roster, classes, kit, scars

GDD §8: class is training plus kit, not an experience tree. Barracks cap how many can train, not how many exist. GDD §8.5 makes scars permanent known penalties, never a chance roll; §8.2 says what they cost the next mission — *"no winch, no swim flank, an Overwatch who will not enter an open street."*

§7's labor board has a "roster" bucket. There is no surface for who these people are, what they can do, what they carry, or what happened to them.

**Fix.** A roster section. Scars ride on the unit and visibly change its previews (A4). GDD §5.12's "name on the bench" and §3.1's roof meetings both end here, which is the humanist throughline arriving somewhere the player can see it.
**Anti-goal:** no per-person management. GDD §4.3 forbids per-citizen clicking; the roster is the fireteam pool, not the town.

### C4. Research, archives, and a requirement addressed to this document by name

GDD §7.1, verbatim:

> *"When the first Pioneer can complete a hatch the founder used to own, the UI should say so. That is the handoff landing."*

That is the emotional turn of the entire founder arc — the institution copying the job but never the trait (§8.3) — assigned to UI, and v0.3 does not answer it.

Beyond it: two branches (§7.1 foundational, §7.2 excavation), where §7.2 unlocks on found artifacts rather than time, and the "Eureka" moment of a find opening a node.

**Fix.** A research section, and the handoff beat written as a beat. How a Eureka is communicated without becoming the lore pop-up §9 forbids is the interesting constraint.
**Anti-goal:** no research percentage, no tech-tree completion read.

### C5. Bands

GDD §5.12: one job per band (eyes / food / name on the bench / warn), a cap per ring, a job change costs a day at the table, and specific acts turn a band cold — shoot the spared, flood their canal, take the crate they needed, make their roof a gun post they did not ask for.

The GDD calls warm and cold *"Map fact, not a bar."* That hands the problem to this document and forbids the easy answer in the same sentence.

§7's mail row draws rumours as marks where they were heard. It never draws the bands.

**Fix.** Bands on the table as people in places: where they were last, what job they hold, whether they are warm. Warmth as a map fact — GDD §5.12's own "information moves with them" suggests the answer is where their eyes are, not a colour on a portrait.
**Anti-goal:** already in §9 ("no morale, karma, reputation, loyalty or happiness bar, including for bands"). Keep it and make it harder to accidentally break.

### C6. Surplus has no spend

GDD §4.3: surplus is spendable in every act — sit a day, stretch MEDEVAC, fund a help-gamble, dredge a little faster, keep a fireteam from turning back for soup. And the tell: *"If food is a mountain, the labor board is empty."*

§7 shows counts and forbids targets, correctly, and gives the player no way to spend.

**Fix.** The spend verbs live where the count lives. The mountain-of-food tell is a real read the interface can make available without a meter — the labor board is already next to it.

### C7. Front end: character creation and the save

GDD §8.2: the founder is customised by name, face and starting kit type — no secret highland loadout. Ironman is the default: one save the game writes.

Neither document describes any of it.

Ironman is also a UI contract, not just a setting. If the game writes the save and the player cannot reload around a death, then the player must never be uncertain whether an action committed. That is D2's problem, arriving from the other direction.

**Fix.** A short front-end section. It also owns GDD §8.2's "difficulty options can come later," which is a §11 item, not a v0.4 one.

### C8. The ending

GDD §6.6: the ending is computed from hidden counts. *"There is no score screen and no UI for them. The ending line is the town the player can see."*

That sentence hands this document a hard problem. v0.3's only response is the §9 anti-goal, "no score, ending tracker, or 'you are on the hollow path' hint, even if endings feel opaque in playtests" — which is the right refusal and not yet an answer.

Something has to specify what the player actually looks at when a campaign ends. GDD §6.6 all but names it: fields that hold, the observatory still a farm and a gauge, a ridge that is a fort and a town that is a barracks, a ditch still on the map. Those are all things you can look at. The difference between a working win and a hollow one is meant to be visible in the basin itself.

**Fix.** An ending section, or an explicit deferral with the constraint written down so it is not rediscovered late. Given the five outcomes differ by what is *on the map*, this may be the most solvable of the hard ones.

### C9. The boat as an object, and fuel

GDD §5.11: Wake-Riders *"stand in water; may take the boat from a roof."* GDD §4.2 makes fuel the limit on how far the one fireteam goes. GDD §3.1 makes the boat home for all of Phase 0, and a place to spend dusk.

Open questions v0.3 does not touch: is the boat a unit on the tactical map? Can it be taken or lost? And is there a fuel read in the field — can the player foresee not getting home?

Note the asymmetry: GDD §6.1 grants an explicit right to know about water and grants nothing about fuel. Running dry mid-basin is either an honest consequence or an unreadable one, and this document should pick.

**Fix.** Decide the boat's status; give fuel a stated knowability position. *Raise* if the answer is that fuel gets §6.1-style protection.

### C10. Supply and threat radius on the table

GDD §4.2: the threat radius grows as the player expands, and supply lines plus waystations are what make deep operations survivable.

Overlaps B10 heavily. Recommend one "reach" surface covering supply, MEDEVAC and threat, rather than three.

---

## D. Craft and accessibility

### D1. No accessibility position

Several load-bearing reads default to colour: cone volumes, the four water surfaces, fog ageing, band warmth if C5 is done carelessly.

§3 declares *"Falling must never look like Flooded. Non-negotiable."* A read that important needs a channel that survives colour vision deficiency and reduced motion — and the surfaces are currently described as "deep, dark, moving" versus "chest-deep, murky, debris," which is colour, value and motion, two of which can be unavailable.

**Fix.** A short accessibility section: colour reinforces and never carries; text scale; a reduced-motion position for water and ageing; and confirmation that Falling-versus-Flooded survives both. §4's "no colour-per-cone rainbow" is already this instinct — make it a rule instead of a preference.

### D2. No commit, confirm or undo policy

One confirm exists in v0.3: shooting a downed unit.

With Ironman (GDD §8.2) and full determinism (§5.4), a misclick is pure loss, and no hidden information justifies it. The interesting question is specific to this game: since movement reveals nothing random, is a move undoable **until it crosses a Watch or an enemy line** — the two points where moving actually produces information?

**Fix.** One policy covering three tiers: free (camera, hover, preview), confirmed (irreversible or ugly: shooting a bleeder, opening a sluice, ending the day), committed (everything past the information boundary).

### D3. No teaching plan for combat

Principle 7 bars cutscenes, briefings and a required codex. §7 makes waking instruments the table's tutorial, which is elegant.

Combat has no equivalent, and Principle 1 says the player never learns a rule by losing to it.

**Fix.** State the position: the previews are the teacher. Then name the rules previews cannot teach, because those are the ones that need another answer — contact being one-sided (§6), and Falling removing the dive (§3), which is a rule the player learns by reaching for something that is not there.

### D4. No orientation aid

90° snap, set zoom levels, per-floor cutaway, on a bowl large enough to walk. Nothing owns orientation.

**Fix.** §6's ridge is nearly free: a horizon object visible from terrace bowls, and GDD §2 puts it in the middle of the basin. It orients without being a compass objective, which §9 forbids. Where the ridge is not visible (floor, sump) the question stays open — and that is already a §11 item.

### D5. Audio is deferred but several reads are event-shaped

§0 gives audio its own document and touches it only where readability depends on it. Several reads are events, not pictures: contact starting, dusk turning over, a cone going live, a bleed-out round ticking, mail arriving.

**Fix.** Name them as audio's brief in §0 rather than leaving them unclaimed by both documents.

---

## E. Structure for v0.4

**§11 "Blocking the first playable bowl" should absorb B1, B2, B5 and B12.** Each blocks the first fight; none is currently listed. The existing list has camera and contact work but no tactical HUD at all.

**§11 "Waiting on the GDD" gains the raises this review generates:**

- Phase 0 water knowability (B6) — the only one that might edit an existing GDD rule
- Prisoner as a fourth off-ramp option (A5)
- Whether §6.1's right-to-know covers a redirection the player is about to cause (B3)
- Whether fuel is knowable (C9)

**§9 anti-goals gain the ones that fall out of the new surfaces:** no build queue bar, no research percentage, no band warmth meter, no ending screen. Each is a surface this review adds, so each needs its guard added at the same time.

**New sections needed:**

| Section | Closes |
| --- | --- |
| AP and actions | B1 |
| Exposure — who can see me | B2 |
| Dispatch and loadout | C1, B10, C10 |
| The base | C2 |
| Roster, kit and scars | C3, A4 |
| Research and the handoff | C4 |
| Bands | C5 |
| Commit and confirm | D2, C7 |
| Accessibility | D1 |
| The ending | C8, or a written deferral |

**Recommended order for v0.4:** A (corrections, cheap, they touch existing text) → B1, B2, B5, B12 (the tactical HUD, which is one coherent piece of work) → the rest of B → C2 and C3 (the two largest) → C4 through C10 → D.
