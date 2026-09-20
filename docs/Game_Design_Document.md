# Game Design Document: "Project Polder" (Working Title)

**Version:** 1.9 — break is defined: outnumbered, in the open, long cone and CQB kit each get a countable working default, and a break lands the moment its condition becomes true. (1.8: knowability extended: pump upkeep is knowable, the Opening reads water off the world and the founder, and a redirection is previewable before it is spent; prisoner named as a fourth off-ramp option; fuel legs are knowable; the boat is a place on the map. 1.7: squad-mode walking is not phased; contact and the knock (working default); Pinned cancels a live Watch and costs one phase of action; broken beats Pinned; bleed-out is 3 rounds (working default). 1.6: vocabulary split: *Pinned* is the combat state, a *band* is a nomad group, a *marked roof* is a shelter; "band" freed from tactical and labor use; §5.12 "Break" renamed. 1.5: endings computed from hidden counts; acts, phases and triggers mapped; table days, economy and classes locked; deterministic break rule and reaction fire; contradictions from 1.4 resolved.)

## 0. Document Scope
This document is the base foundation for the game's mechanics: its systems, rules, campaign structure, and the design tone those rules express. When a later document disagrees with a mechanic described here, this one wins until it is revised.

It deliberately does not cover presentation. UI and UX (including how the water graph, fog, and First Gauge are drawn), art direction, audio, and other production topics are addressed in separate documents. Where this document says a representation "comes later" or is "out of scope," it is pointing at those documents.

Numbers marked as a *working default* are starting points for prototyping, not final tuning.

**Versioning.** The version lives in the header above, not in the filename. This file stays `Game_Design_Document.md` for the life of the project so links, citations and git history follow one path. Each revision bumps the header and adds a "Locked in x.y" block to Section 9. The companion `UI_UX_Document.md` follows the same rule.

## 1. High-Level Concept
A turn-based tactical RPG with deep base-building, logistics management, and a persistent, dynamic world. Set in a post-apocalyptic region structurally similar to the Netherlands, the land was protected by massive levees that failed during "The Collapse." The player is a named founder who starts in the water with a moving boat camp — people who have lived in this basin their whole lives. The Citadel is a life-altering discovery, not a dash for survival. Once the instruments wake, the founder becomes the commander whose voice and impossible engineering hold the reclamation together. The spine of the campaign is humanist: people gathering on dry land to solve a problem together. Hardship and fighting are real. They are not the point. The point is the town that appears because the water left.

**Core Pillars:**
*   **Tactical Permadeath:** High-stakes, turn-based combat where every squad member’s life matters. The founder’s death ends the campaign.
*   **Persistent Reclamation:** The basin is a closed population. Nobody respawns. Clear a roof and those people are gone from it. No mission-budget refill, no zombie street that forgets you were there. That irritation is why the game exists. The other side of the coin: the same finite people are the town. The Vanguard are the exception that proves the rule — they come from *outside* the basin.
*   **Dynamic Environment:** Water moves through a graph of bowls, not isolated tiles. Repairing a pump drops a sector; sealing enough of the ring is what actually dries it. Terrain and factions change with the water step.
*   **Dry Is the Verb:** The campaign is reclamation. Putting water back is a rare late option with a hangover, not a second core loop.
*   **Extended Logistics:** The further the player travels from their central base, the harder survival, supply lines, and extraction become.
*   **The Founder Is the Save:** The player avatar is a deployable body, not a cursor. Their unique engineering cannot be taught. Their presence can steady a squad. Losing them loses the war.
*   **Humanist Throughline:** The game is about getting together to solve a problem. The basin has a finite number of people. They are the town, the bench, the lookouts. Population, fields, pumps, and the Call are the same story: more people, more hands, less of the founder doing everything. A wipe spends that story. Act III is the story under more weight — not a twist that throws away the loop the player learned to love.
*   **No Early-Solved Plot:** The player should not complete the story in their head ten hours before the end. Lore (including the silenced split) never pays a mechanical bill and never pays an ending bill. Hints may stay unfinished. No bloodline speech, no “the army was good all along,” no genre-swap finale, no reunion. The highland noticed the town. That is the honest forecast. How the last streets go is not.
*   **Told in Play:** The story is the loop. A plate, a roof, a column in barley, a band that goes cold, surplus with no labor. Not cutscenes. Not a required codex. Not a briefing that finishes a thought the street should have. Miss every hint and the campaign is still complete. Walk and notice and you may assemble more. The world happened; you are in it. No one sits you down.

## 1.1 Moral physics (tone of the design)
The game has no moral meter. It has a moral physics: people are scarce, land is a verb, and the ending is what you spent.

**What counts as good.** A living basin. Dry enough to eat from. Enough hands to run pumps, fields, lookouts. Neighbors who were not finished when they could have been. Survival is not “the founder lives.” Survival is a town that can still do Tuesday. Care plus competence. You keep people because they are how you live, not because a slider told you to be nice.

**What it refuses.** Karma (no good/evil score, no speech that redeems an army). Purity (dry is not holy; Purifiers are that theology and they are a wrench). Total victory as goodness (army-on-army is a legal win and the rim’s job; hollow credits exist so a correct tactics game is not automatically a kept town).

**Force.** Not a fail. First Vanguard fights are supposed to be gutwrenching. Clean shots hit. Permadeath is real. This is not a pacifist. Force is expensive in the only currency that compounds: the closed basin pool. A wipe is a good mission and a worse decade. Vanguard sit outside that pool; how you treat yields still changes whether pieces of them ever drop the raid script. You can ignore that and still get credits.

The ethic is responsibility for a commons, not “don’t shoot.” You are a water board with guns. Boards that only shoot stop being boards.

**The two heights.** Both think they are reclaiming land. That is symmetry, not a twist. They trained on raiders. You live in bowls. Some of them may come to see a town. Some of yours exist because someone already refused to keep killing boat folk. The game does not cash that out as reunion. It cashes it out as possibility. If the player never notices, the physics still work.

**Outside the care circle, on purpose.** Purifiers almost never get the off-ramp. The founder’s death is not a scar — it is the save ending. Their weight is irreplaceable literacy, not a higher price on one soul. Everyone else is replaceable as a unit and irreplaceable as the pool.

**What actually judges.** Not a scolding cutscene. Three accumulations: how much of the finite pool is still in the box; whether any door was left open after the fierce part; whether the land you dried still has a job besides war.

Working win: force happened; people remain; some of the other height flinched.  
Hollow win: the map looks like victory and the engine called “people” was a magazine.  
Bitter win: neighbors kept; land spent. A second sluice left a ditch on the map.  
Civic lose: the town did not keep the land.  
Personal lose: the reader of the basin is gone.

The game computes these outcomes from hidden counts (Section 6.6). The player never sees a score.

Tragic political ethics, not a fable. Nobody is clean. The pump-plus-neighbors is the only morality that leaves a Tuesday. The design does not ask the player to be good. It asks them not to spend the only thing the polder cannot restock.

## 2. Setting and World
*   **The World:** A vast, flooded urban and industrial lowland based on Dutch polder country — flat, diked, geometric, built below the water that wanted it. Society has adapted over years. Shanty towns cling to highway overpasses, rooftops are farmed, canals and drowned streets are the roads. Water is not a spooky anomaly; it is a mundane reality of everyday life. There are no Alps here. There is one honest height in the middle of the wet, and a wall of dry land far away.
*   **The Height Map:** Three grades on the strategy layer — **rim / floor / sump**. Water runs downhill. High shoulders empty with a small ring. Deep bowls stay wet until everything above them stops pouring in.
    *   *The ridge (the Citadel):* a low moraine / sandy ridge / research hill in the middle of the basin. Survivors call it a mountain. It is not. It is the one place the polder never quite flattened.
    *   *The terrace (first geography):* high shoulder near the ridge. Fairly high. Few pumps. Water has somewhere downhill to go. First bowls the boat camp can actually finish draining. Not yet “your campus.”
    *   *The floor:* ordinary reclaimed polders, towns, industrial parks. The work of the campaign.
    *   *The sump:* the true low bowls toward the center and the old peat. Last to dry, first to take a leak from uphill. Rusted loot. Citadel cellars flood from below until this grade drops.
    *   *The far highlands:* the dry rim of the world. Vanguard country. Pristine caches. The other height, looking back at yours.
*   **The Base:** "The Citadel." Before the Collapse it was a civilian research station — an observatory and weather/water campus on the ridge, built because the sky was clean and you could see the whole basin from the dome. It was not designed as a fortress. The player does **not** start here. They start as basin people on a boat. Finding the dome is not how you survive Tuesday. It is the first time anyone in this life has a map of bowls instead of a memory of bowls. The penthouse is the dome and the upper labs once claimed. Descent is the water falling off the hill and giving back the car park, the bunkers, the instrument halls. Compound is tents and steel on the newly dry slope, facing the polders you are stealing back.
*   **Look down from the dome:** the real polders, still full. That is the campaign poster.
*   **Look out from the dome:** another wall of dry land, waiting.
*   **The Tongue of the Basin:** World text is a rusted Dutch–English hybrid. The lowland was bilingual before it sank — ports, EU boards, research English on the ridge, kitchen Dutch in the polders. A generation in the water welded them. This is flavor, not a mechanic and not a gate. An English-only player should get about 70% of a wall and feel clever. Icons and water still have to work if they miss *verboden*.

    *   *Where it lives:* signs, pump plates, levee marks, graffiti, old receipts, street names. Not subtitles. Not mission briefings. Not the HUD. Squad banter and UI stay readable English, with the odd borrowed word at most. No comedy accent in every voiced line.
    *   *How it is written:* no conlang. Real cousins that already look half-drunk to an English eye — *water, polder, sluis, dijk, pomp, brug, straat, verboden, gevaar, uitgang* — next to observatory English that never left: GAUGE, OVERRIDE, SECTOR 12, DO NOT CYCLE. A plate that reads `SLUIS 4 — NIET OPENEN / NOT OPEN` is the model.
    *   *Different mouths, different rust:*
        *   Terrace / observatory: more English, instrument labels, weathered campus fonts.
        *   Floor polders: more Dutch, municipal, ugly useful.
        *   Wake-Riders: water-words, boat slang, almost no highland English.
        *   Purifiers: sermon Dutch, drowned-bible cadence; English loanwords treated as unclean.
        *   Vanguard: dry clipped military English, leftover NATO-Dutch on maps they never updated.
    *   *First Gauge (bonus read, not a lock):* the founder can finish a sentence a Pioneer only gets half of. Everyone sees `POMP DOOD`. The founder sees which neighbor is the real leak. The mission does not brick if you ignore the extra line.
