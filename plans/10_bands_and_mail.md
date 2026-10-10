# Phase 10 — Bands and mail: people in places, and news that arrives late

**Status:** drafted; §7 decisions locked (A); 10.0 completed. Slices 10.0–10.5 below.
**Tracks:** GDD v1.18 §5.12 (bands: one job each, capped per ring, warm or cold, a band is a person in a place; rumours arrive late until radio), §5.11 (meeting, flight, the band that remembers), §4.2 ("answer mail" as a table verb), §6.4 (a redirection's consequences: "the new canal becomes someone's home"), §6.6 (a warm band is half of the door left open); UI/UX v0.24 §6 (map facts and ageing), §8 (*bands are people in places*; no meter on a face; no quest log).
**Depends on:** Phase 9 — the economy gives a band's food job something to add to and the camp something to take a name from. Phase 8 — the redirection ledger is what makes a band go cold, and the card is where the player is warned. Phase 7 — the basin, the day tick, the campaign and its assignments. Phase 4 — the `facts` layer the store reserved beside `bowls`, and the rule that a fact is current on bowls the dome reaches and last-seen elsewhere.
**Goal:** the basin has other people in it. A band is a person in a place with one job; what it knows reaches the table late, as a mark on the map where it was heard; and a player who floods its canal or takes the crate it needed finds the part of the basin that was talking has gone quiet. None of it is a number: no warmth meter, no reputation bar, no quest log (GDD §5.12, UI §8).

---

## 0. Why this, and why not the alternatives

**The table is empty of anyone but the player.** After plan 9 the camp eats, grows and shrinks, and a redirection costs food, but the only other people in the basin are the ones the player already has. The GDD's long game (the town grows from "a person you did not finish", a warm band as half the ending's door, a rumour that arrives after the leak has ticked) has nothing to stand on at table scale.

**Two reads of the same thing.** A band is a *place*: where it was last seen, with the job it holds. Mail is its *voice*: what it reports, and when you hear it. Both are map facts in the sense plan 4 §7.9 settled: they are not actors in a fight, they are not terrain that ages to dust, and they follow the rule already decided for facts (current where the dome reaches, last-seen and aged elsewhere). So this plan adds no new fog rule; it builds on that one.

**Mail is where the table finally has something it does not already know.** On a bowl the player has walked, the dome reads water now. On a bowl they have not, the only news is a band's, late. That gives "walk the next bowl" a reason beyond the grid, and it makes the lag until radio a real cost the player can read: *heard: ridge_e, the pump broke, two days ago*.

**Why not the neighbours.**

- *Research and radio.* Radio removes the lag. It is a research output, and there is no research yet. This plan builds the lag as a named constant and a flag the radio plan will set, nothing more.
- *The tactical meeting* (§5.11: the knock, flee, truce, help, shoot the hands-up). That is a fight-scale rule with new commands and a conversation prompt. This plan meets a band at table scale (§7.1) so the long game exists; the tactical truce replaces it later without changing what a band is.
- *Vanguard dislodge, FOBs, the causeway.* Enemy structures are table objects that want the same facts layer, and they are the next plan's. A warm band is only half of the door-left-open ending; the other half is theirs.
- *The founder.* Bands do not care who is on the boat yet.

---

## 1. Decisions taken

| Decision | Choice | Consequence |
| --- | --- | --- |
| What a band is | **A person in a place with one job** | `Band`: id, the bowl it was last seen in, its job, warm or cold, the day it was met. Never a meter, never a count of favours. |
| Where it lives | **In the campaign, and in the facts layer as last-seen** | Truth in `Campaign.bands`; what the player last saw of each in the store's top-level `facts` map (plan 4 §7.9 Q3). |
| Knowability | **A band changes only for a reason the table could have read** | A job change is a command; going cold has a stated cause the card names beforehand; nothing moves on a die. |
| What the table may show | **Where it was last seen, aged, and what it said** | No band mark on Unknown ground; a warm band's mark is fresh, a cold band's ages like any stale tile. |
| Where mail is made | **`rules/basin/mail.gd`, from the day tick** | Pure: reads what the day did and what each band's eyes can see, and returns the entries; the morning read is drawn from them. |
| No quest log | **Mail is read once, in the morning, and kept as marks on the board** | UI §8 forbids a quest log; the marks age out like stale tiles. |

---

## 2. Layout

