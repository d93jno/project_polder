# Phase 11 — The Vanguard on the table: pressure, the causeway, FOBs and the push

**Status:** drafted; nothing built. Slices 11.0–11.5 below; §7 decisions open.
**Tracks:** GDD v1.18 §3.2 (acts and triggers, *highland pressure is not a meter*, the causeway as a target, a bridge over a wet floor), §6.3 (the Vanguard invasion and FOBs, a land bridge is a chain of dry-enough sectors), §6.4 (you can drown a bridge), §6.6 (when the push has broken; the civic lose; a warm band and a dislodge for the door left open); UI/UX v0.25 §6 (map facts: current on the dome, last-seen elsewhere), §8 (*enemy structures are table objects*; no threat meter).
**Depends on:** Phase 10 — a warm band's eyes are how a fact reaches a bowl the player has not walked, and a warm band is half of the door left open. Phase 9 — population and fields are what make the town loud. Phase 8 — the redirection ledger and the preview are how a stretch is drowned, and the Bitter rule is already there. Phase 7 — the basin, the day tick and the campaign. Phase 4 — the map-facts rule (§7.9): current where the dome reaches, last-seen and aged elsewhere.
**Goal:** the war arrives as things on the map that the player can read and answer with water. A loud town is watched, then surveyed, then a causeway grows from the rim toward the terrace, with FOBs at its head. None of it is a meter: the player sees marks, a route and a head, and a redirection that drowns a stretch is previewed like any other. The ending queries (the push has broken, the civic lose) exist and are tested, and nothing draws them.

---

## 0. Why this, and why not the alternatives

**The table has water, people and neighbours, and no enemy.** After plan 10 a campaign can be played from the first terrace to a drained basin and nothing comes. The GDD's Act III (the Vanguard on the floor, FOBs, a column on a bridge) is the whole second half of the arc, and its table-scale rules are all pure functions of state the campaign already has: how loud the town is, which bowls are dry enough to walk, and where the water stands. None of it needs a new fight.

**The design is written and one clause is a test.** GDD §3.2: *"The exact threshold stays hidden, but it is never silent."* The pressure is a hidden count that advances through three map facts the player can see, and a test proves that no advance happens without a fact having been drawn first: the same knowability clause plans 7 to 10 hold, pointed at the enemy.

**It is water again.** The Vanguard are masters of dry (GDD §3.2); they cannot cross the sump; a causeway is built on ground, and the player's one great verb is moving the water. So every answer to a causeway at table scale is a redirection that already exists: drown a stretch, drown a FOB's bowl. That keeps the plan inside the rules built and keeps raids (a tactical Vanguard fight on a causeway) for the plan that writes them.

**Why not the neighbours.**

- *The tactical Vanguard* (column cones, first contact on a causeway, the dislodge: a squad yields, a company waits). That is a fight-scale plan with a new faction, new maps and a conversation rule. This plan models the *force* as a count and a head on a route, not as units, and the dislodge as a fact a later plan will set; `Ending` takes both as inputs.
- *Research and the handoff* (naming the Vanguard, the archives, radio) want the pressure to exist first; radio would shorten the lag on the facts this plan makes.
- *The founder as a unit* (precise redirection, the Call) is still a separate plan. A redirection here is the sluice the player already has.
- *The base cutaway and the compound's buildings* (garages, munitions) are Phase 3 content. This plan reads only whether the inner ring is Dry.

---

## 1. Decisions taken

| Decision | Choice | Consequence |
| --- | --- | --- |
| What pressure is | **A hidden count and a stage, advanced by a rule** | `Pressure` (hidden loudness, a stage: none, watching, surveying, building). Nothing shows the count. Every stage change draws a map fact first. |
| What the player sees | **Map facts only** | Highland lights, survey marks and staged material, the causeway's route and head, FOBs. No bar, no percentage, no countdown, no threat meter (UI §8). |
| Where truth lives | **In the campaign, as plain facts with a bowl and a day** | `VanguardFact` rows; what the player last saw rides in the sightings layer plan 10 started. |
| How the player answers | **Water** | A stretch or a FOB's bowl is drowned by a redirection already built; the preview names it. No new command. |
| Endings | **Queries** | `Ending.push_has_broken`, `Ending.is_overrun`; nothing draws them (GDD §6.6: the ending is computed from hidden counts). |
| The tactical Vanguard | **Not here** | The force is a count; a dislodge is a fact a later plan sets. |