*   **Enemy Factions (Grounded & Realistic):**
    *   *The Drifters:* Unorganized scavengers trying to survive. Opportunistic and desperate. They excel at rooftop ambushes and boat raids but panic in open, dry spaces.
    *   *The Wake-Riders:* Faction completely adapted to the flooded world. They use salvaged boats, excel at underwater stealth, and use spearguns and boarding tactics. Useless on dry land. As the basin drains they concentrate on the water that remains. Drain their last canal and they do not vanish: they become Drifter-style pressure or a help-gamble (Section 5.11), not a faction with infinite boats.
    *   *The Purifiers:* A fanatical, cult-like faction that views the flood as a "cleansing." They actively sabotage pumps to keep the world submerged. They do not need to win a fair fight. They need to break one pump in a finished ring. They are basin people, and the basin is finite: the Purifiers who exist can be wiped out, and sabotage gets scarce when they are. New ones appear only from neglect: a pump left unmaintained long enough, with a band gone cold or a desperate camp in that ring, can produce one new wrench. That is a consequence, not a spawn table.
    *   *The Vanguard (Military Remnant):* Originating from the distant, unflooded highlands that ring the far edges of the basin. Old-world doctrine, heavy armor, long-range ballistics. Masters of Dry. They kept the far rim. You kept a ridge in the wet. Drying the floor builds a highway up their grade.

        They have spent a generation fighting **raiders from the waterlogged basin** — boat gangs, desperate sorties, people who come up the grade to steal and run. That is the war they trained. That is what first contact is *for them*. They will not open with a handshake. They will open with a column.

        First fights are fierce, gutwrenching, and the player’s problem to solve (kit, sightlines, the desperate sluice). No ideological cutscene. They expect a raid. You look like one until you don’t.

        **Evolution, not a twist.** Over later contacts they see fields, posts, kids on a slope, a pump that is not loot. They are fighting normal people who live here. Doctrine cracks in *parts* of the Vanguard — a squad yields, a company waits on the rim one day longer, a prisoner who talks, a platoon that will not take the next street. The army as a whole still comes. You do not convert the highland. You dislodge pieces. No allied Vanguard RTS. No reputation bar. The war stays a war until it isn’t, and “isn’t” is withdraw / yield / refuse the order — the same off-ramp as everyone else, just slower and rarer.

        **Strength.** The Vanguard force inside the basin is finite. Reinforcements trickle down from the rim, slowly; the player can attrit a push until the trickle runs dry. The player cannot empty the highland and never marches on it. The war is survive-the-push. Armor is answered by excavation (anti-armor charges), by terrain, or rarely by another redirection. Without those tools, do not take the open street.

## 3. Core Gameplay Loop

**Session loop:** See a problem on the ring (or in the fog) → spend a day on it with the squad → come home to a basin that moved where you were not.

**Campaign loop:** boat camp and roofs → discover the dome → fields and posts → the highland bill. (Days are the only clock; there are no calendar seasons. Section 3.2 maps this loop to acts and phases.)

1.  **Walk the bowl:** The squad *is* the camera. Moving peels fog from Unknown to Known-quiet. Scouting is not a separate mission type.
2.  **Night and high ground:** Dusk is a habit, not a race to the Citadel. Camp the boat or a marked roof. Night on open water is a worse fight, not a game over.
3.  **Tactical fight:** When live fog shows a pump, a camp, or a leak — drop into the street. The founder is on the boat until the town exists; after that they may stay at the table. The player always plays the fight, whether or not the founder is in it.
4.  **Secure & Repair:** Complete the tactical objective to restart the local turbines. Routine overrides can be done by trained Pioneers. Impossible repairs still want the founder. One pump is not a dry sector.
5.  **Reclamation:** Water in that bowl falls. It only reaches Mud, then Dry, if enough neighboring pumps and levees in the ring are also holding. “Secured” means the player is ahead of the leak, not that physics retired.
6.  **Hold the Ring:** Patch neighbors, kill Purifier wrenches, keep the step from walking back. A late stopped pump is a leak, not an ocean — the improved network is why.
7.  **Expand Logistics:** Establish a forward camp or supply road in a newly dried chain of sectors. Land bridges are how the Vanguard arrive. Early high-point shelters become the sketch for these.
8.  **Sow the Floor:** A dry tile can become a field. People migrate onto land that can feed them. Population does work (research, dredge, roster depth). Food stops being the daily crisis once fields and mouths match.
9.  **Research & Upgrade:** Use scavenged tech to improve weapons, armor, base facilities, and traversal gear. The workshop copies what can be taught. It cannot copy the founder. More people in the old instrument halls make this faster.
10. **The Highland Bill:** A ridge with fields and smoke is a state. Act III is keeping the thing that ended foraging — and meeting the army that noticed.

## 3.1 Modes, Fog, Time, and Shelters

### Squad mode and table mode
Two cameras, one basin. Not two games.

*   **Squad mode (all of Phase 0):** a single team on the map. The squad is the camera. No labor board. No End Turn. Time passes because you walked and because dusk came. Walking is free movement until contact (see Contact and the knock). It is never phased.
*   **Table mode (after the dome is understood):** labor, fields, research, which bowl is ticking. Same map. Live vision only from staffed posts, later radar rumors, and the squad if deployed. Coming home is the switch. You do not build a garage mid-gunfight.

The Citadel is not required to survive the night. It is required to *think like a water board*. Finding it is life-altering because it is the first high point that looks *out*, not just *up*.

### Fog
*   **Unknown:** black. Unvisited bowls.
*   **Known-quiet:** walked before. Terrain and last-seen water step remain. Actors are hidden. A street can grow a wrench or a column.
*   **Live:** squad, staffed watch, or (later) radar heading. You see the present.

Leaving live vision freezes the tile. It does not wipe it.

Water steps may remain visible on known bowls from the dome once instruments work — geography, not faces. Purifiers stay hidden until someone looks.

### Time
One clock: **days**. Mode only decides how a day is spent.

*   Squad mode burns the day with feet and fights. One deployment ≈ travel + fight + dusk. Walking, boat legs, knocks and fights all spend the day. How much each spends is tuning (§10). If travel were free, one day could tour the basin and dusk would be fiction.
*   Table mode spends a day when you sit (next day / clock in the dome).
*   **Creep, fields, Vanguard march, research tick at day end, never mid-fight.** Mid-combat water is the tile under your boots, except a chosen redirection.
*   If the squad is out at dusk they camp a marked roof or the boat. They do not snap-home by default. The day still closes. Known-quiet updates where they were not.

Night is a habit these people already have. Wake-Riders own canals after dark. A bleeder on a raft is a bad idea. Miss the habit and the fight is worse, not over.

### Contact and the knock
*Working default. Prototype in one bowl, then lock.*

Squad mode is not phased. Walking, swimming and boating are free: no AP coin, no End Turn, no Watch. Phases start on the same map when contact happens. Seeing is never contact.

Contact starts when:
*   a hostile has a clean line on a squad body; or
*   the player acts: fires, knocks a shelter, or starts a machine on a tile with a Live hostile.

A meeting is never contact. Once phases start they run until extract, until no hostile holds the street, or until dusk forces a camp.

Contact is one-sided on purpose. If the squad's own line started fights, contact range would depend on loadout, and spotting a camp then turning the boat around would stop being a choice.

**The knock.** Occupants were always there. Nothing spawns at the knock. People on a roof deck see the approaches, so walking into their line is contact before any knock. People inside see nothing until the knock. Surrounding an interior is legal, and it spends daylight.

### The boat camp
Home until the Citadel exists. It moves. It is small and wet. A bad place to spend dusk with a casualty.

The boat is a place on the tactical map, not an off-screen menu. It is where the squad started, where MEDEVAC leaves from, and where dusk is spent if no roof is marked. Wake-Riders can take it from a roof (5.11): that is a mission-state change and a bad day, not the end of the camp. What a taken boat costs — a walk home, a fuel loss, a leg on foot — is tuning (Section 10).

### High-point shelters
Exploration that pays the long game. Rooftops, overpass piers, parking decks, church lofts — floors the water has not taken today.

States: *unseen / slept once / marked*. Not a second Citadel. A night you can afford away from the boat.

**Risk / reward when you first commit to a roof.** You do not know which until you knock.
*   **Empty.** Quiet night. You mark it. Cheapest outcome, least human.
*   **Occupied by normal people.** Other survivors in the same weather. A meeting, not a loot screen. Possible food, a name for the later roster, a deck already being farmed. The humanist beat in miniature. The town starts as a conversation on a roof.
*   **Occupied by hostiles.** Drifters who do not share, Wake-Riders nesting, Purifiers with a pulpit. Dusk is now a fight you chose.

A friendly roof is later the easiest place to offer a post. A cleared hostile roof is still a marked roof — empty of people, useful. Sometimes you turn the boat around.

Later the same marked roofs become waystations (MEDEVAC), watch posts, boat caches, shoulder fields, or Act III forward camps. Phase 1 map-work is the infrastructure sketch. Marked roofs do not reset when the dome turns on.

Marking a roof as a labor post later still costs a person. Sleeping there does not auto-staff it.

### Vision research
*   **Roof eyes:** a posting. Live vision on that tile. Person not in the boat.
*   **Watchtower:** built on a dry rim. Longer sight. The observatory’s original job, copied.
*   **Radar:** late. Movement on known-quiet land — a heading, not a face. Does not replace a drop.

## 3.2 Campaign Structure: Phases, Acts, and Triggers
Earlier versions used *phase*, *act*, and *chapter* loosely. From here on, **phases** describe the base, **acts** describe the campaign, and "chapter" is not a term. They map like this:

| Campaign time | Where you live | Camera | Base phase |
|---|---|---|---|
| Opening | The boat | Squad mode only | Phase 0: The Boat |
| Act I | The penthouse, waking | Squad mode plus the first table verbs | Phase 1: The Penthouse |
| Act II | The descent | Table mode is real; founder optional | Phase 2: The Descent |
| Act III | The compound becomes possible | The Vanguard on the floor | Phase 3: The Compound |

**Triggers.**
*   **Opening → Act I:** the dome is found by walking. It is not scripted. If the player wanders away from the ridge, the Citadel stays a rumor.
*   **Act I → Act II:** the first terrace ring reaches Dry and the player holds the dome, even if its gauges are still waking.
*   **Act II → Act III:** either a player-made land bridge points toward the ridge, or the highland notices smoke: a hidden threshold of population plus at least one field. Act III does not require the player to build a bridge (see Turtling).
*   **Phase 3 (the Compound)** unlocks when the inner ring, meaning the terrace plus the first floor ring around the ridge, is Dry. The whole basin does not need to be dry. A wet moat chosen at the edge does not lock out garages.

**Turtling is allowed.** The Vanguard are masters of dry. Without a player bridge, no heavy column crosses the sump; they do not swim an army. A player who stays small on the terrace gets a late Act III or none: a small town, no highway, a legitimate way to play. A player whose town grows loud (the hidden smoke threshold) without building a bridge sees the Vanguard start a **causeway** from the rim. It is visible while under construction; that is the route, told in play. The causeway is a target: raids can slow it, and a redirection can drown a stretch of it, with the usual hangover and the Bitter rule in Section 6.6. First contact on a causeway follows Section 6.5.

**Map scale.** One basin: ridge, terrace, floor, sump, and the far rim. "Previously disconnected zones" are bowls behind levees inside that basin, not a second country. Campaign length and sector count are prototype work.

## 4. Strategic Layer (Base & Logistics)
### 4.1 Base Building: The Citadel's Vertical Evolution
The player's base physical structure is directly tied to their success in draining the surrounding region. The base evolves in three distinct architectural phases. The founder’s *job* rides the same elevator as the building.