```
rules/basin/band.gd                  Band: id, bowl, job (EYES, FOOD, NAME, WARN), warm, met_day, route
rules/basin/bands.gd                 the rules: cap per ring, who stands where today, going cold, warm count
rules/basin/mail.gd                  Mail: what each warm band's eyes heard, and the day it arrives
rules/basin/mail_entry.gd            MailEntry: bowl, what (step landed / walk began / pump broke), day it happened, day it arrives
rules/campaign.gd                    bands: Array of Band; inbox of mail not yet arrived; radio (false: the seam)
rules/campaign_codec.gd              bands and the inbox ride in the save, beside redirections
rules/fixtures/bowl_openings.gd      which bowl carries an authored band, and its route (data, not a guess)
rules/commands/table/set_job_command.gd   a band's job changes: Confirmed, charges the table day
rules/commands/table/home_command.gd      a band is met when a dispatch to its bowl comes home (§7.1)
rules/basin/ending.gd                Ending.has_warm_band(campaign): a query, nothing draws it
rules/basin/redirection_preview.gd   names a band that would go cold (§10.3)
presentation/table_queries.gd        the band marks, the mail lines, the card's warning
presentation/table_view.gd, table_board.gd   draws them; a band is a mark on a bowl, with a word, never a meter
tests/unit/basin/test_band.gd, test_mail.gd, test_bands_cold.gd
tests/invariants/test_knowability.gd extended: a mail entry names an event that happened, and arrives no earlier than its lag
```

---

## 3. Deliverable phases

Each slice ends with `make test` green. `make shots` joins the checkpoint at 10.5.

### 10.0 — A band is a person in a place

**Ships.** `Band` (id, home bowl, job, warm, met_day, route) and `Campaign.bands`, copied by `duplicate_campaign` and saved by the codec. An authored band per opening (`BowlOpenings.band(bowl_id)`), not met until §7.1's meeting. A cap per ring (`BasinRules.BANDS_PER_RING`, a working default) enforced by the rule that meets a band, not by the screen. `Bands.warm_count(campaign)` and `Ending.has_warm_band`.

**Done when.** A band exists unmet, is met by the rule, never exceeds its ring's cap, survives a save and a branch (`duplicate_campaign`) untouched, and `Ending.has_warm_band` is true exactly when a met band is warm.