---

## 2. Layout

```
rules/vanguard/pressure.gd           Pressure: hidden loudness and the stage; the one place the stage changes
rules/vanguard/causeway.gd           Causeway: an authored route of bowls, how many stretches are built, the head
rules/vanguard/fob.gd                Fob: a bowl, the day it was placed, abandoned when its bowl is wet enough
rules/vanguard/vanguard_fact.gd      VanguardFact: kind (lights, survey mark, staged material, causeway stretch, fob), bowl, day
rules/vanguard/land_bridge.gd        LandBridge: the chains of dry-enough bowls, and whether the player has made one
rules/vanguard/vanguard_day.gd       the day tick: advances the pressure, builds a stretch, places a FOB, marches the head
rules/campaign.gd                    vanguard: Pressure, Causeway, fobs, facts; saved by the codec
rules/basin/redirection_preview.gd   names a stretch or FOB the redirection would drown
rules/basin/ending.gd                push_has_broken, is_overrun, act (query)
presentation/table_queries.gd        the marks, the head, the morning's lines, the card's lines
presentation/table_board.gd          draws marks and the route on the board, last-seen where not walked
tests/unit/vanguard/test_pressure.gd, test_causeway.gd, test_fob.gd, test_land_bridge.gd, test_endings.gd
tests/invariants/test_knowability.gd extended: no stage change without a fact drawn first
```

---

## 3. Deliverable phases

Each slice ends with `make test` green. `make shots` joins the checkpoint at 11.5.

### 11.0 — Pressure and the acts

**Ships.** `Pressure` on the campaign: a hidden loudness from the people and Dry fields of plan 9, a stage (none, watching, surveying, building), and `VanguardDay.tick` calling it from `close_day`. Stages advance one at a time, with a minimum of days between them (`BasinRules.PRESSURE_*`, working defaults), by decision 7.1. *Building* is refused while the inner ring (the terrace plus the first floor ring) is not Dry, as GDD §3.2 says; watching and surveying advance regardless. `Ending.act(campaign)` reads the act from the state: Act I, II, or III when a player land bridge exists or the stage is Building.

**Done when.** A quiet town never leaves *none*; a loud one reaches *watching* then *surveying* in order and no sooner than the minimum days; *building* waits for a Dry inner ring and then comes; the stage cannot go backwards; `Ending.act` is a pure read; and the count is never exposed by any query the table uses.

### 11.1 — Map facts, and who can see them

**Ships.** `VanguardFact` rows (highland lights at the rim, survey marks and staged material along the route, a causeway stretch, a FOB), placed by the stage that makes them and seen by the rule of plan 4 §7.9: current on a bowl the player has walked, last-seen and aged elsewhere, and visible through a warm band's eyes at the bowl it stands in (decision 7.5), through the mail lag. Nothing is drawn on a bowl that reads Unknown.

**Done when.** Each stage produces its fact before the stage changes; a fact on a walked bowl reads current; one elsewhere reads last-seen with its age; a warm EYES band reports a fact at its bowl two mornings late; and a fact never makes an unwalked bowl known.

### 11.2 — The land bridge

**Ships.** `LandBridge.chains(campaign)`: the chains of bowls from a rim bowl to the terrace whose every bowl is dry enough (decision 7.2), through the feeder links the basin already has. `LandBridge.player_made(campaign)` is true when such a chain exists that the Vanguard did not build; it starts Act III on a base still in Phase 2 (GDD §3.2, *a bridge over a wet floor*) and is the thing a column can march on.

**Done when.** A chain is found exactly when every bowl in it meets the rule; one bowl wetter breaks it; a bridge the player made starts Act III with no stage of pressure needed; and the query changes nothing.

### 11.3 — The causeway

**Ships.** Once the stage is Building, `Causeway` builds one stretch (one bowl of an authored route from the rim toward the terrace) every `BasinRules.STRETCH_DAYS` days, by decision 7.3. A stretch whose bowl stands wetter than the rule allows is *drowned*: it stalls the head and is rebuilt only when the bowl is dry enough again. Built stretches behind it stay. The head is the last built stretch, and a column on the head is a fact the table can read.