*   **Phase 0: The Boat (before the dome):** Squad mode only. Moving camp. High-point shelters. The founder is folk literacy on a wet plate. Night is a habit. The Citadel is a rumor on a ridge, not a checkpoint.
*   **Phase 1: The Penthouse (High Water):** After discovery. The player has the dome and the upper labs. Space is agonizingly limited. Hard choices about which basic facilities (rudimentary med-bay vs. ammo press) to build. Table mode arrives as systems wake, not as a switch.
    *   *Instruments start dead.* Building first — glass, a view with your eyes, dark gauges. Bowls are still known by walking. Feed the campus over time: terrace power, a hall cleaned, a pump on the slope. The graph becomes knowable in pieces. First Gauge meeting its original tools is earned. Not a dumped water-board. Not a buried Act II tech node.
    *   *You arrive few.* Boat-camp numbers. A handful can only do and figure out so much before more people show. Waking the Citadel is limited by hands as much as by scrap. Halls stay dark because nobody can spare the day. Table verbs appear as the pool grows — research, watch, dredge — not because a menu unlocked. The campus waits on the same finite people as the fields.
    *   *Founder role:* Still no engineering staff. The founder is almost always on the boat when something matters. The Call is thin. Literacy meets tools only as those tools wake.
    *   *Water:* First finished rings are the terrace — high pocket, small ring. Look over the edge and the sump is still a lake.
*   **Phase 2: The Descent (Draining the Inner Basin):** As the player successfully activates pumps in the zones immediately surrounding the Citadel, the local water level drops. This physically exposes the lower floors of the base. The player must spend resources to "dredge and sanitize" these newly exposed, moldy floors, unlocking vast amounts of internal real estate for advanced facilities (hydroponics as a stopgap, research labs, heavy workshops).
    *   *Founder role:* The workshop comes online. Recruits can be trained into Pioneers who handle routine hatches and overrides. The founder can sit a mission out. Taking them is for gold-rush panic, ugly water, or a squad that will fold.
    *   *Water:* Drying the terrace and the next ring down exposes campus floors and the road that used to be a car park. The true cellars wait on the sump. Neighbors still leak downhill.
*   **Phase 3: The Compound (Dry Ground Expansion):** Once the inner ring (the terrace plus the first floor ring around the ridge) is Dry, the player is no longer constrained by the building's footprint. They can expand horizontally onto the dry ground. The rest of the basin does not need to be dry; a wet moat chosen at the edge does not block this phase. This late-game stage allows for massive external add-ons like Vehicle Garages (essential for late-game travel) and Heavy Munitions Factories. Defense is forward, not at the glass: posts and forward camps on the floor hold the push out in the polders. There is no siege minigame on the dome. A column on the terrace or slope is a civic lose (Section 6.6).
    *   *Founder role:* Everyday engineering has been copied. Vanguard streets do not care about a 2019 service manual. The Call is at full weight because the roster has watched the founder do impossible things. Deploying is usually expensive and occasionally correct — first contact with the Vanguard, a FOB assault, a scarred Overwatch who will not cross an open avenue unless the founder is on the tile.
    *   *Water:* A stopped pump is a leak, not a new ocean. Redirection becomes a desperate late option (Section 6.4).

### 4.2 Logistics Management
**Currencies (closed list).** Four, plus the clock. No fifth bar. Biomass is food or scrap, not its own pile.
*   **Food** — mouths; surplus you spend (sit a day, MEDEVAC, help, dredge).
*   **Fuel** — boats, later vehicles, how far the one fireteam goes. Sources: diesel caches salvaged in Flooded and Mud; later a still (boat-side, then dry-side) that turns scrap and time into fuel. No infinite well.
    *   *Knowable, like water.* Before committing to a leg the player can learn what it costs and whether the fuel left still reaches home. Running dry is a decision that was available to read, never a surprise on the way back. Same clause as 6.1, pointed at the other travel currency.
*   **Scrap** — workshop, dredge, kit, feeding dead instruments, pump upkeep. Consumables (ammo, trauma kits, smoke, barricade charges) are crafted from scrap and sometimes fuel. The ammo press is a building that turns scrap into charges. Consumables are items, not a fifth bar.
*   **People / time** — the finite pool and the day. Labor is people. The day is the clock.

**People and the roster.** The boat camp starts with more people than the fireteam (working default: roughly 8–12; four deploy, the rest are the camp). The roster is a subset of the population. A roster death shrinks the pool. Barracks cap how many people can train as soldiers, not how many people exist.

Travel: flooded = boats (fast, small). Mud = slow, eats food, risky. Dry = fast, heavy possible.
*   **The Threat Radius:** As the player expands outward, they attract the attention of harder factions from the deep basin and the highland borders, requiring posts and forward camps to safely extend supply lines.
*   **Supply Lines and Medical Extraction:** The logistical network is what keeps soldiers alive. Establishing strong supply lines, waystations, and clear transport routes is crucial. These networks dictate how quickly an injured party member can be rotated out of combat and transported back to the Citadel for treatment. A poor logistical network means longer transport times, increasing the risk of death or permanent scarring. A sector that has crept back toward mud turns a dry road into a ration-eater again.
*   **The Empty Chair (soft tax):** When the founder deploys, the Citadel runs slower that day — research, radio, or how readily the one fireteam can be sent. A cost, not a lockout. Stay-home is the late default without forbidding the field.

**Stay-home is a command shift, not End Turn.** Act III must not feel like the avatar retired from the game just as the Vanguard arrive. Table days have verbs. The founder is on the instruments.

Table-mode decisions on a day the founder stays. The budget is one day: a handful of assignments (labor moves, research, mail) plus one dispatch or no dispatch. It is not an action-point minigame, and you do not do all of these:
*   **Dispatch the fireteam** without the founder. Choose up to four from the bench, choose the bowl, pay the day. The player plays that tactical map. "Not in the street" means the founder's body stayed home, not that the fight auto-resolves.
*   **Read the graph.** Which feeder is pouring. Which bowl is walking. Authorize a patch or let a posting hold.
*   **Move labor.** Pull hands off a field onto a rim because radar sketched a heading. That is the grumble as a verb.
*   **Answer mail.** A nomad rumor arrived late. Send someone, ignore it, or wait for the mast.
*   **Archives.** Research the column (old language). Unlock kit, not a cutscene.
*   **Route the wounded.** Which marked roofs are the MEDEVAC chain today.
*   **Refuse the sluice.** Precise redirection still wants the body on the gauge. Staying home means you *cannot* spend the desperate card today. That is an active no.

What stay-home is not: watching numbers auto-resolve while you mash next day. If a table day has no decision that would change tomorrow’s map, it should not have been a day — it should have been a deploy.

### 4.3 Food, Fields, and People
Survival runs the whole campaign. The *job* of survival changes.

**Food is a problem until the basin feeds the ridge. Then it is infrastructure.**
*   **Terrace / Flooded:** Everything is gathered. Scavenge, rooftop plots, fish, ugly biomass. Every mission is also dinner. Hydroponics in the dome is a bad compromise because there is no dirt.
*   **Floor / Mud:** Fields exist as promises. Falling and Mud are not food yet. You still eat from crates and tanks. The gold rush is calories with a gun in the way.
*   **Dry inner ring:** First real fields. Rations tick up if the tile stays dry and un-ruined. The number begins to go quiet.
*   **Basin dry enough / Act III:** The pantry is solved as long as the land holds. No more forage missions. No more “we cannot leave the ridge because soup.” Attention moves to land bridges, FOBs, the column, whether to spend a sluice. Food only speaks again if a field is burned or a hangover drowns the barley. That is a wound, not a lifestyle.

**Surplus is spendable, all acts.** Extra rations are not a silent “you’re fine” and not a warehouse sim. Spend them: sit a day at the table, stretch MEDEVAC, fund a help-gamble, dredge a little faster, keep a fireteam from turning back for soup. The pile stays modest. People accumulate into the extra — more mouths, more posts, more bench. A fat stockpile means you are not taking people in. That is already a hollow choice. If food is a mountain, the labor board is empty; that’s the tell.

Do not add a farm sim. No soil minigame. A dry tile is one of: *empty / camp / field / ruined / road / post / forward camp*.
*   **Post** is a watch post or a gun post: same tile, labor decides which.
*   A workshop or cache sits on a camp or road tile.
*   A **forward camp** is the player's forward base on the floor: a waystation that extends supply and MEDEVAC, and a target. Vanguard FOBs are the enemy's structures, not a player tile state.

Fields tick on the day clock like everything else.

**People follow the water out.**
Dry land is a magnet. Shanty roofs empty toward the fields. Drifters stop being only recruits and start being families on a street you made. One population number. It ticks up toward whatever the dry tiles can feed. Ruin a field or drown a suburb and some leave or die.

They do work, or they are only a score. Growth is **allocation**. People take jobs that used to be the founder’s panic and the squad’s only outing.

**Labor board (light):**
*   **Pumps / ring watch:** stationed hands keep a held bowl from walking back. The “Hold the Ring” loop becomes a posting, not always a mission. This is how focus leaves Act I survival.
*   **Overwatch posts:** dry sightlines get people on roofs and rims. Not the class — the job. A populated dry tile can see a column coming. The founder does not have to scout every shoulder.
*   **Research:** hands in the old instrument halls.
*   **Workshop / dredge:** floors and compound faster.
*   **Fields:** the food engine.
*   **Roster:** more names, not automatically better soldiers.

You are not unlocking a new game. You are handing the old jobs to a town. Early: the founder is the pump, the lookout, the dinner. Late: those are postings. First Gauge and the ugly fights remain the reason to go out.

A town on the slope is why the Vanguard bother. Twelve wet people on a ridge are a curiosity. Fields, smoke, and a road are a state. Population makes Act III louder on purpose — because you succeeded at being human, not because the script flipped.

No happiness slider, no house placement, no mood management. The choice is *where* they settle: high terrace (safe, small) versus floor polders (food, exposed, on the highway). Act III grumbling lives in writing and in which jobs appear on the labor board.

**Anti-goals (town — out of scope). The player will never be asked to:**
*   Place, upgrade, or decorate individual houses
*   Zone districts or draw roads as a builder
*   Run citizen supply chains, taxes, or shop inventories
*   Manage a happiness / loyalty / piety meter
*   Click every person onto a farm tile each day (labor is a handful of job buckets, not a sim)
*   Breed, name, or family-tree civilians
*   Fight as allied AI armies on the geoscape
*   “Win” by maxing a faction reputation bar

Population is one number. A dry tile has a short list of states (above). Labor is a short board. If a feature needs a civ overlay to explain, it does not ship.

Open: whether late population also costs (MEDEVAC load, mouths if a field dies) or is only upside plus a bigger target. Open: whether incoming camps are automatically yours or sometimes still half Drifter.

## 5. Tactical Layer: Fight Constitution

**Mission loop:** See a sightline → spend AP to change it or use it → someone bleeds or a machine changes → extract.

Keep it simple. Same rules in flood, mud, and dry. The floor changes. The game does not.

### 5.1 The fireteam
*   **Up to four bodies.** The founder may be one of them. The town grows the bench, not the fireteam. A thin fireteam (fewer than four) can still deploy; two bad wipes can shrink you. Roof meetings are the recruit path, not a guarantee. The only softlock is a founder who is alone and cannot walk, which is rare and earned.
*   Phase 0 is the same fireteam on the boat: unclassed basin folk. Everyone in the basin can swim; swimming is a habit, not a class. Classes arrive with survival, training and kit (Section 8).
*   **One fireteam in the field.** One tactical map per day. The boat-camp grammar never retires. Other jobs are postings, ally eyes, or tomorrow. The empty-chair tax makes the one team slower or thinner to send; it never means two streets run before dusk. Table days breathe. Squad days are the street.

### 5.2 Phases (XCOM-style)
All of yours, then all of theirs. No interleaved initiative. Easy to teach. Same structure in every water step.

