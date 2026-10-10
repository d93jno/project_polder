# Phase 9 — The day economy: mouths, fields, fuel and scrap

**Status:** drafted; §7 decisions locked (A); 9.0 completed. Slices 9.0–9.5 below.
**Tracks:** GDD v1.18 §4.2 (the four currencies, fuel knowable like water, surplus spendable), §4.3 (food is a problem until the basin feeds the ridge; fields tick on the day clock; people follow the water out; the labor board), §6.4 (a drowned field is a cost), §6.6 (civic lose: food at zero before fields exist); UI/UX v0.23 §8 (previews show capabilities, never bars, percentages or targets).
**Depends on:** Phase 8 — fields are counted per bowl (`BasinBowl.fields`, `ruined`) and ruin is recorded but costs nothing yet. Phase 7 — `Campaign` holds food, fuel and scrap as plain counts that nothing spends except pump upkeep (scrap), and the labor board has a FIELDS bucket that does nothing. `DayResult` is the morning's data.
**Goal:** the three counts on the table start to mean something, and every one of them can be read before it bites. Mouths eat, fields feed, a dispatch burns fuel, scrap comes from somewhere, and a ruined field is finally a cost the player can see coming. Nothing is a bar: the table says "food lasts four days", never "food 62%".

---

## 0. Why this, and why not the alternatives

**Phases 7 and 8 left the economy as decoration.** `food 12 · fuel 4 · scrap 6` is drawn and never changes. Hands in FIELDS produce nothing, a ruined field is a line in the morning read with no consequence, and a dispatch is free. That makes the table's best decisions (where to put hands, whether to send the fireteam, whether to open the sluice over somebody's barley) cost nothing, which UI §8 calls a day with no decision.

**The GDD has the shape and leaves the digits.** Food is a problem until fields exist (§4.3); fuel is knowable before a leg is committed (§4.2); scrap is workshop, dredge and upkeep; people grow toward what dry tiles can feed. All of it is pure arithmetic over state the basin already holds, so every rule here is a deterministic function on `Campaign` and testable headless, the same way the day tick was.

**The knowability clause is the test.** Food running out, fuel not reaching home, and a flood ruining a field must each be readable beforehand. Plan 7's knowability test (a change lands only after being read as walking) extends to the economy: a count never drops to a state the morning read could not have forecast.

**Why not the neighbours.**

- *Bands and mail* (the old draft of this slot) are map facts on the facts layer. They do not need an economy to exist, and the economy does not need them. They follow.
- *Research and the Citadel's rooms* spend scrap and hands, so they want this plan's income first.
- *Individuals.* People stay one number and the labor board stays buckets (GDD §4.3 anti-goals). Nobody gets a name or a mood here.
- *Consumables and the ammo press.* Items, not bars; they want a workshop output and wait for it.

---

## 1. Decisions taken

| Decision | Choice | Consequence |
| --- | --- | --- |
| Counts stay plain integers | **No fifth bar, no rate display** | The table shows counts and *lasts N days*; never a percent, a meter or a target. |
| Where arithmetic lives | **`rules/basin/economy.gd`, called by `BasinDay`/`EndDayCommand`** | One place changes `food`, `fuel`, `scrap`, `people`; a test reads every file and fails on any other assignment, the way plan 8 guards a bowl's step. |
| Forecast | **`EconomyForecast.read(campaign)`, the rule run on a copy** | Same pattern as `RedirectionPreview`: the card cannot disagree with the tick. |
| What the player may see | **Only what they know** | Fields on bowls they have walked count; an unwalked bowl's harvest is "ground you have not walked", not a number. |
| Costs of a dispatch | **Fuel for the leg, and a day (already)** | Fuel is shown on the dispatch slot before the fireteam is sent (§7.3). |

---

## 2. Layout

```
rules/basin/economy.gd               Economy: eat, harvest, upkeep, growth; the one place a count changes
rules/basin/economy_forecast.gd      the query: days of food, whether a leg reaches home
rules/basin/basin_rules.gd           constants: food per mouth, yield per field, fuel per leg (working defaults)
rules/basin/day_result.gd            gains the day's meal, harvest, growth and leavers
rules/commands/table/end_day_command.gd   runs the economy after the basin tick
rules/commands/table/dispatch_command.gd  spends the fuel for the leg
rules/campaign.gd                    people (the pool) grows and shrinks only through Economy
presentation/table_queries.gd        the forecast lines and the fuel line on the dispatch slot
presentation/table_view.gd           shows them; no bar
tests/unit/basin/test_economy.gd, test_economy_forecast.gd
tests/invariants/test_knowability.gd extended: no count reaches a state the forecast did not name
```

---

## 3. Deliverable phases

Each slice ends with `make test` green. `make shots` joins the checkpoint at 9.5.

### 9.0 — Mouths and the daily meal

**Ships.** `Economy.eat(campaign)`: each person eats `BasinRules.FOOD_PER_MOUTH` a day, taken in the morning after the basin tick. Food never goes below zero. The people's shortfall is recorded in `DayResult` (the morning says *short by N*, not a bar). `EconomyForecast.days_of_food(campaign)` reads the rule on a copy and returns how many days the current food, hands and fields last.