**Done when.** A stretch is built on its day and no sooner; a drowned stretch stops everything past it and the head says where it stopped; the same stretch resumes when its bowl dries; the route and the head are facts with a bowl and a day; and no number of days built is ever exposed.

### 11.4 — FOBs, the head, and the endings

**Ships.** A FOB is placed at the causeway's head every `BasinRules.FOB_EVERY_STRETCHES` stretches and at the end of any chain the Vanguard stand on (decision 7.4); it is abandoned when its bowl stands wetter than the rule allows. `Ending.push_has_broken` and `Ending.is_overrun` read the state: *quiet* is no FOB and no column head pointing at the terrace for `BasinRules.QUIET_DAYS` in a row, and *overrun* is a head that has reached the terrace or the slope. `RedirectionPreview.read` names a stretch or FOB the redirection would drown, in the same simulated runs it already does.

**Done when.** A FOB appears at its stretch and is abandoned by water, and by nothing else in this plan; the quiet-days count resets on any FOB or head and a single quiet day is not enough; burning one's own fields does not satisfy it (a test builds that case); the card names a drowned stretch exactly when the rule drowns it; and both ending queries are pure reads with no screen.

### 11.5 — The surface

**Ships.** The board draws the marks: lights and survey marks as small glyphs on the rim, the causeway as a route with its head, FOBs as places, each current on a walked bowl and last-seen and aged elsewhere (UI §8). The morning reads *a column was seen at X*, *a mark appeared at Y*, *the causeway stalled at Z* in words. The redirection card gains the lines of 11.4. No meter, no percentage, no countdown, no *threat* word (UI §8).

**Done when.** A shot shows each fact kind on the board, one of them last-seen and aged, the card naming a drowned stretch, and the morning's lines; every word on screen equals a rule's output; the `never shows` assertions are extended with *threat*, *danger* and *wave*, and hold.

---

## 4. Explicitly out of scope

- The tactical Vanguard: columns as units, the cones of a column, first contact on a causeway (GDD §6.5), raids, sieges of a FOB, the dislodge. A later plan; this one models the force as a count and a head.
- Naming the Vanguard and the philosophy that comes out of research. Research is its own plan.
- Radio and masts. The mail lag already has its flag; this plan only makes facts that flow through it.
- Phase 3's buildings (garages, munitions) and the forward camp as a player tile; the plan reads whether the inner ring is Dry and nothing more.
- Harm tallies and the population ratio of the win (GDD §6.6) beyond what the ledger already holds.
- The Purifiers' sabotage of pumps as a pressure source.

---

## 5. Verification

- `make test` green after each slice. Vanguard tests are pure unit tests under `tests/unit/vanguard/`.
- **Knowability.** A stage never changes without a fact for it having been placed first; a stretch is built on a day a forecast could have named; nothing the table can read exposes the hidden loudness.
- **Facts are not actors and not terrain.** A fact never appears over Unknown, never makes a bowl known, and is current only where the dome reaches (the map-facts test of plan 4 §7.9, now with a subject).
- **Preview equals rule.** The card names a drowned stretch or FOB exactly when playing the redirection through the horizon drowns it.
- **Isolation.** Commands return new campaigns; the forecast, the preview and the ending queries change nothing.
- **One place.** A test reads every file under `rules/` and `presentation/` and fails on an assignment to the pressure stage, the built-stretch count or a FOB list outside `rules/vanguard/` and the codec.
- **UI §8.** The existing `never shows` assertions are extended.
- **Screens.** `make shots` for the table setups, viewed by a human.

---

## 6. Sequencing note

**11.0 first and headless**: the stage and the act are the spine. **11.2 is independent of 11.1** and can go in either order, but the player-made bridge feeds 11.0's act, so its query is wired in once 11.2 lands. **11.3 needs 11.0** (it builds only when the stage is Building) **and 11.1** (its stretches are facts). **11.4 needs 11.3.** **11.5 last:** it is the only slice that touches the scene.

---

## 7. Decisions

### 7.1 — What is the pressure and how does it advance? **A hidden loudness that crosses authored thresholds, one stage at a time, with a minimum number of days between.**

