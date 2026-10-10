# Phase 8 — Redirection at table scale: spread, hangover and the card

**Status:** 8.0–8.5 completed. Slices 8.0–8.5 below; §7 decisions locked.
**Tracks:** GDD v1.18 §6.2 (creep), §6.4 (redirection: the card, its constraints, its cost), §6.5 (the first-contact sluice), §6.6 (Bitter), §4.3 (what a dry tile is), §4.2 ("refuse the sluice"); UI/UX v0.22 §8 (redirection is previewed before it is spent), §3 (mid-fight water).
**Depends on:** Phase 7 — the basin, the day tick, the campaign, dispatch and the way home. Phase 6 — a sluice opened in a fight is the redirection; `HomeCommand` already leaves the bowl a step wetter and held (`hang_days`). Phase 5 — the preview ends in a Confirmed action.
**Goal:** the highest-consequence button in the game is a decision the player made with the consequences in front of them. A redirection spreads in a way the rules can state, leaves a hangover the campaign remembers (and that a later ending can read as Bitter), and is previewed on the table before the fireteam is sent: which bowls step wetter and by how much, whether the creep reaches the next bowl, roughly how long the target hangs wet, and what of the player's own is standing in it. A regretted sluice should be a decision the player made, not a consequence the map withheld (GDD §6.4).

---

## 0. Why this, and why not the alternatives

**Plan 7 stopped at the edge of the idea.** A sluice opened in a fight steps the bowl one wetter and holds it for five days (`HomeCommand`, `BasinBowl.hang_days`). That is the hold. It is not the redirection GDD §6.4 describes: nothing spreads to a neighbour ("creep can overshoot into the next bowl if ignored"), nothing of the player's stands anywhere to be drowned, no record is kept for the Bitter rule, and the table says nothing before the player commits. The first button in the game with a hangover has no hangover on the table yet.

**The design is written, and one clause in it is a test.** GDD §6.4: *"Knowable before it is spent … which bowls step wetter and by how much, whether the creep can reach the next bowl, roughly how long the target hangs wet, and what of theirs is standing in it."* That is a function of the basin and the labor plan, so it is a pure query under `rules/basin/` that simulates on a copy and diffs, exactly how plan 6's interact preview works at the tactical scale. The invariant is the same one: the preview is the rule run, so it cannot disagree with it.

**What exists to build on.** `BasinDay` already has creep, a leak cap and the drying rule; `Campaign` already carries the labor board and the basin; `HomeCommand` already records a redirection as a step and a hang. The new parts are small and each is testable headless: a spread rule, a per-bowl list of what stands there, a ledger, a simulation, and one surface.

**Why not the neighbours.**

- *Bands, mail, the causeway and FOBs* are map facts on the facts layer (plan 4 §7.9) and do not need a redirection to exist. They are the next plans' (§8). The causeway is the one with a stake here: GDD §6.4 says "you can drown a bridge", so the preview must be able to name a road. That needs a road flag per bowl (§7.2) and nothing more.
- *The founder* (GDD §8.2–§8.3: precise redirection wants the body on the gauge) is not modelled yet. Gating the sluice on the founder is a rules change that waits for the founder; "refuse the sluice" is built as a table choice that does not need one (§7.5).
- *Reverse a pump, cut a levee.* GDD §6.4 lists three ways to redirect. The terrace has a sluice; a pump and a levee cut are other machines on other maps. The ledger and the preview are written over "a redirection", not "a sluice", so they take those later.
- *The economy.* Fields that are drowned cost food in the GDD, and food is a plain count that does not tick yet (plan 7 decision 7.1). A ruined field is recorded and shown; what it does to rations is the day-economy plan's.

---

## 1. Decisions taken