**Done when.** A day ends with food lower by the mouths; a shortfall is recorded and leaves food at zero; the forecast equals the days the real tick takes to reach zero; and the morning read names the meal.

**What landed.** `Economy.eat` (`rules/basin/economy.gd`), called from `Campaign.close_day` after the basin tick, so day end and the way home both eat. The constant is `BasinRules.MOUTHS_PER_FOOD` = 4 rather than a food-per-mouth number: one ration feeds four and a part-fed group eats a whole one, so the ten at the opening eat three a day and the 12 food lasts four days. `DayResult.meal` is `{ate, short}`. `EconomyForecast.days_of_food` ends real days on copies of the campaign (so it is the tick, not a second implementation) and returns -1 past `BasinRules.FORECAST_DAYS` (30). The table shows *food lasts N days* under the people count, and the morning read opens with *the camp ate N food* (*and was short by M* when it was). People leaving for want of food is 9.4's. Tests in `tests/unit/basin/test_economy.gd` and one in `test_table_view.gd`.

### 9.1 — Fields feed

**Ships.** Harvest: a bowl's un-ruined `fields` on ground that is Dry yield food per field per day, scaled by the hands in the FIELDS bucket (§7.1). Falling and Mud yield nothing (GDD §4.3); a ruined field yields nothing for good. A bowl the player has not walked contributes to the tick, but the table's forecast lines it as *ground you have not walked*.

**Done when.** Fields on a Dry bowl raise food each day; hands in FIELDS change the harvest by the stated rule; Mud ruins a field and the harvest drops by exactly that field in the forecast and the tick alike; and a redirection's preview (plan 8) can state the food it will cost, in counts.

### 9.2 — Fuel and the leg

**Ships.** A dispatch costs fuel for the leg to its bowl and home again (`BasinRules.fuel_for_leg(bowl, step)`: Flooded by boat, Mud slower, Dry cheapest; GDD §4.2 "Travel"). `DispatchCommand.validate` refuses a dispatch the fuel cannot cover and says why. The dispatch slot shows the leg's cost and whether the fuel left reaches home *before* the fireteam is sent (GDD §4.2: "never a surprise on the way back").

**Done when.** A dispatch spends the stated fuel; a dispatch the fuel cannot cover is refused with a reason; the slot's line equals the command's cost; and a test proves the slot cannot say "reaches home" when the rule says it does not.

### 9.3 — Scrap in and out

**Ships.** Scrap income: hands in WORKSHOP turn time into scrap at a stated rate; a fight brought home with extracted units brings back what the fixture's loot carries (§7.4). Out: pump upkeep (already built) and a simple dredge cost for a bowl the player chooses to clear (a labor move, not a new screen). `Economy` is the only place scrap changes.

**Done when.** Scrap rises with workshop hands and falls with upkeep; a pump that cannot be kept for want of scrap is shown as such before the day ends; and nothing outside `Economy`, `AssignLabor`'s refusal and the pump post spends scrap (a test reads every file).

### 9.4 — People follow the water

**Ships.** Population growth (GDD §4.3): one number that ticks up toward what the dry, un-ruined tiles can feed, and down when a field is ruined or a suburb drowned. New hands arrive idle. Leavers come out of IDLE first, then the least-posted bucket, the way the lost leave the bench (plan 7).

**Done when.** A well-fed camp with spare fields grows by the stated rule; a drowned field makes a stated number leave; the pool never goes negative or invents hands; and the morning read says who came or left in words, not a graph.

### 9.5 — The surface: the table says what it costs

**Ships.** The table shows *food lasts N days*, the harvest in counts, the fuel line on the dispatch slot, scrap upkeep, and the people who came or left, all from `EconomyForecast`. The redirection card (plan 8) gains its food line. No bar, no percentage, no target, no icon that implies one (UI §8). Food at zero with no fields is the civic lose of GDD §6.6 and is a query (`Ending.is_starved`), not a screen.

**Done when.** A shot shows the forecast lines on the board and the fuel line on the dispatch slot; every number on screen equals a rule's output; the `never shows` assertions still hold; and `Ending.is_starved` is true exactly when food is zero and no un-ruined field is Dry.

---

## 4. Explicitly out of scope

- Individuals, names and moods (GDD §4.3 anti-goals). The pool is one number.
- Consumables, the ammo press and other items. A later workshop plan.
- The still (scrap and time into fuel) and research that cheapens fuel. Needs Research.
- Spending surplus: sitting a day, stretching MEDEVAC, funding a help-gamble. Needs the verbs those spend on.
- Hydroponics (a dome-only stopgap) and the Citadel's rooms.
- Forward camps and supply lines as food or MEDEVAC routes.
- Balancing the digits. Every rate is a working default in `BasinRules`, named and tested for its rule rather than its value (GDD §10).

---

## 5. Verification