- **A. A hidden loudness (the people and the Dry fields of plan 9, scaled) that must cross a threshold to leave *none*, *watching* and *surveying*; each stage change waits a minimum of days after the last and is preceded by its fact.** It is GDD §3.2's "population plus at least one field, advancing through readable bands", it is a pure function of state the campaign already holds, and the minimum is what makes it never a surprise.
- **B. A calendar: stages arrive on authored days.** Simple and testable, and the town's loudness would not matter, which the GDD says it does (turtling is a legitimate line).
- **C. A seeded roll each day.** Closest to "the highland notices", and it makes the stage unforecastable, which breaks the clause this plan is built on.

### 7.2 — What is a land bridge? **A chain of Mud-or-drier bowls from a rim bowl to the terrace.**

- **A. A chain of bowls, each at Mud or drier, linked by the basin's own feeder links, from a rim bowl to the terrace.** GDD §6.3 says "a chain of dry-enough sectors", Mud is walkable slowly (GDD §4.2 Travel), and it makes the redirection (one step wetter) the thing that breaks a bridge.
- **B. Dry only.** Cleaner, and a causeway on a Mud bowl would then be impossible, which makes the Vanguard's first stretches too hard to build while the basin is still drying.
- **C. Falling or drier.** Generous: the Vanguard would then build across ground the player still boats on, which fights the "masters of Dry" premise.

### 7.3 — How does a causeway grow, and what stops it? **An authored route, one stretch (one bowl) every few days once Building, stalled by a drowned stretch.**

- **A. An authored route of bowls from the rim toward the terrace; one stretch is built every `STRETCH_DAYS` days while the stage is Building; a stretch whose bowl stands at Falling or wetter is drowned, stalls everything past it, and is resumed only when the bowl is Mud or drier again; stretches behind it stay.** It gives the player the one move the GDD names (drown a bridge), it is a function of the water that already exists, and the head is a place, not a percentage.
- **B. A continuous progress value per day.** It reads naturally and is a bar by another name (UI §8).
- **C. The whole causeway appears at once when Building starts.** No growth to read, no raid or flood to slow, and no lead time (GDD §10 tuning).

### 7.4 — FOBs, and how the player answers them **A FOB at the head every few stretches, abandoned when its bowl is drowned; no raids in this plan.**

- **A. A FOB is placed at the head every `FOB_EVERY_STRETCHES` stretches and at the end of any chain the Vanguard stand on; it is abandoned when its bowl stands at Falling or wetter. The only answer in this plan is water.** GDD §6.4 names "a FOB you wanted" as what a redirection costs; raids need a tactical Vanguard fight, which is a later plan, and the force stays a count.
- **B. Raids now: a dispatch to a FOB's bowl runs an authored fight and a win removes it.** The better game and a new faction, a new map and a prompt: larger than this plan.
- **C. FOBs are permanent.** Then the push can never break by the quiet-days rule, and the ending would be unreachable.

### 7.5 — Do bands' eyes see the Vanguard? **Yes: a warm EYES band reports a fact at its bowl, through the mail lag.**

- **A. A warm, met band on EYES reports a Vanguard fact at the bowl it stands in as mail, two mornings late.** It gives bands a reason beyond the pump, it extends plan 10's mail without a new rule, and it answers the GDD's "a rumour arrives late until radio".
- **B. Only the dome and walking reveal facts.** Safer, and it leaves the bands' eyes with nothing to do about the enemy, which is what they were promised for.
- **C. Bands reveal facts instantly.** Radio's job, before there is radio.

### 7.6 — When has the push broken, and when is the basin lost? **Five quiet days in a row; or the head reaches the terrace.**

- **A. *Quiet* is no FOB and no column head pointing at the terrace for `QUIET_DAYS` (working default: 5) in a row, with Act III already started; *overrun* is a head that reaches the terrace or the slope.** GDD §6.6's own check, as a count a test can hold; both are queries and nothing draws them.
- **B. A single quiet day.** GDD §6.6: "one quiet day between waves is not credits".
- **C. Force spent only.** Needs raids to spend a force, which §7.4 leaves out; the quiet-days rule is the one reachable here.

---

## 8. What comes after

`plans/12` is **research and the handoff**: archives and the old language (kit, not a cutscene), naming the Vanguard, the mast that removes mail's lag, the still that turns scrap into fuel, and the first research hands. Then the tactical Vanguard (columns as units, raids on a FOB, first contact on a causeway, the dislodge), the base cutaway and the compound's buildings, the founder as a unit, the knock-and-truce meeting replacing plan 10's table-scale one, and last a 3D basin table over the same rules.