| Decision | Choice | Consequence |
| --- | --- | --- |
| What a redirection is | **A recorded event, not just a changed step** | The campaign keeps a ledger: bowl, day, the step it came from and whether it was the authored first-contact card. Bitter reads the ledger. |
| The preview | **The rule run on a copy of the campaign, diffed** | No second implementation. `RedirectionPreview` clones the campaign, applies the redirection, ticks the basin forward under the current labor plan and reports what changed. |
| Knowable | **The preview names exactly what GDD §6.4 lists, and says when it is a range** | Precision follows the ring (§7.3); a half-fixed ring previews as a range and the card says it is a range. |
| What the table may know | **Only bowls the player knows** | The preview never names a bowl that reads *unknown*; creep into one says "into ground you have not walked". |
| Where the preview appears | **On the dispatch slot, before the fireteam is sent** | UI §8: dispatch is the only moment the information can change a decision. |
| Bitter | **A pure query, no UI** | GDD §6.6: the ending is computed from hidden counts; there is no score screen. `Ending.is_bitter(campaign)` exists so the later ending plan can call it; nothing here draws it. |

---

## 2. Layout

```
rules/basin/basin_bowl.gd            stands: what is on a dry tile of the bowl (§7.2)
rules/basin/basin_day.gd             creep across bowls (§7.1) and ruin on wet ground
rules/basin/redirection.gd           Redirection: the ledger entry; the one place a bowl is redirected
rules/campaign.gd                    redirections: Array of Redirection
rules/basin/redirection_preview.gd   the query: simulate on a copy, diff, say when it is a range
rules/basin/ending.gd                Ending.is_bitter(campaign): a query, nothing draws it
rules/commands/table/home_command.gd records the redirection through Redirection, not by hand
rules/fixtures/bowl_openings.gd      which bowls carry a sluice, and which is the first-contact card
presentation/table_queries.gd        the card's words, from the preview
presentation/table_view.gd           the dispatch slot shows the card, and a "hold the sluice" choice
tests/unit/basin/test_creep.gd, test_redirection.gd, test_redirection_preview.gd, test_ending.gd
tests/invariants/test_knowability.gd extended: a spread step is announced like any other
```

---

## 3. Deliverable phases

Each slice ends with `make test` green. `make shots` joins the checkpoint at 8.4.

### 8.0 — Creep across bowls

**Ships.** A rule for what a redirected or leaking bowl does to the bowls it feeds (decision 7.1), written into `BasinDay` beside the leak and drying rules it extends. A bowl fed by a feeder that stands two or more steps wetter than it, and whose own ring does not hold, walks one step wetter, announced like every other step (a walk with its days, landing on a later tick). Nothing spreads past one bowl a day. The late leak cap still applies to a dead pump and is not widened to the spread: a ring that holds stops creep.

**Done when.** `test_creep.gd` shows a Flooded redirected bowl pushing a Dry neighbour toward Mud over days and then stopping while its own ring holds; the same spread running on without a stop when the ring does not hold; an uphill-only rule (a bowl never pushes the bowls that feed it); and no spread into a bowl with more than half its feeders as dry as it. `tests/invariants/test_knowability.gd` is extended with redirected starts: a spread step still lands only after a day of being read as walking.

**What landed.** `BasinDay._pushed_by_feeder` and the shared wetter pressure. A bowl is pushed wetter when one of its own feeders stands `BasinRules.SPREAD_STEPS` (two) or more steps wetter than it, unless more than half its feeders are already as dry as it is. The push goes through the same branch as a dead pump's leak, so it has the same cap (Dry walks to Mud and stops while at least half the ring has a working pump) and runs on when the ring does not hold, and through the same walk machinery, so it begins walking one tick and lands a later one. It reads feeders only, so it never climbs to the bowls that feed it, and a tick reads the previous day, so it crosses one bowl a day. Tests in `tests/unit/basin/test_creep.gd`: a Flooded redirected terrace pushes the Dry polder it feeds to Mud and no further while that polder's ring holds, runs on to Falling when both its feeders' pumps are dead (one step behind the water that pushes it, since two steps is the threshold), never pushes upward, does not push the sump while two of its three feeders are as dry as it is, crosses one bowl at a time, still holds the terrace wet through it, and follows the terrace back down once the hold ends. `test_knowability.gd` gains a run from a redirected start with random postings and pumps dying, and a check that the run is not vacuous.