**Watch (reaction fire).** Phases have teeth. In your phase, a unit can spend AP to watch a cone. In their phase, the first enemy that moves into that cone or acts inside it takes one shot, resolved by the normal rules (deterministic, Section 5.4). One watch, one shot. A Watch cancels if its unit is Pinned before it fires (Section 5.4); the cone is spent, and the preview says so. The enemy uses the same rule during your phase; Vanguard long cones are why open streets are deadly. Without watch, dry streets would be decided by whoever peeked first.

### 5.3 One AP coin
Each person gets a pool each player-phase. Move, shoot, interact, swim, deploy cover, smoke, winch, First Gauge, Echo Call — all spend that pool. Exact digits are prototype work.

*   Mud doubles move cost.
*   Deep water: no rifles / LMGs. Sidearms, melee, spearguns.
*   A mission, a deployment and a fight are the same thing: one day's tactical map.
*   First Gauge: at most once per fight. No campaign cap; its rarity comes from how rarely the founder deploys. Passive reads (the bonus read on plates, veteran eyes) do not spend it.
*   Echo Call: at most once per fight. Witness pulse after First Gauge is short and free of a second spend.

### 5.4 Sight and damage
No RNG half-cover. No 35% dodge.

*   **If the line is clean and the shot is legal, it always deals damage.** Peeking an open dry street is a decision, not a dice roll.
*   **Material is the only 'cover.'** A wood plank or crate may stop a pistol. A rifle or sniper punch through. Deployed Pioneer barriers and smoke *break or block the line*. They do not add a miss chance.
*   **Smoke and deep water** hide a body (no line). Chest-deep Falling water does not.
*   **Pinned** is a state: a unit hit by a shot that does not drop it loses what it is doing. It is not a dodge roll. Suppression means Pinned. Any non-drop hit pins; there is no suppression weapon class. Pinned is required, because the break rule (5.5) uses it. *Working default:*
    *   Hit in its own phase (reaction fire): it stops. The rest of that phase is gone. Pinned clears at the end of that phase.
    *   Hit in the opponent's phase: a live Watch cancels at once and shows spent. The unit starts its next phase Pinned, spends it ducked, and Pinned clears at the end of it.
    *   One hit costs one phase of action at most. Keeping a unit ducked means hitting it again, and one more hit usually drops it. No stunlock.
    *   Same rule for both sides. Vanguard fire strips a player Watch the same way. Pinning does not open a street at first contact: a column has more cones than the squad has spare lines (6.5).
*   Health is low. A clean rifle or sniper shot drops a unit to Bleeding Out. Two clean pistol hits do the same. That is the point.
*   No random rolls anywhere in combat. Scars apply known penalties, not chances.