**What landed.** `Band` (`rules/basin/band.gd`: id, `Job` EYES/FOOD/NAME/WARN, an authored `route` and where on it it stands, `met_day` (0 while unmet), `warm`, `cold_cause`, and `name_given` for 10.2's spent NAME job) and `Bands` (`rules/basin/bands.gd`: `authored`, `band`, `met_in_ring`, `why_not_met`, `meet_at`, `warm_count`). `BowlOpenings.bands()` authors two, unmet: the Wake-Riders (EYES, a route of the terrace then polder_a) and a roof-clan on the west ridge (FOOD). The ring is the bowl's grade, `BasinRules.BANDS_PER_RING` = 2, and a met band counts toward it warm or cold; `why_not_met` says *not there*, *already met* or *the ring holds no more bands*, and `meet_at` meets every band the cap allows at a bowl in authored order. `Campaign.bands` is copied by `duplicate_campaign` and saved by the codec; a save from before bands opens with the authored ones. `Ending.has_warm_band` is true when a met band is warm. A test reads every file under `rules/` and `presentation/` and fails on any assignment to a band's warmth, job, meeting, cause or spent name outside `Band`, `Bands` and the codec. **Not yet:** nothing meets a band (10.1), a band does not yet move along its route (it comes with mail, 10.3), and nothing draws one. Tests in `tests/unit/basin/test_band.gd`.

### 10.1 — Meeting a band at table scale

**Ships.** `HomeCommand` meets the band of the bowl the fireteam came home from, when someone got out, as decision 7.1 says. A met band is warm, holds the job the opening authors for it, and appears in the morning read (*you met a band at the terrace*). Nothing about a band is read from a bowl the player has not been to.

**Done when.** A dispatch that comes home with a survivor meets the bowl's band once; a wiped squad does not; a bowl with no band meets none; and the morning names the meeting in words with no number.

### 10.2 — Jobs

**Ships.** `SetJobCommand`: a warm band takes one of four jobs, EYES, FOOD, NAME or WARN (GDD §5.12). Changing a job is a Confirmed action that charges the table day, as decision 7.6 says, and is refused with a reason when the day's dispatch is spent or a dispatch is out. EYES: its bowl's events become mail (10.3). FOOD: a stated amount of food a day, through `Economy`. NAME: one person arrives on the bench the first day it holds the job, then the job is spent. WARN: its bowl is named on the redirection card (10.4).

**Done when.** Each job does what the GDD says through the rule that owns it (`Economy` for food, `Campaign.bench` for a name), a change costs the day, a cold band takes no job, and the cap is not broken by a job.

### 10.3 — Mail

**Ships.** `Mail.read(campaign, result)`: for each warm band with EYES, the day's events at the bowl it stands in (a step that landed, a walk that began, a pump that broke) become `MailEntry`s that arrive `BasinRules.MAIL_LAG_DAYS` later (decision 7.2), earlier only when `Campaign.radio` is set (the seam; nothing sets it here). `Campaign.close_day` queues them and delivers the due ones into `DayResult`, so the morning read draws mail from the same place it draws everything else. An entry names a bowl and an event and never gives what stands in it; hearing a bowl does not make it known (decision 7.3).

**Done when.** An entry arrives exactly `MAIL_LAG_DAYS` after its event and never before; a band without EYES, a cold band or an unmet band reports nothing; a heard bowl is still unknown to the table's own reads; and the forecast and the tick agree about what arrives.

### 10.4 — Going cold, and the warning before it

**Ships.** The rule from decision 7.4: a band goes cold when a redirection leaves its bowl wetter and hanging, or when the fireteam takes the cache at the bowl it stands in (`Campaign.salvaged`). Going cold is recorded with its cause and is permanent (decision 7.4). `RedirectionPreview.read` names a band that would go cold, in the same simulated run it already does, and the card says so (*the band at X would go cold*); a WARN band's bowl is named even when the player has not walked it, which is the job's whole point.

**Done when.** Each cause cools exactly its band and no other; a cold band stops reporting and holds no job; the card names a cooling band if and only if the rule will cool it (a test runs the redirection and compares); and a redirection of a bowl with no band says nothing.

### 10.5 — The surface

**Ships.** The board draws a band as a mark on the bowl where it was last seen, with its job in a word, aged in the grammar section 6 already uses (a cold band's mark ages out like a stale tile); mail arrives as *heard:* lines in the morning read and as marks that fade; the band's dispatch-slot line and the set-job control (a small per-band row, not a menu). No meter, no reputation line, no log (UI §8).

**Done when.** A shot shows a met band's mark on the board, its job, a *heard:* line in the morning read and the card's cold warning; every word on screen equals a rule's output; the `never shows` assertions still hold (no *warmth*, *trust*, *reputation*, *loyalty*, bar or percentage); and a cold band's mark visibly ages out.

---

## 4. Explicitly out of scope

- The tactical meeting (the knock, flee, truce, help, shoot the hands-up) and the second-meeting gamble (§5.11). A later fight-scale plan replaces §7.1's table meeting.
- Radio, masts and the research that builds them. The lag is a constant and `Campaign.radio` is a flag nothing sets.
- Answering mail by sending someone (GDD §4.2's verb). It wants a way to send one person without a fireteam; the day's dispatch is the only send there is.
- Vanguard dislodge, FOBs and the causeway (the next plan), and the ending that counts them with a warm band.
- Purifiers and Vanguard as bands. Only basin folk are bands (GDD §5.12).
- Harm tallies (§6.6) beyond what a cold band already records.

---

## 5. Verification

- `make test` green after each slice. Band and mail tests are pure unit tests under `tests/unit/basin/`.
- **Knowability.** A band changes only through a command or a stated cause; a mail entry names an event that happened and arrives no earlier than its lag; the card's warning equals the rule (the redirection is run and the band's state compared).
- **Unknown stays unknown.** A heard bowl is not marked known; the table's reads of it (the board card, the dispatch, the preview) are unchanged by mail.
- **Isolation.** Commands return new campaigns; the preview and the forecast change nothing (the plan 8 pattern, extended to bands and the inbox).
- **One place.** A test reads every file under `rules/` and `presentation/` and fails on any assignment to a band's `warm`, `job` or `bowl` outside `Bands`, the codec and the fixtures, the way plans 8 and 9 guard the step and the counts.
- **UI §8.** The existing `never shows` assertions are extended with *warmth*, *trust*, *reputation* and *loyalty*.
- **Screens.** `make shots` for the table setups, viewed by a human; a green suite does not show what is on screen.

---

## 6. Sequencing note

**10.0 first**, and headless. **10.1 needs 10.0**; **10.2 needs 10.1** (a job needs a met band). **10.3 needs 10.2** (mail is the EYES job). **10.4 is independent of 10.3** and could go before it, but its preview reuses 10.2's WARN and 10.0's state. **10.5 last:** it draws everything, and it is the only slice that touches the scene.

---

## 7. Decisions

### 7.1 — How is a band first met, before there is a tactical meeting? **A dispatch to its bowl that comes home with someone, authored per bowl.**

Locked (A).

- **A (chosen). A bowl whose opening carries a band meets it when a dispatch to that bowl comes home with at least one survivor; the band is warm and holds its authored job.** It is data on the bowl like the first-contact sluice (plan 8 §7.4), needs no new fight rule, and a later tactical meeting replaces it without changing what a band is.
- **B. Build the knock and the truce in the fight now.** The honest answer to GDD §5.11, and a fight-scale plan with new commands, a prompt and a flee rule; larger than this one.
- **C. A table verb that "finds" a band for a day and a scrap.** Quick, and a band is then a purchase, which the GDD calls a conversation, not a recruit.

### 7.2 — How late does mail arrive? **A fixed lag in days, shortened only by radio.**

Locked (A).

- **A (chosen). Every report arrives `MAIL_LAG_DAYS` after its event (working default: 2), and radio (a flag nothing sets yet) removes the lag.** It is the GDD's "a day, a dusk, a boat that has to find you" as one number a test can state, and the forecast and the tick agree on it.
- **B. Lag by distance: the number of bowl-to-bowl hops between the band and the camp.** Closer to "a boat has to find you", and a second graph rule and a second number to preview; worth it once a mast exists.
- **C. No lag.** Then mail is the dome by another name and radio has nothing to improve.

### 7.3 — What can a report say, and does hearing a bowl make it known? **It names the bowl and the event, and never makes the bowl known.**

Locked (A).

- **A (chosen). An entry names the bowl and one of three events (a step landed, a walk began, a pump broke) with its age, and the table's own reads of that bowl stay unknown.** It keeps the plan 4 and plan 7 rule that a bowl is known by walking, and it gives the player a reason to go.
- **B. Hearing marks the bowl known.** Cheaper, and it undoes the knowability test: a walk would land without the player having walked.
- **C. A report only says "something happened somewhere".** Safe, and useless: the GDD's example is *wrench on the north rim*.

### 7.4 — What makes a band go cold, and does it come back? **A redirection that leaves its bowl wetter and hanging, or taking its bowl's cache; permanent.**

Locked (A).

- **A (chosen). Two causes the table can read beforehand, both from the ledger: a redirection of the band's bowl that is still hanging, and the fireteam taking the cache at the bowl the band stands in. Going cold is permanent.** These are the GDD's "flood their canal" and "take the crate they needed"; both are already recorded (`redirections`, `salvaged`), and a permanent state is a map fact, not a bar.
- **B. The same causes, and the band thaws after N days.** Kinder, and a timer on a person is a meter in disguise.
- **C. Only the flood.** The cleanest, and it drops "take the crate" and the shot-the-spared and gun-post causes the GDD lists; those wait for the tactical meeting and the posts rule.

### 7.5 — Does a band stand still? **A fixed authored route, one step a few days, deterministic.**

Locked (A).

- **A (chosen). A band follows an authored route (a short cycle of bowls it moves along every `BAND_MOVE_DAYS`), so its eyes move with it (GDD §5.12: "information moves with them").** The table shows where it was *last seen*, and an old mark ages. No randomness.
- **B. A band never moves.** The simplest, and then it is a fixed post, which the GDD says early bands are not.
- **C. A band wanders by a seeded roll.** Closest to "wanderers still wander", and it makes the mark unpredictable in a way a test cannot hold to the knowability rule.

### 7.6 — What does changing a job cost? **The table day.**

Locked (A).

- **A (chosen). A job change is a Confirmed action that uses the day's dispatch (so no fireteam goes that day).** GDD §5.12 says a job change "costs a day at the table", and the dispatch is how the table already spends a day.
- **B. One of the day's three assignments.** Cheaper than the GDD says, and then jobs can be reshuffled freely.
- **C. Free.** Jobs are then a dial, not a commitment, which is the opposite of the sentence it came from.

---

## 8. What comes after

`plans/11` is **the Vanguard on the table**: the highland pressure bands (watching, surveying, building) as readable map facts on the same facts layer, the causeway that grows day by day, FOBs as table objects and targets, and the push-has-broken check that sits beside a warm band in GDD §6.6. Then research and the handoff (including the radio that removes mail's lag), the base cutaway, the founder as a unit, the tactical meeting (replacing 7.1), and last a 3D basin table over the same rules.