### 8.1 — What stands in a bowl

**Ships.** `BasinBowl.stands`: counts of what the player has on the bowl's dry tiles, from the list GDD §4.3 gives (*empty / camp / field / ruined / road / post / forward camp*) reduced to the ones a redirection can drown: `fields`, `camps`, `posts`, `ruined` and a `road` flag (§7.2). The day tick ruins a field in a bowl that has walked to Mud or wetter (GDD §4.3: "Mud kills fields") and never restores one: a ruined field is a record the player can read, not a number that heals. Counts are part of the save (`CampaignCodec`).

**Done when.** A field in a bowl that goes Mud becomes ruined, once, and stays ruined when the water recedes; posts and camps in a wet bowl are listed, not destroyed; a bowl nobody has walked reads *unknown* and its stands are not readable; the codec round-trips stands; the opening fixture has a few stands on the walked bowls so the preview has something to name.

**What landed.** `BasinBowl` gains `fields`, `camps`, `posts`, `ruined` and `road`. `BasinDay._ruin` runs after each bowl's step: a bowl that stands at Mud or wetter loses its fields to `ruined` (reported in `DayResult.fields_ruined` as `{id, count}`, which also counts as something that moved), once, and nothing ever restores them. Camps, posts and the road are listed, never destroyed. `WaterGraph.read` returns `stands` for a bowl the player has walked and nothing for one they have not. `CampaignCodec` saves the stands and the ruin lines of the morning read. Fixtures: the opening has a camp and a post on the terrace and a post on the west ridge (no fields: the walked bowls are wet), and the late ring has fields on the terrace and both polders, a camp, a post and the road through the first polder. Tests in `tests/unit/basin/test_stands.gd`: the read, an unknown bowl reading nothing, a field ruined once at Mud and again never, a ruin that does not heal when the water recedes, posts and camps and the road surviving a flood, Dry ground ruining nothing, a redirection drowning the fields of the bowl it floods and the polder it pushes while the other polder keeps its own, and both round-trips through the save. Falling is wetter than Mud, so the rule is "Mud or wetter", as the plan says.

### 8.2 — The ledger and Bitter

**Ships.** `Redirection` (the bowl, the day, the step it left, whether it was the first-contact card) and `Campaign.redirections`. `HomeCommand` records one through `Redirection.record(campaign, bowl_id, from_step, first_contact)` instead of setting the bowl's step and hang by hand, so there is a single place that redirects. `Ending.is_bitter(campaign)` is true when a redirection that is not the first-contact card still hangs: its bowl stands wetter than the step it left. A redirection stops counting when the bowl has walked back to or past that step (GDD §6.6: "still has a hanging wet tile at the end").

**Done when.** The first-contact sluice never makes a campaign Bitter; a later one does until the bowl has dried back; two redirections of one bowl count once and the second is judged against the step the first left; `HomeCommand`'s existing tests still pass through the new path; the ledger round-trips through the save.