### 5.5 Break (deterministic morale)
No percentages. A unit is **broken** when any of these is true:
*   the last friend in its squad on this map has dropped;
*   it is pinned and outnumbered in the open;
*   it is unadapted (Drifters, other untrained AI, or the player's raw unclassed recruits) and stands on Dry with CQB kit while a long cone sees it.

A trained Muckraker does not dump the street because it is dry. The player version of the third clause is the Agoraphobia scar (Section 8.5).

**Break, defined.** *Working default. Prototype in one bowl, then lock.* The clauses above lean on four terms. Each is a count or a lookup the player can make from what the screen already shows; none needs the enemy's intent.
*   **Long and short.** Every weapon class is one or the other. **Long:** rifle, LMG, sniper. **Short:** pistol, shotgun, melee, speargun. The same table sorts the cone (below) and the kit.
*   **CQB kit** means every weapon the unit carries is short. One long weapon and it is not CQB kit. This is the "shotguns, machetes, and sidearms" of 6.3.
*   **Long cone.** A loaded Watch cone (5.2) of a long weapon class, with the unit's tile inside it and a clean line to it (5.4). A spent cone does not count. Nor does a long weapon with a clean line but no Watch: the panic is the visible geometry the enemy paid AP for, which the player can see and answer.
*   **Outnumbered.** More standing hostiles have a clean line on the unit than there are standing friends within 3 tiles of it, counting itself. Downed units count for neither side. Friends near you are the protection, so isolation matters and a tight group looks after itself.
*   **In the open.** At least one hostile has a clean line on the unit, and no tile the unit can reach with the AP it holds now is free of a clean line from every hostile that has one. This is the mud line in 6.3, "without AP to reach hard cover," made exact. It is weapon-aware because material is the only cover (5.4): a plank hides a body from a pistol and not from a rifle. Pinned does not zero the AP for this test; otherwise a pinned unit could never reach cover and the phrase would stop meaning anything.

**When it lands.** Break is a state, checked after every action resolves and again at the start of each phase. It takes effect the moment its condition becomes true. A player unit that breaks mid-phase loses the rest of that phase; an enemy that breaks acts on it in its own phase (5.11). Clauses 1 and 3 are facts about the map and are known before the click. Clause 2 also needs the unit to be Pinned, which needs an enemy to choose to shoot, so before the click the most that is knowable is that a unit is outnumbered and in the open where it stands: *if hit here, breaks.*

**Agoraphobia** (8.5) is the third clause with the kit, training and terrain conditions taken off: a long cone sees the unit in the open, as defined here, and it breaks, on any ground.

*   **Broken enemies** flee or drop the gun, per the faction table in 5.11.
*   **Broken player units** lose the rest of the current phase. In the next phase the player still chooses their move, but it must end closer to cover or to the extraction point. They do not auto-flee the map.
*   **Pinned and broken: broken wins.** A unit that is both takes its broken move instead of ducking. Otherwise a pinned break could never reach the off-ramp (5.11).
*   **The Call:** allies inside its radius cannot break.

**Everyone bleeds out.** Bleeding Out lasts 3 rounds (*working default*); a round is one player phase plus one enemy phase. Enemies at 0 HP bleed on the same clock as the roster. A trauma kit stops the clock; from then on, extraction timing follows 8.5. Executing the downed means attacking a bleeding unit. A prisoner is a broken Vanguard unit the player chooses to take instead of shoot, once research into the Vanguard has begun. The founder bleeds out like anyone else; a failed founder extract ends the save.

### 5.6 Objectives, not wipes
Killing is what happens when the thing is contested. Success verbs:
*   **Start / hold / stop the machine** (pump, sluice, override)
*   **Mark / clear the roof** (empty, friendly meeting, or hostile fight)
*   **Get them to the boat** (MEDEVAC; founder-down *becomes* this)

Gold rush: leave with the crate before the third faction does.  
First contact: the street becomes a ditch and you are not on it.  
Fail: squad gone, founder not extracted, you fled and the bowl walks.

### 5.7 Founder on the map
Same AP, same HP, same cones. First Gauge is an interact that changes the map. The Call is a radius on allies. Enemies shoot silhouettes. If the founder drops, the mission type switches to extract.

### 5.8 Water is the class balance
Do not add a new combat system per act.

| Step | Move | Sight | Who is strong |
|---|---|---|---|
| Flooded | swim / boat | short, fog, roofs | Frogman, sidearms |
| Falling | chest-deep, ugly | mixed; no swim-hide | last flanks, first bad footing; Purifiers like this |
| Mud | double AP walk | mid | Muckraker, winch |
| Dry | fast | long cones | Overwatch, Pioneer cover |

Falling is the worst of both: you cannot disappear into the deep and you cannot run.

### 5.9 Water as a medium & reactions
*   Dive to break line of sight in Flooded. Climb out to shoot heavy.
*   Water + stun-dart: localized shock in ankle-deep. Grounds out in deep.
*   Oil + fire on the surface: floating denial.

### 5.10 No priority flag
Enemies do not know the founder is the save. Later, factions that have *seen* the work (especially Purifiers) may learn. The Vanguard shoots doctrine, not mythology — unless a late hunted sequence is wanted.

### 5.11 Flight and truce
Not everyone is a zealot. Tough lives. At some point the fight is not worth it. This is not a diplomacy minigame and not a talk stat. Clean shot still always damages — including a back that is running.

**Off-ramp (earned, not a turn-one button):**
The enemy is broken (Section 5.5), you have not executed the downed this mission, the objective is a machine or a roof, and ideally The Call is in radius. Then their phase can be: peel toward an edge, or a gun hits the floor.

Your phase: **let them go**, **take the meeting**, **take the prisoner**, or **shoot**. Shooting works. The tile remembers.

Take the prisoner is Vanguard-only and appears only once research into them has begun (5.5). Before that the option does not exist, because nobody in the basin yet knows what to ask.

**By mouth:**
*   *Drifters:* the point of this rule. Opportunists. Will peel or talk.
*   *Wake-Riders:* stand in water; may take the boat from a roof. A truce is territorial (“this canal at night”) not a peace.
*   *Purifiers:* almost never. Confusion if a sluice they thought holy moves. Not a handshake.
*   *Vanguard:* first fights — no chat, no peel. Column, cones, gutwrenching. Later, after they have seen a town: withdraw as doctrine, a company that will not take the next street, a cut-off squad that yields a prisoner / a heading. Pieces dislodge. The army does not become yours.

**Outcomes:**
*   *Flee:* you still get the pump or the roof. Less loot than a wipe. They leave this fight. If you meet those people again they are **less likely to engage and more likely to flee**. They learned. The bowl also gets a little kinder (next roof here likelier a meeting) if you let them go.
*   *Meeting / truce:* short. Food, a name, a marked roof, a warning. Later a recruit or a post. Neighbor, not quest hub. The pump must still be yours or it is not a success.
*   *Prisoner (rare, Vanguard):* one fact at the table, then they sit or they walk. No interrogation game.
*   *You shoot the hands-up:* the crate is yours. That tile’s next occupants have heard. Fewer conversations. No mood meter. It also counts toward the hidden harm tally that can make a win hollow (Section 6.6).

A friendly shelter is this sentence before the gun. A mid-fight truce is the same sentence after someone has bled.

**Second meeting — help as risk/reward.**
You let them go. Later the fog goes live and it is *them*: wrecked boat, sick on a deck, a pump they cannot read. Not an auto-recruit. Another knock.

*   **Help.** Costs a day, food, a kit, sometimes a fight that is now yours. If it holds, they convert in the long game: a name on the roster, a labor post, a friendly roof that stays friendly. The town grows from a person you did not finish.
*   **Pass.** They remain unlikely to shoot you. They do not become yours.
*   **It can go wrong.** Ambush wearing a familiar face, a burden that bleeds on the boat, a debt that draws Purifiers. Same gamble as a shelter: you do not know until you commit.

Drifters and tired Wake-Riders become neighbors this way. Purifiers almost never. Vanguard cut-offs become prisoners who talk, rarely townsfolk. One prompt, a cost, a band that remembers. Not a quest tree.

### 5.12 Long-term allies (not an RTS)
A **band** is a group of nomads — a boat, a roof-clan, a family that walks. You meet a face. You are dealing with the people behind them. No faction reputation bar, no allied armies, no attack-move.

**Finite basin.** There is no spawn table that restocks souls. Drifters, roof-clans, tired riders are the same pool that becomes labor, lookouts, roster, fields. A wipe spends the town you have not built yet. Killing helps the mission and taxes the season. That is why flight, truce, and help exist as more than flavor.

**Scale:** the band is the mechanic. Enough warm bands and a pocket defaults kinder. A habit, not a +12 slider. Purifiers and Vanguard do not get a mouth-level habit (highland soldiers are not basin people; cultists are basin people you will almost never keep).

**Early they are nomads.** Trust makes the *band* a lookout, not a tower. Information **moves with them**. If they boat west, their eyes are west.

**Lag until radio.** Rumors arrive late — a day, a dusk, a boat that has to find you. You hear “wrench on the north rim” after the leak has ticked. Research can add radio: a *staffed* post or an ally who touches a mast reports at day start with no lag. Radio nails mail to a place. It does not spawn units. Wanderers still wander.

**Jobs (one per band):** eyes / food / name on the bench / warn. Rare “show up once” in their own bowl. Cap bands per ring. Change of job costs a day at the table and can go cold if you turn a home into a tower they did not want.

**Going cold:** shoot the spared; flood their canal (warn on the sluice — Wake-Riders live in the wet); take the crate they needed; make their roof a gun post they did not ask for. The band goes cold.

**Act III:** some bands go cold because you asked settled people to stand a rim. Map fact, not a bar. No allied Vanguard armies.

## 6. The "Drain" Mechanic & Terrain Evolution

### 6.1 The Graph (how water actually moves)
Sectors are bowls. Levees are rims. Pumps empty *this* bowl. Bowls sit at a grade (rim / floor / sump). Water does not care about a mission-complete screen. It cares whether the neighbor is still pouring in, and whether that neighbor is *uphill*.

Do not simulate liters. Simulate **support**.

Each sector has:
*   its own pump (on / damaged / dead)
*   a list of neighbors that feed it
*   a water step: **Flooded → Falling → Mud → Dry**
*   a leak rate that falls as the local ring and the inner basin improve

A sector can only step down if enough of its feeders are also stepping down (working default: two neighbors, or majority of the ring). One hero pump in a hole in the ring makes a whirlpool and a loud mission, not a dry street.

**Completely dry is a network state, not a sector trophy.**

Players think in rings. How the graph is drawn is out of scope here (see Section 0).

**Knowability (mechanic, not presentation):** the support network is player information, not hidden math. For a known bowl the player can always learn: water step, grade, whether the pump is holding, whether it is being kept, which neighbors feed it, which of those are still pouring, and — if a step is walking — that it is walking and roughly how soon. Known-quiet may hide *people*. It may not hide the last water you had a right to know. A bowl that changes with no way to have seen it coming is a design bug. Dome instruments, once awake, can report geography on known bowls without revealing faces. First Gauge can identify the real feeder when several are noisy. Representation belongs to the UI document.

*Wear is covered by the same right.* A pump dies from neglect (6.2), and neglect is a clock. A pump that fails with no way to have seen it coming is the design bug named above. Kept, thin and failing are all readable states.

*Before the instruments wake.* The right does not begin with the dome. Through the Opening, and through the halls of Act I that are still dark, the same facts are carried by the basin itself: levee marks, gauge faces, pump plates, the water against a wall someone painted a line on. The founder reads more of them than anyone else (8.3). This is the one place the rusted hybrid text (Section 2) is load-bearing rather than flavor, and it is why the Opening is playable without a table. What a plate can say is bounded by what a plate could know: a plate reports its own machine and its own bowl, never the ring.

### 6.2 Creep, not snap
When a pump dies or a levee opens, water walks back. It does not instantly reset the tile to ocean — not once the region has been improved.

*   **Early / outer wild bowl:** leak rate is high. The same Purifier wrench and Flooded is climbing the walls by nightfall.
*   **Late / inner improved ring:** leak rate is low. Dry ticks toward Mud over days. You have a repair window. Miss it and you get mud and a smaller mess, not Act I again.

Motivation: the pumps were fixed *and* the overall state improved. A stopped pump is now a leak, not a flood. “Secured” means *we are ahead of the leak*.

**Late leak cap (soft).** One ignored late pump: Dry walks to Mud and *stops* if the rest of the ring holds. The seriousness is crops. Mud kills fields. Less food, thinner surplus, mouths you already took in. Not Act I ocean.

Several feeders dead, or the sump’s pump dead *and* uphill still pouring: that bowl can keep walking, slowly. The sea can still win *a* low bowl. It cannot refill the whole inner basin from one wrench. Redirection is the other way a finished street goes wet. Civic lose is the low ring walking while you were only an army — lost harvest, cellars, not one muddy road.

Repair is a first-class loop beside assault:
*   **Assault:** take the station.
*   **Hold:** keep it coughing while the step creeps down.

**Hold is maintenance, not a Tuesday cadence.** Pumps die from wear if they are not kept. Posted hands + scrap (and sometimes food/fuel to reach them) are the upkeep. Skip it long enough and the pump breaks — then the late leak cap applies (Mud, crops). There is no “5pm Purifier spawn.” Purifiers are a *person* with a wrench. They prefer a pump that is already thin. Neglect makes sabotage cheap. A watched, fed pump is boring to break and expensive to reach. Wear is the clock. People are the optional disaster.
*   **Patch:** a neighbor died, this bowl is gaining centimeters, go now.

Gold rush fires on the way down. If the player is sloppy it can fire on the way up again — use that sparingly.

### 6.3 Water steps on the ground
*   **Flooded (The Surface)**
    *   **Environment:** Traversal by boat or swimming. High verticality (rooftops, bridges). Water provides ample routes for stealth and flanking.
    *   **Combat:** Close Quarters Battle (CQB). Shotguns, machetes, and sidearms rule. Long-range visibility is poor due to fog and structures.
    *   **Enemies:** Scavengers and Wake-Riders are at their strongest here.
    *   **Founder:** Almost always on the boat. Unique water-work is common. The Call is small.

*   **Falling (One pump, ring still leaking)**
    *   Water has dropped. Rooftops feel taller. Streets are chest-deep. Not yet the full gold rush — the tease. Buildings are rumored, not reachable.
    *   **Combat:** Worst of both. No dive-to-hide, no dry sprint. Purifiers like this step.

*   **Mud (The Gold Rush)**
    *   **Environment:** Enough of the ring is holding. Water is no longer deep enough to swim in to break line-of-sight, but too thick to walk through easily. Movement AP costs double.
    *   **The Gold Rush Mechanic:** Exposing untouched pre-collapse buildings acts as a dinner bell. The player must launch tactical missions into the mud to race rival factions (like The Drifters) trying to steal high-value salvage. You are not clearing an empty map; you are actively competing with opportunistic looters.
    *   **Combat:** Sluggish, brutal 3-way fights. Getting caught out in the open mudflats without AP to reach hard cover is a death sentence. Players must rely on winches, deployable platforms, or holding high ground to survive.
    *   **Founder:** Optional. Pioneers can crack most routine machines. The Call matters in three-way panic. Unique trait is for the ugly pump, the real leak in the ring, or the levee that will drown two basins if the read is wrong.

*   **Dry (Reclaimed Ground & The Vanguard)**
    *   **Environment:** Ground floor, basements, and subway networks accessible. Traversal is fast. High-value pre-collapse tech can now be excavated safely.
    *   **The Preservation Gradient (Loot Scaling):** Depth plus time. The sump and old peat were underwater the longest — rust, sludge, ruined caches. The starting terrace is middling: high enough to rot in shallows, not highland-clean. As you push out and up toward the far highlands, pre-collapse equipment is in pristine condition. That un-rusted kit is essential for the late game. The observatory’s own deep guts are a special case: high building, flooded from below until the sump drops.
    *   **The Fatal Funnel:** Draining the water removes the natural barrier, opening the borders to adjacent bowls that levees had kept apart (still inside the one basin). Open streets provide no natural cover, creating massive, deadly sightlines. A *chain* of dry-enough sectors is a land bridge.
    *   **The Agoraphobia of War:** Factions that have lived on cramped rooftops and boats for a generation are terrified of vast, open dry land. Scavenger AI will panic, stick to building edges, and use ineffective CQB weapons.
    *   **The Same Fight, Drier:** Loadouts change with the water. That is evolution of the loop already taught (terrain decides the kit), not a late-game genre swap. Wetsuits and shotguns fade. Long-range ballistics, deployable cover, and smoke come forward. Frogmen are not deleted — they wait on the posts and on the day you spend a sluice.
    *   **The Vanguard Invasion & FOBs:** The Military Remnant takes immediate advantage of land bridges, not of a single dry tile. They roll heavy armor and construct FOBs. If the player does not launch siege missions to destroy these FOBs, the Vanguard begin organized assaults against supply lines and the Citadel.
    *   **Founder:** Usually upstairs. The Call is the reason to drop. Unique engineering is rare and campaign-shaping when it appears — first contact included.
    *   **After it dries:** the tile gets a job — road, field, camp (workshop/cache), post, or forward camp. Empty dry land is an invitation. Mud was a gold rush. Dry is a harvest you can lose.

### 6.4 Redirection — rare late option with a hangover
Putting the sea back is **not** a core verb. Dry is the campaign. Wet-again is a temptation the map may offer when a land bridge is about to become a highway.

*   Not a Flood skill tree. Not a weekly chore. Frequency: rare on purpose. One planned inundation in a campaign feels like a story. Three feels like a system. Eight is a different game.
*   The player spends stored dryness. Open a sluice, reverse a pump, cut a levee on purpose. Water creeps *where it was pointed*. Speed depends on how healthy the ring is. Precise in a mature network. Reckless in a half-fixed outer bowl is how you flood yourself.
*   Constraints: the target sector walks one step wetter and stays there for days (loot access, vehicle road, a FOB you wanted). Creep can overshoot into the next bowl if ignored. Precise redirections want the founder on the map. You cannot drown the highlands. You can drown a bridge.
*   **Knowable before it is spent.** 6.1 covers water the player did not cause; it also covers water they are about to. Before committing, the player can learn which bowls step wetter and by how much, whether the creep can reach the next bowl, roughly how long the target hangs wet, and what of theirs is standing in it — roads, fields, camps, posts. The card is meant to be a hard choice, not a blind one. A regretted sluice should be a decision the player made, not a consequence the map withheld. Precision still depends on the ring: a mature network previews tightly, a half-fixed outer bowl previews as a range and says so.
*   Cost is shared. Vanguard APCs and sightlines die. The player’s Overwatch kit and dry roads die with them. Frogmen matter again. Drifters and leftover Wake-Riders treat the new canal as home. Purifiers notice a sluice that moved.
*   The first-contact sluice (6.5) is authored panic and never counts toward a Bitter win. Any later redirection whose tile is still hanging wet at the end does (Section 6.6).

**Unwanted wet** stays Purifier leaks and neglected neighbors. The player is not the only person who can make a street wet. They are the only person trying not to — except on the day they break their own rule.

### 6.5 First contact: the desperate card
The first Vanguard fight is how the player learns both the faction and the tool. The first land bridge (or the causeway, for a turtling player) is authored enough that a usable gauge is always within reach.

The player has spent the campaign learning that dry is safety. A land bridge opens. Something heavy rolls onto a street they thought they owned. The kit that owned flood and mud does nothing. They think these are Drifters with better coats until the sightlines go wrong.

Redirection here is not clever. It is panic with a gauge. The map offers the sluice because the street will not be won as it is. First Gauge fires because the alternative is the save file on asphalt. The Call is “get off the road, the road is about to become a ditch.”

They win. Sort of. Trucks stop being trucks. The sector takes a step back toward mud. The hangover starts.

**The week after does the teaching:**
*   The tile is not Flooded. It is worse than it was. Creep, not snap.
*   A supply road they liked is slow again.
*   Purifiers notice the handle.
*   The next Vanguard contact is on the *rim*. They waited. They do not park in the ditch twice.
*   The founder was on the map. Hands on the machine.

**If first contact is lost.** If the squad loses the fight but extracts, the column stays where it is, the hangover may not fire, and Act III has simply started the hard way. If the founder goes down and is not extracted, it is the personal lose, as always.

After first contact, redirection stays in the deck with a memory attached. It is not how every Vanguard mission is solved. Second fight: still fierce. Bring Overwatch and cover. Do not drown the suburb again unless the hangover is worth it. They still think they fought a raid that got lucky with a sluice.

**They evolve later.** For a generation they fought boat-gangs coming up the grade. That script runs until it cannot. After enough streets that have fields on them, after a prisoner sits in a compound that is not a nest, pieces of the Vanguard dislodge: a company waits, a squad yields, an order is not taken. The player still has to *beat* columns. The humanist crack is time and evidence, not a speech on contact day.

The last fight sitting on the floor is why peel is thinkable. “Why are we in someone else’s barley?” is a sentence a soldier can finish. A bundled siege on the dome is not — doctrine holds when everyone is packed against a wall. Spread across farms, the raid script has room to fail. Geography does that work, not a speech.

Hangover social is story and labor, not a meter.

**Naming them.** Not on first contact. That fight is “soldiers,” “the column,” “highland kit.” The name — and later a partial philosophy (reclaim a dead basin, boat-folk as raiders) — comes out of research: archives, maps, a prisoner, a cadence on a plate. Learning how to beat them *is* learning what they think they are doing. Over time. Not a briefing. Not a finished worldview ten hours early. Enough to fight smarter. Not enough to complete the plot.

### 6.6 Campaign shape and finality
The game ends when the highland war resolves, not when every tile is a garden. A living polder with a wet moat you chose can be a victory. A perfect map with nobody left to eat the bread is not.

The ending is computed from hidden counts. There is no score screen and no UI for them. The ending line is the town the player can see.

**When the push has broken.** Act III must already have started. Then either:
*   several consecutive days pass (tuning) with no Vanguard FOB, and no column on a land bridge or causeway pointing at the terrace; or
*   the in-basin Vanguard force is spent, because the rim trickle has run dry.

One quiet day between waves is not credits. The check looks at the terrace and those bridges, not at fields: burning your own barley to unsit a FOB does not satisfy it.

**Working vs. hollow.** A win is working only if all three of these hold. Miss any one and it is hollow.
*   **The pool, both halves.** Your own people are still at least two-thirds of the highest population you ever had (working default). *And* harm to other basin folk stayed under a line. Harm counts only where an off-ramp was actually open and you closed it: shooting units that had yielded or were fleeing, or clearing a roof by wipe when a meeting was on the table. Purifier pulpits and hostiles that never broke do not count against you. Cross the harm line and the win is hollow even if your labor board looks fat.
*   **A door left open.** At least one warm band *and* at least one Vanguard dislodge during Act III (a squad that yielded, a company that waited, an order refused). A single kind roof from week two is not a philosophy. Act III guarantees contacts where a yield is possible (cut-off squads, units standing in someone's barley), so this is always reachable. A Vanguard withdrawal the player could have punished and chose to allow also counts as a dislodge.
*   **Land that feeds.** On the inner tiles that were Dry when Act III began, fields plus camps must be at least posts plus forward camps.

**Bitter.** A win is also bitter if a redirection other than the first-contact sluice still has a hanging wet tile at the end. The first-contact card was authored panic and never makes you bitter. Hollow and bitter can both be true: hollow takes the label, and the ditch is still on the map. Bitter alone means neighbors kept, land spent.

**The outcomes.**
*   **Working win:** the push breaks in the basin, on the floor, before the slope. Fields hold. The observatory is still a farm and a gauge. Force happened. It was not the whole sentence. Some Vanguard pieces dislodged. People remain to run the pumps. You do not take the war to their rim. They do not reach the dome.
*   **Hollow win:** army-on-army. They break. You stand. Credits. The finite pool paid: roofs emptied, yields shot, no door left open. The ridge is a fort. The town is a barracks. Fields thinner than they should be. You won the war the rim trained. People are how you survive. You spent them. Still a win. Should not feel like one.
*   **Bitter win:** you hold the ridge and drowned a bridge again. People eat. The polder you spent does not come back soon. Neighbors kept; land spent. Not the same as hollow.
*   **Civic lose (founder may still be alive):** the column reaches the terrace or slope, food hits zero before fields exist, or the sump walks back up the hill while you are busy at the wall.
*   **Personal lose:** founder bleed-out, failed extract.

Act III is not one more pump and it is not a different game. The inner bowls are dry enough to eat from, people are posted on pumps and rims, the land bridge is real, and the other height has decided the observatory is no longer a curiosity. When calories go quiet, scarcity becomes time on the bridge, which dry tiles you will ruin, roster mix, and the founder’s neck.

**The town has just gotten good.** Fields work. Kids on a slope that used to be a roof. Labor is pump watch and harvest, not another gold rush. Then a form of bad arrives that the townspeople do not have a word for. Not Drifters. Not water-cult. An army from the dry rim, speaking a language the polders rusted away from. They will not like the next jobs. They settled. You are asking them to stand on a rim with a rifle.

**The founder is the translator.** First Gauge was always literacy — plates, bowls, the observatory’s habit of looking. That literacy now points at the Vanguard. Archives in the dome, NATO-Dutch on their leftover maps, doctrine that still lives in the old language. Research into this faction is not a new meta. It is the same “finish the sentence nobody else can read,” pointed at people instead of pumps. The town can staff the posts. Only you can tell them what is coming and what kit will matter.

Evolution, not a twist:
*   Same loop: go out, hold a ring, read a thing, bring people home.
*   New weight: some labor moves from fields to overwatch posts. People grumble. The humanist story is that they do it anyway, together, because the alternative is the slope burning.
*   New knowledge: excavation / dome archives unlock Vanguard-facing tools (cover, long guns, how a column moves). That is the town learning, not the game swapping genre.
*   The Call late is “we just got a life and I am asking you to risk it.” That is why it has weight.

**No twist.** The Vanguard are the bill for a town that worked. Heavier kit, drier street, more to lose because the fields exist. If a late system asks the player to throw away the loop they loved for hours, it does not ship.

**Where the last fight sits.** Neither capital. The Vanguard push into the basin. The town fights on the floor — bridges, FOBs, fields they did not want to stand on. If a column reaches the Citadel, the basin is already dead (civic lose, not a set-piece on the dome steps). Basin people do not want the highland war; they meet a column, get shot at, stay away. No campaign march on the rim. Working win: the push breaks out in the polders, before the slope. Hollow can look the same on a map and cost the people who held those fields.

**No happiness meter.** Reluctance is story: lines, faces, a labor board that now lists rifle posts where a field was. People still take the job. City-builder “keep them happy” does not ship.

## 7. Tech Tree & Research
The research system is divided into two distinct branches. The player must balance investing in immediate survival needs versus risking operations to unlock high-tier pre-collapse technology.

### 7.1 Foundational Tech (Independent)
This branch represents the survivors' ingenuity. It is completely independent of finding rare loot and relies only on the closed currencies (scrap, food, people/time). Biomass is not a separate pile. It focuses on base efficiency, logistics, and adapting to the harsh environment.
*   **Logistics & Traversal:** Upgrading boat engines to burn less fuel, building a still that turns scrap into fuel, researching "Mud-Cleats" to slightly reduce AP penalties in draining zones, or building makeshift bridges to connect nearby rooftops.
*   **Base Infrastructure:** Expanding the Citadel’s capabilities. Upgrading the Med-Bay to heal wounded soldiers faster, building hydroponics (small, bad calories, dome-only: a stopgap until fields exist, never a food win), or expanding barracks capacity (how many people can train as soldiers).
*   **Makeshift Armory:** Crafting rudimentary but effective weapons for the early game (e.g., pneumatic spearguns, reinforced machetes, basic pipe-bombs, and heavy plating for boats).
*   **The Workshop (teaching the possible):** Unlocks Pioneer training and routine water interactions for the roster (hatches, standard overrides, pump start-up). This is how the institution copies the founder’s *job* without copying the founder’s *trait*. When the first Pioneer can complete a hatch the founder used to own, the UI should say so. That is the handoff landing.

### 7.2 Excavation Tech (Dependent/Discovery-Based)
This branch contains all the high-tier, game-changing upgrades. Players cannot simply research these by waiting; they *must* find specific Pre-Collapse Caches, Blueprints, or Hard Drives exposed during the "Draining" or "Reclaimed" phases. Finding a specific artifact unlocks a node on this tree.
*   **The "Eureka" Mechanic:** Finding a pristine military server rack in a drained corporate building might unlock the "Advanced Ballistics" tree: good long rifles and LMGs the workshop can manufacture. Before that, Overwatch works with spotters and whatever long gun salvage provides.
*   **Tactical Hardware:** Deployable kinetic cover (essential for open-street combat against the Vanguard), thermal optics to see through fog/smoke, anti-armor charges for the Vanguard's heavy kit, and advanced trauma kits that reduce scar severity and buy time for extraction. They never cancel permadeath.
*   **Macro-Engineering:** Finding old civil engineering blueprints allows the player to upgrade the Citadel's pumps. This permanently increases the speed at which newly secured zones drain from Mud to Dry, shortening the dangerous "Gold Rush" phase. It also lowers leak rates in held rings.

## 8. Tactical Squad & Character Classes
The player recruits basin folk: named survivors from roofs, boats and meetings, who start with no specialization. ("Drifters" always means the hostile opportunists, never recruits.) A class is training plus kit, not an experience tree that conjures a sniper from nothing. Frogman waits on survival and the right kit. Pioneer is workshop training, after the dome. Muckraker needs the winch and the mud to learn in. Overwatch can be assigned before Advanced Ballistics and uses what exists (a spotter, any salvaged long gun) until the good rifle is found. Because combat relies on terrain and line-of-sight rather than RNG cover, classes are designed around environmental mastery and utility.

The founder is **not** a fifth class. They can take any kit the roster can (Frogman through Overwatch). The power is knowledge, not tools. First Gauge and The Call are the identity. A gun is just a gun.

The peel-off that became the boat camp dumped highland gear to melt into basin life. No heirloom rifle. No starting armor. Rim kit found later is loot like anyone else’s — not a birthright.

### 8.1 Class Archetypes
*   **The Frogman (Water Specialist):**
    *   *Role:* Stealth, flanking, and early-game dominance. Late-game relevant again if the player spends dryness or a ring walks back.
    *   *Mechanics:* Moves through flooded tiles with zero AP penalty. Can perform silent takedowns from the water. Excels with spearguns and suppressed sidearms.
    *   *Weakness:* Cannot equip heavy weapons. Highly vulnerable and lacks utility in Dry zones — until someone puts the street in the ditch.
*   **The Muckraker (Mud/CQB Specialist):**
    *   *Role:* Hazard survival and close-quarters brutality.
    *   *Mechanics:* Ignores the movement penalty of Mud. Equipped with grappling hooks/winches to pull teammates out of danger or drag enemies out of cover. Uses shotguns and heavy melee (sledgehammers).
    *   *Weakness:* Useless at long range; struggles in open-street Vanguard firefights.
*   **The Pioneer (Environmental Engineer):**
    *   *Role:* Line-of-sight manipulation, area denial, and *taught* water-work.
    *   *Mechanics:* Carries deployable barricades to instantly create cover in open streets. Throws smoke grenades to break line-of-sight. Uses elemental traps (oil spills, stun darts for water shocks). After the workshop exists, Pioneers can perform routine commander-era interacts (hatches, standard overrides, hold-the-pump). They cannot aim a living network the way First Gauge can.
    *   *Weakness:* Low direct damage output; heavily reliant on consumable items/charges. Cannot take the founder’s unique trait.
*   **The Overwatch (Sightline Control):**
    *   *Role:* Long-range execution and scouting.
    *   *Mechanics:* Uses sniper rifles and spotter scopes. Can "Overwatch" massive cones of open terrain. Essential for surviving the Vanguard in Dry zones.
    *   *Weakness:* Sniper rifles cannot be fired while treading water or moving through deep mud. Nearly useless in the cramped, foggy conditions of Flooded. A redirected street makes them a passenger.

### 8.2 The Founder (Player Avatar)
The player is a named, customizable survivor who is a permanent member of the war and an optional member of any given squad.

**Deployment is a choice, not a lock.**
*   Phase 0 and Act I (Boat, Penthouse / Flooded): practically required. No bench, no workshop.
*   Act II (Descent / Mud): optional. Correct for riots, ugly water, fraying morale, a ring about to walk back.
*   Act III (Compound / Dry): expensive. Correct when the Call will hold a street, when a once-a-campaign machine will not start for anyone else, or when first contact offers the sluice.

**Customization.** Name, face, and starting kit type. No secret highland loadout.

**Saving.** Ironman is the default: one save that the game writes. "The founder is the save" only bites if the save cannot be reloaded around a death. Difficulty options can come later.

**Death ends the campaign.**
The founder uses the same combat rules as everyone else: true LOS, low HP, no plot armor. At 0 HP they enter Bleeding Out, same as the roster. A teammate can stabilize them. MEDEVAC must get them off the map. If they are not extracted in time, the save ends. The Citadel still has engineers. It does not have the person who can ask a dead turbine for one more cycle.

Roster deaths remain real. Other people scar, retire, or die. Those losses change the next mission (no winch, no swim flank, an Overwatch who will not enter an open street). The founder is the save. The others are the memory.

**Soft tax:** Deploying the founder slows the Citadel that day (see 4.2). Living through a down-and-extract still costs time the Purifiers and the leak clock can use.

### 8.3 Unique Trait — working name: *First Gauge* (aka *The Wet Year*, *Board Memory*)
An unobtainable founder-only trait. It is not a higher engineering stat. Recruits cannot catch up. The workshop cannot teach it.

**First Gauge is literacy at the start and judgment at the end.** Same trait, two reasons to risk the neck. It cements why this person is the founder before there is a barracks, and it remains a reason to deploy them after the workshop exists.

*   **Early (literacy):** These people grew up wet. The founder is the one who can finish `POMP DOOD` without a campus. The boat camp survives because of that, not because of a bunker. When the dome is found, the same literacy meets instruments. The first ring drops because they were on the pump. The save file has a reason to exist before there is staff.

**Optional lore (not a system):** generations back, a piece of the Vanguard splintered. They had been sent down the grade to fight “boat people” and saw they were killing ordinary basin folk. They could not stand it. They left. They could not say where they came from — the rim would have followed the name — so the band buried the origin and kept only the useful things: maps, plates, how a gauge behaves, the old language. Handed down. Silenced. The founder does not need to know. A player may assemble it from hints. If they never do, nothing is missing.

No bloodline reveal, no bonus trait, no speech that stops a column, no reunion ending. Explanation only: why the knowledge already lived in a wet boat, and why the Vanguard were never one slab of killers. Pieces have dislodged before. They can again.

*   **Late (judgment):** The workshop can start machines. The trait does not retire. The jobs that still want it are the ugly ones — which neighbor is the leak, hold this bowl until the second crew arrives, the first-contact sluice, the hangover you have to stop before it reaches the suburb under the bridge, and *reading the Vanguard*. Archives, old maps, the language the town no longer speaks. Deploying the founder is no longer “we have no staff.” It is “this is the sentence only they can finish.”
*   **If they die:** the campaign ends because the basin loses the last person who can read it the way the observatory was built to watch. Not because a high-stat unit left the roster.

*   **What it is:** One impossible water-verb, used rarely (once per fight at most; no campaign cap, because it is rare in the way deploying the founder is rare). The workshop starts pumps. First Gauge makes a bowl *behave*: hold this bowl alone until the second crew arrives; read which neighbor is the real leak; ask a wreck for one more cycle so the ring does not walk back tonight; start or stop a redirection without dumping the next basin.
*   **What it is not:** A hatch every Pioneer will later open. Everyday engineering belongs to the institution. It is not a Flood skill.
*   **Veteran eyes (thin leftover):** Even after Pioneers exist, the founder still *sees* water better — a ghost of flow, a warning before a Purifier breach, a faster read on a lying levee, the tick before a step changes. Observatories look at basins the way they used to look at sky. Not a locked door. A habit in the eyes.
*   **Visible when it fires:** Prefer a map change the player can see (a sluice slams, a path appears, the pump turns over, an arrow on the ring reverses) plus the squad reacting. The myth needs a picture.
*   **Why the roster cares:** “Look at that person doing impossible things.” The trait is the proof that feeds The Call. Morale as witness, not as a rank pip.

Default until decided: one verb with several faces — *make this bowl behave* — rather than three separate traits.

### 8.4 The Call
A founder-only command presence. It scales with what the Citadel has become and with what the squad has *seen*, not with a generic level.

*   **Early:** Small radius. One ally holds. Nobody in a tight bubble panics. A loud wet person.
*   **Mid:** Gold-rush and mud panic are the reason to bring the body. The Call is for the riot, not the schematic.
*   **Late:** Full weight. Hold this avenue. Smoke and move. Do not break. First contact: get off the road. A scarred veteran will cross dry ground if the founder is standing on it.

**How it fires:**
*   **Witness pulse (preferred after First Gauge):** The founder uses the unique trait. For a handful of turns the squad is different — they hold, they cross, they do not dump loot and run. Then it fades. The pump is coughing. The Vanguard is still the Vanguard.
*   **Echo Call:** Once per fight, a non-damage order (Rally / Hold / On me / Open the sluice) that can fire even when there is no machine to touch. Weaker than the witness pulse. Exists so dry-land missions still have a reason to risk the save.

The Call is not an always-on weather effect for the whole map. Presence has a radius. The founder has to be on the street. Allies inside the radius cannot break (Section 5.5).

### 8.5 Survival, Trauma, & Extraction
*   **Lethality:** Health pools are low. A clean rifle or sniper shot without physical cover drops a unit to Bleeding Out. No rolls.
*   **Trauma System:** If a character is reduced to 0 HP, they don't instantly die, but enter a "Bleeding Out" state (clock in 5.5). If a teammate can apply a Trauma Kit and extract them, they survive, but gain a permanent physical or psychological scar (e.g., "Lung Damage: reduced AP in water," or "Agoraphobia: breaks when a long cone sees them in the open"). Scars are known penalties, never a chance roll.
*   **Founder exception:** Same bleed-out rules. Failed extract is not a scar; it is the end of the campaign. A founder who is extracted can take a body scar, but never Agoraphobia or anything else that forbids standing in a cone for The Call. Literacy never scars off.
*   **Founder recovery:** In the med-bay the founder cannot deploy for some days but can still use every table verb (the empty chair inverted). Before the dome, the founder recovers on the boat or a marked roof, slower than a med-bay. The camp can go out without them; First Gauge stays home. The campaign does not freeze.
*   **Medical Evacuation (MEDEVAC):** Simply stabilizing a bleeding out character isn't enough; they need definitive care. This is where logistics comes in. Players can request a MEDEVAC to pull injured operators from the field.
    *   The speed and success of the MEDEVAC depend on the player's established logistics network (Section 4.2). If a team is operating deep in poorly supplied territory, extraction takes longer. A sector that has crept wetter makes the boat late.
    *   While awaiting extraction, the stabilized character is vulnerable and may require a dedicated squad member to defend them, reducing combat effectiveness.
    *   If extraction is delayed too long, a roster character's condition worsens (worse scar or permadeath). If the founder’s extraction is delayed too long, the campaign ends.
    *   Founder-down turns the mission into “get them to the boat.” That is the continue prompt. It is not an escort-the-VIP script from turn one.
*   **The Meat Grinder:** Players must maintain a deep roster. Sending a team of top-tier Frogmen into a newly dried zone against the Vanguard is a recipe for a total squad wipe. Sending the founder into that same street without a reason is how saves die. Sending only Overwatch onto a street you just redirected is how the hangover gets personal.

## 9. Decisions locked this pass
*   The player is a deployable founder, not only a commander cursor.
*   Founder death (failed extract from bleed-out) ends the campaign.
*   Roster permadeath and scars stay in force.
*   Unique engineering is a trait others cannot obtain. It is not a stat lead they could close.
*   The workshop teaches the possible. First Gauge is the impossible — make a bowl behave.
*   First Gauge is literacy at the start and judgment at the end. Same trait, two reasons to risk the neck.
*   The Call grows as the Citadel grows and as the squad witnesses the trait.
*   Enemies do not priority-target the founder by default.
*   Deploying the founder has a soft Citadel tax, never a hard lockout.
*   Sectors are a hydrology graph. Dry is a network state.
*   Water walks (creep). It does not snap back to ocean after the region has improved.
*   A late dead pump is a leak, not a flood.
*   Putting water back is a rare late option with a hangover, not a core loop.
*   First Vanguard contact is a desperate redirection. The founder is on the gauge. The week after teaches the cost.
*   After first contact, Vanguard wait on the rim. They do not park in the same ditch twice.
*   The landscape is Dutch-style lowland with one honest height in the middle (research ridge / observatory) and a highland wall at the edge. Not an alpine range.
*   First playable polder is the terrace on that ridge: high, few pumps, water runs downhill.
*   Strategy heights are rim / floor / sump. Water prefers downslope. Hangover from a high redirection can land on the bowl beneath.
*   In-world language is a Dutch–English hybrid on environmental text only. UI, briefings, and voice stay readable English. Not a mechanic. Not a gate. First Gauge may add a bonus read on plates.
*   Survival runs the whole campaign. Food is a problem until the basin feeds the ridge, then it is infrastructure. Act III is not foraging.
*   Dry tiles can be fields. People migrate onto land that feeds them. Population speeds research, dredge, and roster depth, and makes the Vanguard treat the ridge as a state.
*   No farm sim. Dry tile states: empty / camp / field / ruined / road / post / forward camp.
*   The campaign ends with the Vanguard war, not with 100% Dry. Founder death is the personal lose. Famine and the ridge falling are civic loses. A force-only victory is a hollow win: map held, people spent, town became an army. Still credits. Should not feel like a triumph.
*   Humanist throughline: people gathering to solve a problem. Hardship is real. It is not the point.
*   Population growth is labor allocation (pump watch, overwatch posts, research, fields, roster). Jobs leave the founder and the emergency squad and become a town.
*   Act III is evolution of the same loop under more weight. No genre-swap twist. The Vanguard exist because the town worked.
*   After the town settles, people will not want the next jobs. Reluctance is story only — lines, faces, posts that used to be fields. No happiness meter. No city-builder mood management.
*   The founder’s old-language literacy is how the Citadel researches the Vanguard and learns how to face them. The town staffs the posts. The founder names the threat.
*   The campaign starts outside the Citadel on a moving boat camp. Squad mode is all of Phase 0. The dome is a life-altering discovery, not a survival key.
*   Fog: Unknown / Known-quiet / Live. Actors hide on known-quiet. Terrain and last water step remain.
*   One clock: days. Leaks and fields tick at day end, never mid-fight. Night is a habit. Dusk on open water is a worse fight, not game over.
*   High-point shelters (roofs, overpasses) are exploration that persists: later waystations, watch posts, caches, forward camps. Not second Citadels.
*   First use of a shelter is risk/reward: empty, friendly survivors (meeting / possible recruit), or hostiles (a fight you knocked on). You do not know which until you commit.
*   Tactical constitution: up-to-4-person fireteam, XCOM phases (all yours then all theirs), one AP coin, clean shot always damages, material/smoke/water are the only line-breakers. No RNG cover.
*   Missions succeed on machines, roofs, and extracts — not on wipes as the default goal.
*   Town grows the bench, not the fireteam size. One fireteam in the field; one tactical map per day. Postings and ally eyes are the other jobs, not a second fight.
*   Falling water: no swim-hide, no easy run. Worst of both.
*   Flight / truce is an earned off-ramp, not a diplomacy layer. Drifters peel or talk; Purifiers almost never; Vanguard withdraw. Letting them flee makes that group less likely to fight you next time, more likely to flee again. Shooting the hands-up works and is remembered.
*   Second meeting with people you spared can be a help-gamble: cost a day and kit to convert them into long-game allies (roster / post / friendly roof), pass and stay strangers, or walk into a bad surprise. Not a quest tree.
*   Allies are not an RTS. A band is a nomadic *group*. Early lookouts walk; rumors move with the band and arrive late until radio. Radio speeds mail to a mast; it does not spawn armies. Cap bands. No faction reputation bar.
*   The basin’s people are finite. They are the future town. Wipes spend that pool. Killing is a mission tool and a seasonal tax. No respawn. A cleared roof stays cleared of those people. Vanguard arrive from outside; they are not the basin refill.
*   Watchtower → radar is labor + research. Radar is a heading, not a deleted fog.
*   Vanguard first fights are fierce and unreadable as people. They expect raiders from the wet. Over later contacts they see a town; pieces may dislodge (wait, yield, refuse an order). The army does not become an ally. No reputation bar.
*   Optional lore only: the founder’s band descends from Vanguard who splintered after refusing to keep killing basin people. Origin was silenced; knowledge was kept. Highland kit was dumped to melt in. Hints possible. Zero mechanical effect. Not an ending.
*   Founder loadout is any kit. Identity is literacy and The Call, not a unique gun.
*   No plot that can be finished ten hours early. Lore does not unlock an ending or a bonus. Hints may stay unfinished. No bloodline speech, no redeemed-army finale, no genre swap.
*   Moral physics, not a moral meter. Good is a town that can still do Tuesday. Force is expensive, not forbidden. Hollow win is army-on-army that spent the finite pool.
*   Story is told in play and place. No required cutscenes or lore dumps. Hints optional. A player who only fights and drains still has the complete game.
*   The water graph is knowable: step, grade, pump, feeders, whether a step is walking. Not hidden math. How it is drawn is not in this document.
*   Stay-home days have command verbs (dispatch fireteam, read the graph, move labor, answer mail, archives, refuse sluice). Not an End Turn screensaver.
*   Town anti-goals: no house placement, no happiness meter, no civ supply chains, no allied RTS armies, no per-citizen clicking.
*   Currencies are food, fuel, scrap, people/time. No fifth bar.
*   Hold-the-ring is wear and maintenance (hands + scrap). No Tuesday spawn clock. Purifiers exploit a thin pump; they are not the timer.

**Locked in 1.5:**
*   This document is the mechanical foundation. UI, art, audio and other presentation live in separate documents.
*   Endings are computed from hidden counts; the player never sees a score. The push has broken when Act III has started and either several consecutive days pass with no Vanguard FOB and no column on a bridge or causeway toward the terrace, or the in-basin Vanguard force is spent.
*   A win is working only if all three hold: your population is at least two-thirds of its peak and harm to other basin folk stayed under the line (harm counts only where an off-ramp was open); at least one warm band and one Act III dislodge exist; and fields plus camps are at least posts plus forward camps on the inner tiles that were Dry when Act III began. Miss any and it is hollow.
*   Bitter means a redirection other than the first-contact sluice left a hanging wet tile. Hollow outranks bitter when both apply.
*   Phases describe the base; acts describe the campaign; "chapter" is retired. Opening/Phase 0 boat → Act I penthouse → Act II descent → Act III compound and Vanguard.
*   The dome is found by walking. Act I → II when the first terrace ring is Dry and the dome is held. Act III on a player land bridge toward the ridge, or on a hidden smoke threshold (population plus a field).
*   Turtling is allowed. Without a player bridge, a loud enough town makes the Vanguard build a visible causeway, which can be raided or drowned.
*   One basin. "Disconnected zones" are levee-bound bowls inside it.
*   A mission, a deployment and a fight are the same: one day's tactical map. The player always plays it, founder present or not. A table day is a handful of assignments plus one dispatch or none.
*   Fuel comes from salvaged caches and a still (scrap plus time). Consumables are crafted from scrap. Still four currencies.
*   The roster is a subset of the population; roster deaths shrink the pool; barracks cap trainees, not people. Fields tick on the day clock; there are no calendar seasons.
*   Class is training plus kit. Phase 0 recruits are unclassed, and everyone swims. "Drifters" never means recruits.
*   Advanced trauma kits reduce scars and buy time; they never cancel permadeath. Hydroponics is a small stopgap, never a food win.
*   Combat is fully deterministic. A clean rifle shot drops a unit to Bleeding Out; two pistol hits do the same. Scars are known penalties.
*   Watch is reaction fire: one watch, one shot, same rule for both sides. Pinned is required; suppression is Pinned.
*   Break is deterministic: last friend down; pinned and outnumbered in the open; unadapted CQB on Dry under a long cone. Broken player units lose the phase and must move toward cover or extraction; they never auto-flee. Allies in The Call's radius cannot break.
*   Enemies bleed out too. A prisoner is a broken Vanguard unit taken instead of shot, after Vanguard research begins.
*   Defense is forward: posts and forward camps on the floor. No siege at the glass. Phase 3 needs only the inner ring (terrace plus first floor ring) Dry.
*   First Gauge: once per fight, no campaign cap, passive reads free.
*   The first land bridge or causeway always has a usable gauge. Losing first contact but extracting starts Act III the hard way.
*   The Vanguard in the basin are finite, with a slow rim trickle. Purifiers are finite; new ones come only from neglected rings. Wake-Riders concentrate on the remaining water and become Drifter pressure or a help-gamble when it is gone.
*   An extracted founder can take body scars, never ones that stop The Call; literacy never scars. The founder recovers in the med-bay (table verbs still work) or, before the dome, on the boat or a marked roof. The camp can deploy without them.
*   Ironman save by default. Founder customization is name, face, and starting kit type.

**Locked in 1.6:**
*   Vocabulary, one meaning each. **Pinned** is the combat state (suppression). A **band** is a nomad group the player has met; bands are warm or cold. A **marked roof** is a shelter the player has committed to. Units fighting together on one tactical map are a **squad**. The word "pin" alone is retired.
*   "Break" means only the morale state (§5.5). A band losing trust is "going cold."

**Locked in 1.7:**
*   Squad-mode walking is not phased. Movement is free until contact. There is no End Turn outside a fight.
*   Any non-drop hit pins. There is no suppression weapon class. A Pinned unit cannot keep a live Watch; the cone shows spent.
*   A unit that is both Pinned and broken takes its broken move.
*   Working defaults added in 1.7, not locks: contact and the knock (§3.1); Pinned duration (§5.4); bleed-out 3 rounds (§5.5).

**Locked in 1.8:**
*   The version lives in the document header, not the filename (§0).
*   Knowability (§6.1) covers pump upkeep, and it does not begin with the dome — before the instruments wake the same facts are carried by plates, levee marks and the founder's eye.
*   A redirection is knowable before it is spent (§6.4). Which bowls, how far, overshoot reach, how long it hangs, and what of yours is in the water.
*   Fuel legs are knowable the way water is (§4.2). Running dry is readable in advance.
*   **Take the prisoner** is a named fourth option on a broken enemy, Vanguard-only, after research has begun (§5.11).
*   The boat is a place on the tactical map (§3.1).

**Working defaults added in 1.9, not locks (§5.5):**
*   Long weapon classes are rifle, LMG and sniper; short are pistol, shotgun, melee and speargun. CQB kit means every carried weapon is short.
*   A long cone is a loaded, long-class Watch cone with a clean line on the unit. A long weapon without a Watch does not break anyone.
*   Outnumbered: more standing hostiles with a clean line than standing friends within 3 tiles, counting itself.
*   In the open: a hostile has a clean line on the unit and no tile reachable with the AP it holds is free of a clean line from every such hostile. Pinned does not zero the AP for this test.
*   Break is checked after every action and at each phase start, and lands the moment its condition is true.
*   Agoraphobia is the third clause with kit, training and terrain waived.

## 10. Still open
*   Final name of the unique trait.
*   Exact neighbor count / "majority of the ring" for a step down.
*   Mix rate of empty / friendly / hostile roofs (tuning).
*   Whether Purifiers / Vanguard ever learn to hunt the founder on sight.
*   Which table verbs are available in each act (tuning). The empty-chair tax hits research, radio, and the readiness of the one fireteam when the founder is out.
*   Late population: upside only plus a target, or also a cost if fields die.
*   Incoming camps: automatically yours, or sometimes still half Drifter.
*   Ending thresholds (tuning): how many quiet days mean the push has broken, where the harm line sits, and the hidden smoke threshold that starts a causeway.
*   Starting boat-camp size (working default 8–12), founder recovery days, and how fast the rim trickle runs dry.
*   ~~How visible First Gauge is on the tactical map.~~ Settled in UI/UX 0.4: a map change the player can see, plus the squad reacting. The mechanic stays locked here.
*   Contact and the knock (§3.1): working default. Validate in one bowl, then lock.
*   Day burn (tuning): how much of the day a tile walked, a boat leg, a knock and a fight each spend. Blocks the Opening end to end.
*   After dark: what actually changes at dusk. "A worse fight" is locked; the mechanism is not. Do Wake-Riders appear, gain cones, or own swim tiles?
*   Bleed-out length (working default 3 rounds) and Pinned duration (tuning).
*   Downed bodies: does a downed unit block a line? Working default: it does not, and deep water still hides it (5.9).
*   Break thresholds (§5.5): the 3-tile friend radius, which classes are long, and whether Agoraphobia should keep the Dry condition. Working defaults; validate in one bowl, then lock.
*   What a taken boat costs (§3.1): a walk home, a fuel loss, a leg on foot. Tuning.
*   How tightly a redirection previews in a half-fixed ring (§6.4) — where the range stops being useful and starts being noise.

**Closed in earlier versions:** the late leak cap is soft; dome instruments start dead and wake piecemeal; the Vanguard are unnamed at first contact; the founder may take any class kit; the last fight is in the basin; food surplus is spendable every act; hangover social is story and labor.

**Moved out of this document:** UI/UX, art direction, audio, and other presentation topics (see Section 0).