- `make test` green after each slice. Economy tests are pure unit tests under `tests/unit/basin/`.
- **Forecast equals tick.** `EconomyForecast` and `EndDayCommand` are compared over a run of days from several openings; any disagreement is a failure.
- **Knowability.** Extending plan 7's test: for a run of days with random-looking but fixed labor plans, no count reaches zero, and no pool loses a hand, that the previous morning's forecast did not name.
- **One place changes a count.** A test reads every file under `rules/` and `presentation/` and fails on an assignment to `food`, `fuel`, `scrap` or the people pool outside `Economy` (and the opening fixtures, comparisons excepted).
- **Isolation.** Commands return new campaigns; `Economy` never edits its input (`test_state_isolation.gd` pattern).
- **UI §8.** The existing `never shows` assertions are re-run on the new lines.
- **Screens.** `make shots` for the table setups, viewed by a human; a green suite does not show what is on screen.

---

## 6. Sequencing note

**9.0 first**, because eating is the smallest rule and the forecast pattern is proved on it. **9.1 needs 9.0** (a harvest only matters against a meal). **9.2 is independent** of 9.1 and can go in either order. **9.3 and 9.4 need 9.0 and 9.1.** **9.5 last**: it draws everything and is the only slice that touches the scene.

---

## 7. Decisions

### 7.1 — How does a field yield? **A fixed yield per Dry, un-ruined field, with hands in FIELDS adding to it.**

Locked (A).

- **A (chosen). A fixed yield per Dry, un-ruined field; each hand in FIELDS adds a stated extra, up to a field's worth of hands.** It keeps "hands in the food engine" a real labor choice (GDD §4.3), and the forecast is a sum a test can state.
- **B. Yield only with hands.** A field with nobody on it feeds nobody. Simple and harsh; it makes a flood over a staffed field and an unstaffed one the same loss.
- **C. Yield by the ring's wetness gradient.** Realistic and a second water model on the table; GDD §6.1 says do not.

### 7.2 — What happens when food runs out? **People leave, then the camp is starved (a query, not a screen).**

Locked (A).

- **A (chosen). A shortfall costs a stated number of people each day it lasts, taken from IDLE first; zero food with no Dry field is `Ending.is_starved`.** Matches GDD §4.3 ("some leave or die") and §6.6 (the civic lose), and it leaves the player a day or two to react.
- **B. Hard stop: zero food ends the campaign at once.** Clearest, and it reads as a surprise unless the forecast is perfect; GDD says the lose is a state, not a timer.
- **C. A morale penalty on dispatch.** A fifth bar by another name.

### 7.3 — What does a leg of fuel cost? **A count by the bowl's step, there and back, shown before sending.**

Locked (A).

- **A (chosen). Fuel for the leg depends on the bowl's step (Flooded boat, Mud slower, Dry cheapest), paid when the fireteam is sent, and refused if it cannot reach home.** The GDD says fuel is knowable before the leg, and the step is already on the table.
- **B. A flat cost per dispatch.** Simple, and it throws away the point that water decides the road.
- **C. Fuel burned per fight turn.** Needs a fight clock the table does not own, and breaks the layer rule (the fight reads nothing of the campaign).

### 7.4 — Where does scrap come from? **Workshop hands, plus what a fight brings home.**

Locked (A).

- **A (chosen). Hands in WORKSHOP produce a stated amount a day; a fight brought home adds what its extracted units carry.** Two sources, both knowable: one is a rate, the other is on the fixture.
- **B. Workshop only.** Then a dispatch has no pay and the fireteam is only a cost.
- **C. Salvage only.** Then WORKSHOP is dead weight and the labor board loses a choice.

### 7.5 — How does the population grow? **Toward what Dry, un-ruined fields can feed, a stated step a day, never past the food.**

Locked (A).

- **A (chosen). One number that moves a stated step toward the mouths the fields can feed, and never grows while food is short.** The GDD's "ticks up toward whatever the dry tiles can feed", and it makes a ruined field cost people.
- **B. Fixed by act.** Easy to test and it cuts the link between the water and the camp the GDD names.
- **C. Growth by random arrivals.** Breaks determinism.

### 7.6 — Does the redirection card name the food it costs? **Yes, in counts, for bowls the player has walked.**

Locked (A).

- **A (chosen). The card gains a line per bowl: fields lost and the days of food that changes, from the same forecast.** Closes plan 8's open end ("a ruined field is recorded, not yet priced") and keeps the preview equal to the rule.
- **B. The card stays as is and the cost shows up in the morning.** That is a consequence the table withheld, which §6.4 forbids.
- **C. A single total.** Hides which bowl is paying.

---

## 8. What comes after

`plans/10` is **bands and mail** as map facts on the facts layer plan 4 reserved: the marks heard and where, arriving late until radio; a band as a person in a place with one job, warm or cold as a map fact; and the consequences GDD §6.4 lists for a redirection (the new canal becomes someone's home). Then research and the handoff, the base cutaway, the causeway and Vanguard FOBs with the push-has-broken check, the founder as a unit, and last a 3D basin table over the same rules.