**What landed.** `rules/basin/redirection.gd` (`Redirection`: bowl, day, `from_step`, `to_step`, `first_contact`, `hangs(basin)`, and the one place a bowl is redirected, `Redirection.record(campaign, bowl_id, to_step)`) and `rules/basin/ending.gd` (`Ending.hanging_redirections` and `Ending.is_bitter`, queries with no UI). `record` sets the bowl's step, drops any walk in progress and starts the hold, and appends the entry; if an earlier redirection of the same bowl is still hanging, the two count once and the new entry is judged against the step the first one left. A redirection hangs while its bowl stands wetter than the step it left, so it stops counting the moment the bowl is back at that step or drier (decision 7.6). `Campaign` gains `redirections` and `cards_spent`, copied in `duplicate_campaign` and saved by the codec. `HomeCommand` no longer touches a bowl: it calls `Redirection.record` when the fight left the water at a different step, and a test reads every file under `rules/` and `presentation/` and fails on any other assignment to a bowl's step or hold, comparisons excepted. **Pulled forward from 8.5:** the first-contact card. `BowlOpenings.carries_first_contact_card(bowl_id)` (the terrace) and `Campaign.cards_spent` make the first redirection recorded at such a bowl the card, and the next one not; the dispatch's hold-the-sluice choice and the card's line are still 8.5. Tests in `tests/unit/basin/test_redirection.gd`: the entry, a walk dropped, the card and the redirection after it, a bowl with no card, two redirections counting once against the first step, a new entry after a dry-back, the ledger copied and saved, no redirection meaning no Bitter, the first-contact sluice never Bitter although its ditch is on the map, a later redirection Bitter until the bowl dries back, Bitter reading only the ledger (a wet bowl nobody redirected is not the player's), and the real way home through a fight that opens the sluice.

### 8.3 — The preview

**Ships.** `RedirectionPreview.read(campaign, bowl_id, horizon_days)` returns, as data: the bowls that step wetter and by how many steps, whether the creep reaches a bowl beyond the first (and which), how many days the target hangs wet, and what stands in each affected bowl (`fields`, `camps`, `posts`, a road). It clones the campaign, applies the redirection through 8.2's single place, ticks the basin forward under the current labor plan and diffs. Only bowls the player knows are named; one they do not know contributes a line, "creep reaches ground you have not walked", and nothing else. Precision follows the ring (§7.3): each affected bowl in an instrumented ring gives an exact day count, and a half-fixed ring gives a range and sets `is_range`.

**Done when.** The preview's list equals the bowls whose steps differ after a real `HomeCommand` with the redirection and the same days run, asserted over the opening and the late-ring fixtures; it changes nothing (campaign and basin identical before and after); it never names an unknown bowl; a ring that is fully instrumented gives exact days and a half-fixed one gives a range with `is_range` set; and no function in `presentation/` computes a step, a spread or a hang.

**What landed.** `rules/basin/redirection_preview.gd`: `RedirectionPreview.read(campaign, bowl_id, horizon_days)` (fourteen by default). It copies the campaign twice, records the redirection on one through `Redirection.record`, ticks both through `Campaign.close_day` under the current labor plan and scrap, and diffs them day by day. It refuses a Flooded bowl ("the water is already as deep as it goes"); otherwise it returns `from`, `to` (one step wetter, as the sluice does), `bowls` (nearest first, then the basin's order; only bowls the player has walked), `creeps`, `beyond_first`, `unknown_reached` (a count, never a name), `horizon_days` and `is_range`. Each bowl carries its `distance` downstream of the target, `now`, `peak`, `steps_wetter` (than today, at worst), `set_back` (than the plan it would otherwise have followed), `hang_days` and `beyond_horizon`, `stands` (fields, camps, posts, road, and `fields_lost`, the ruined fields the redirection is responsible for, not the ones the world would have ruined anyway), and `hang_days_min` / `hang_days_max`. Precision follows decision 7.3: exact when every affected bowl has instruments, otherwise the target's maximum is wider by one day per affected bowl that lacks them and each such bowl is one day wider. Tests in `tests/unit/basin/test_redirection_preview.gd`: the refusal, the step it leaves, the hold at least five days, the creep reaching the polder the terrace feeds and never the other polder or the bowls that feed it, what stands (the polder's two fields lost to the redirection while the terrace's, ruined by Mud anyway, are not), it changing nothing (campaign, basin, ledger, scrap), never naming a bowl not walked, exact versus range, the horizon, the order, the labor plan being the current one, and the two checks that matter: against the real way (dispatch, a fight that opens the sluice, `HomeCommand`, then `EndDayCommand` for the rest) the bowls it lists are exactly the bowls that differ after one day, and every bowl wetter in the real run is named by the preview with the same fields lost. What the work found: a sluice from Falling spreads even with no sluice, because Falling is already two steps wetter than a Dry polder, so the redirection that matters for the card is the one that crosses that threshold (the tests start the terrace in Mud, so the sluice leaves it Falling); and, since nothing generates scrap yet, a long horizon under the opening labor plan ends with the pumps broken for lack of it, in the redirected run and the plain one alike. The tests give the camp enough scrap to keep its pumps so the water moves only for the reasons under test.

### 8.4 — The surface

**Ships.** The dispatch slot shows the card for a bowl with a sluice, before the fireteam is sent and before the sluice is ever opened: each affected bowl by name with its step now and its step after, a line for creep reaching beyond the first bowl, the hang as days (or *about N to M days*, and the word *range*), and what the player has standing in each, as counts. It reads in words and shapes with no hue (UI §14), never a bar or a percentage (UI §8), and ends in plain words, "this is what a sluice at the terrace does". The morning read gains the hangover: *held wet* lines for each redirected bowl and a spread step on the day it begins to walk.

**Done when.** A shot shows the dispatch slot with the card for the terrace; the card's bowls and counts equal the preview's; the `never shows` assertions of plan 7.4 still hold; the card never names an unknown bowl; and a human can read the card, choose to send the fireteam anyway or hold the sluice (8.5), and see the same bowls change in the morning if they open it.

**What landed.** `TableQueries.redirection_card(preview, bowl_id)` turns a `RedirectionPreview` into the card's words, and the dispatch dictionary carries it as `card` whenever the chosen bowl is one the player has walked and `BowlOpenings.carries_sluice` is true (the terrace). The lines: *if the sluice at the terrace is opened:*; *a range: not every bowl here has instruments* when it is one; per bowl, *its name, its step now to its worst step, wet for N days* (*about N to M days* for a range, *more than N days* past the horizon) and a second line of what stands in it in counts (*2 fields drowned*, camps, posts, *the road*); then *the creep stays in the bowl*, *reaches the next bowl* or *goes beyond the next bowl*; and *and reaches ground you have not walked* when it does. A Flooded bowl says its sluice *can do no more*. `table_view` draws it in a label on the board beside the sump rather than in the narrow right panel (the panel overflowed the window with it), and the dispatch slot keeps the bowl's first two lines above the bench. The morning read gains the hangover from the ledger (*held wet, N days*, then *still wetter than before the sluice* until the bowl has dried back) and the fields a flood ruined, on bowls the player has walked only. UI 0.23. Shot `table_card` sets the terrace to Mud with the pumps kept (scrap and hands set directly, because nothing generates scrap) and probes that the card is on the slot and reads as a card; the earlier table shots still pass. `tests/presentation/test_table_view.gd` gains eleven tests: the card appears before anyone is sent and only for a bowl with a sluice, it names the preview's bowls and nothing else, exact versus *a range*, an unwalked bowl never named, a Flooded bowl refusing in words, no bar or percentage or target, the morning's hold and hold-ended lines, the ruined-fields line on known bowls only, and the view naming no redirection rule. Not yet: the choice to hold the sluice (8.5), and playing the card then the morning by hand in a window.

### 8.5 — Refuse the sluice, and the first-contact card

**Ships.** "Refuse the sluice" as a dispatch choice (GDD §4.2: an active no). A checkbox on the dispatch slot that seats the fight with the bowl's sluice locked (`Machine.locked`, which `MachineCommand` refuses with a reason), and a plain line on the card saying so. The first fight at a bowl that carries the authored first-contact card is flagged on the bowl (`BowlOpenings`), so the redirection it records is `first_contact` and never makes the campaign Bitter (GDD §6.5). Everything else about the first-contact sluice is unchanged.

**Done when.** A dispatch with the sluice held produces a fight in which `MachineCommand` refuses to open it with a reason, and the preview card for that dispatch says there is no redirection; the first redirection at the terrace is recorded as first contact and the next is not; and the held choice is not saved (it belongs to a dispatch, which is not).

**What landed.** `Machine.locked`, copied by `duplicate_machine`; `MachineCommand.validate` refuses a locked machine with *the sluice is held shut*. `DispatchCommand` takes `hold_sluice` and records it on the deployment; `TableDispatch.build_fight(campaign, bowl, ids, hold_sluice)` locks every sluice in the seated fight, and `game.gd` passes the deployment's flag. The dispatch slot shows a *hold the sluice* checkbox only for a bowl that carries a sluice and resets it when the bowl changes; while held the card reads *the sluice at <bowl> is held shut: nothing is redirected*. The hold is not saved (a loaded campaign has no deployment). The first-contact flag had already landed in 8.2. Tests: a locked sluice refused with its reason, only sluices locked, a held fight brought home redirecting nothing, the card line, checkbox scope and reset, and the hold not surviving a save.

---

## 4. Explicitly out of scope

- Gating the sluice on the founder (GDD §8.2, §8.3). A later plan, once the founder is a unit on the table.
- Reversing a pump and cutting a levee as redirections, and a second water surface on one map (UI §3). The ledger takes them; nothing here builds them.
- Food, rations and what a ruined field costs. Ruined fields are recorded and shown, and the day-economy plan makes them matter.
- Roads as a graph, the causeway as a structure, vehicles. A bowl has a road flag so the preview can say "a road is drowned".
- Bands and mail reacting to a redirection (GDD §6.4: Drifters and Wake-Riders treat the new canal as home; Purifiers notice a sluice that moved), Vanguard APCs dying in it, and the Overwatch kit drowned with it. Those are consequences on other layers.
- The ending itself, its thresholds and its screens. `Ending.is_bitter` is a query; the ending is computed from hidden counts later (GDD §6.6).
- Rendering the spread on the tactical map. The tile-by-tile play-out in a fight is plan 6.4's, and the basin-scale picture is the board's.

---

## 5. Verification

1. `make test` green.
2. **Knowable.** A spread step is announced like any other: over a long run of redirections and labor plans, no step lands unless the day before read as walking that way.
3. **Preview equals rule.** The preview's affected bowls equal the bowls that differ after the real command and the same days, over both fixtures; it names no bowl the player has not walked.
4. **One place redirects.** `grep` finds no assignment to a bowl's step or `hang_days` outside `BasinDay` and `Redirection`.
5. **The ledger is the truth for Bitter.** `Ending.is_bitter` reads only the ledger and the basin; the first-contact card never counts.
6. **Branchable.** The preview and every redirection return a new campaign and leave the input unchanged; the isolation tests are extended.
7. **The surface decides nothing.** `table_view` and `table_board` name none of the spread, hang or preview rules; the plan 7.4 assertion is extended to them.
8. `make shots` shows the card; UI §8's *never shows* column holds; no hue carries it.

---

## 6. Sequencing note

**8.0 and 8.1 first and independent.** Both extend the tick and neither needs the other, but the preview needs both. **8.2 before 8.3** because the preview applies a redirection through the one place 8.2 builds. **8.3 is the contract** the screen is written against, as 7.1's knowability test was for plan 7. **8.4 needs 8.3.** **8.5 last**: it touches `Machine`, `MachineCommand`, the dispatch and the fixtures, and is the only slice that reaches back into the tactical layer.

---

## 7. Decisions

### 7.1 — How does a redirection spread? **A bowl fed by a feeder two or more steps wetter walks one step wetter when its own ring does not hold.**

Locked (A).

- **A (chosen). A bowl fed by a feeder two or more steps wetter than itself walks one step wetter when its own ring does not hold; never past one bowl a day; never up to the bowls that feed it.** It is the overshoot GDD §6.4 names ("creep can overshoot into the next bowl if ignored"), it reuses the ring-holds test that already limits a dead pump, and it stops by itself while the ring holds.
- **B. No spread: a redirection only holds its own bowl.** Simplest, and then "whether the creep can reach the next bowl" has no answer to preview, which the GDD says the card must name.
- **C. A fuller water model.** Heads, flows, rates. GDD §6.1: "Do not simulate liters."

### 7.2 — What does the player have standing in a bowl? **A few counts per bowl, plus a road flag.**

Locked (A).

- **A (chosen). A few counts per bowl, plus a road flag: fields, camps, posts, ruined.** Enough for the card to say "2 fields, a post and the road" and for Mud to ruin a field. It is a summary of GDD §4.3's tile states, not a tile map.
- **B. Only the labor board's counts, not placed anywhere.** No per-bowl answer, so the card cannot say what stands in the water.
- **C. Per-tile states for every dry tile of every bowl.** The full GDD §4.3 list and a lot of data and authoring for a first card.

### 7.3 — How tightly does a redirection preview in a half-fixed ring? (GDD §10) **Exact where every bowl in the affected ring has instruments, otherwise a labelled range.**

Locked (A).

- **A (chosen). Exact where every bowl in the affected ring has instruments, otherwise a range one day wider for each affected bowl that does not, and the card says *range*.** It follows the GDD ("a mature network previews tightly, a half-fixed outer bowl previews as a range and says so") and the day count it widens is something a test can state.
- **B. Always exact.** Tidy, and it breaks the knowability rule the other way: it would claim more than the instruments know.
- **C. Always a range.** Honest and uselessly vague in a fully instrumented ring.

### 7.4 — Which redirection is the first-contact card? **The first one recorded at a bowl whose opening carries the authored sluice.**

Locked (A).

- **A (chosen). The first redirection recorded at a bowl whose opening carries the authored first-contact sluice (the terrace).** GDD §6.5 says the map offers it, so it is data on the bowl, not a guess about the player's history.
- **B. Whichever redirection happens first in the campaign.** Simple, and it lets any bowl's first sluice be the free one.
- **C. None: every redirection counts.** The first-contact card would then make a campaign Bitter, which the GDD says it never does.

### 7.5 — "Refuse the sluice", before there is a founder **A dispatch choice that locks the sluice for that fight.**

Locked (A).

- **A (chosen). A dispatch choice that locks the sluice for that fight.** An active no (GDD §4.2), built without the founder; gating on the founder is a later change to which squad may open it.
- **B. Model a founder now.** The founder carries other rules (First Gauge, the Call, scars, the empty-chair tax) that are far larger than this plan.
- **C. No refusal verb.** Then the only way to "refuse" is to send nobody, which is not the choice the GDD names.

### 7.6 — When does a redirection stop counting toward Bitter? **When its bowl has walked back to or past the step it left.**

Locked (A).

- **A (chosen). When its bowl has walked back to or past the step it left.** The hangover is the water being wetter than before; once it is not, the neighbours have their land back (GDD §6.6: "still has a hanging wet tile").
- **B. When its hold runs out.** The hold is five days and the walk back takes longer, so a campaign could stop being Bitter while the ditch is still on the map.
- **C. Never.** Once a redirection, always Bitter. The GDD calls the ending computed from what is on the map at the end.

---

## 8. What comes after

`plans/09` is **bands and mail** as map facts on the facts layer plan 4 reserved: the marks heard and where, arriving late until radio; a band as a person in a place with one job, warm or cold as a map fact; and the consequences GDD §6.4 lists for a redirection (the new canal becomes someone's home). Then research and the handoff, the base cutaway, the causeway and Vanguard FOBs with the push-has-broken check, the founder as a unit, the day economy that makes a ruined field cost food, and last a 3D basin table over the same rules.
