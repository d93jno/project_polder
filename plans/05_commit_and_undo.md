# Phase 5 — Commit and undo: what stands, and what the player can take back

**Status:** 5.0 completed; 5.1–5.4 not built. Slices 5.0–5.4 below; §7 decisions locked.
**Tracks:** GDD v1.17 §3.1 (free movement until contact), §5.3 (AP), §5.5 (MEDEVAC, bleeders), §8.2 (Ironman); UI/UX v0.17 §5 (what commits), §3 (mid-fight water).
**Depends on:** Phase 4 (`plans/04_fog_what_the_squad_knows.md`), specifically 4.5: `RevealResult` and `Command.apply_outcome` are the fact this plan spends.
**Goal:** the four tiers of UI §5 (free, reversible, committed, confirmed) exist in code, not only in prose. A move that revealed nothing can be taken back; one that revealed anything stands; the ugly irreversible actions ask once and state their cost. The interface never implies a tier it does not enforce.

---

## 0. Why this, and why not the alternatives

**The boundary exists and nothing uses it.** 4.5 made "did this command reveal anything?" a value (`RevealResult.anything_revealed()`). `fight_view` still applies every command straight into `_state` and keeps no history, so a misclick on a walk is pure loss in a game with no dice, which is the exact thing UI §5 says the interface owes the player a fix for.

**One confirm exists, by hand.** `fight_view._confirm_target_id` implements "this kills a bleeder, click again" for one case. UI §5 lists more: First Gauge, opening a sluice, dispatching, ending the day. Copying the hand-built path per case is the shape plan 1 §0 warned about; the confirm needs to be one mechanism the cases register with.

**State is already branchable.** `CombatState.duplicate_state()` is the isolation guarantee the whole rules layer is built on, and every command returns a fresh state. Undo is therefore "keep the previous state", not "write inverse commands". That is the reason this slice is small, and it must stay that way: an inverse-command undo would be a second implementation of every rule.

**Why not the neighbours.**

- *Interact gizmos* (the hatch, pump house and sluice on the terrace, UI §3 mid-fight water) come next, in `plans/06`. They need the confirm mechanism from here for "opening a sluice", and they need machines authored in a bowl, which the terrace does not have yet.
- *The full fight save* (mid-fight persistence) is the piece plan 4.6 deliberately did not attempt. It is in scope here only as far as undo needs a history, not a file (§4).
- *The MEDEVAC window* rules slice (GDD 1.11) is separate; only its preview's confirm tier is registered here (5.3).

---

## 1. Decisions taken

| Decision | Choice | Consequence |
| --- | --- | --- |
| What undo is | **Hold the previous `CombatState`** | No inverse commands. A history is a list of states plus the `RevealResult` that produced each. |
| What is reversible | **A move whose `RevealResult` is empty** | Exactly `not anything_revealed()`. An act (`was_act`) is never reversible. |
| What a reveal does to history | **It stands, and clears the stack behind it** | Undoing past a reveal would let the player replan with information they were not owed. |
| Where the rule lives | **`rules/`** (`CommitPolicy`), the view only draws it | Principle 3: if the chrome and the rule disagree, the rule wins and the chrome is the bug. |
| Confirm | **One mechanism, registered per action** | The bleeder shot becomes its first registration, not a special case. |

---

## 2. Layout

```
rules/commit_policy.gd            tier_of(command, state, outcome) -> Tier, pure
rules/command_history.gd          the undo stack of states; push, undo, clear_on_reveal
presentation/confirm_prompt.gd    one prompt: the action, its cost, "again to confirm"
presentation/hud.gd               an Undo control, shown only when it can act
tests/unit/test_commit_policy.gd
tests/unit/test_command_history.gd
tests/presentation/test_confirm_prompt.gd
```

`fight_view.gd` routes `validate()` then `apply_outcome()` through the history and the policy. It decides nothing.

---

## 3. Deliverable phases

Each slice ends with `make test` green; `make shots` joins the checkpoint when the HUD changes.

### 5.0 — The tier as a value

**Ships.** `CommitPolicy.Tier` (`FREE`, `REVERSIBLE`, `COMMITTED`, `CONFIRMED`) and `CommitPolicy.tier_of(command, state, outcome)`, where `state` is the one the command was applied to. A command is `CONFIRMED` when `Command.needs_confirm(state)` says so, `COMMITTED` when its outcome revealed anything, otherwise `REVERSIBLE`. Selection, hover, camera and path planning are `FREE` by never being commands.

**Done when.** A table-driven test names every case: a walk through known empty ground is reversible; a walk that peels a cell, triggers a Watch by entry, or enters an enemy line is committed (each separately); a shot, an interact and a throw are committed even with nothing else revealed; a registered confirm action is confirmed.

**What landed.** `rules/commit_policy.gd` (`Tier`, `tier_of`, `is_undoable`) and `Command.needs_confirm(state)`, overridden by `ShootCommand` (the target is a bleeder) and `InteractCommand` (a Trauma Kit). Which actions confirm therefore lives on the command, beside its other rules, and 5.3's `ConfirmPrompt` reads it instead of keeping its own list. Setting a Watch and a throw are committed through `_is_act` (§7.4). `tests/unit/test_commit_policy.gd` names every case above, and that tiering does not mutate the state.

### 5.1 — The history

**Ships.** `CommandHistory`: `push(state_before, outcome)`, `can_undo()`, `undo() -> CombatState`. A committed push clears the stack, so what remains is only ever unrevealing moves in a row.

**Done when.** Undo returns the exact prior state; two reversible walks undo in order; a reveal clears the stack; ending a phase clears it; the history never mutates a state it holds (cover with `tests/unit/test_state_isolation.gd`).

### 5.2 — Undo in the view

**Ships.** `fight_view` keeps one `CommandHistory`, an Undo control in the HUD that is visible only when `can_undo()`, and a key binding. UI §5 gets one sentence on what the control looks like.

**Done when.** On the scripted street a walk then Undo restores unit position, AP and the drawn overlays; a walk that peels fog shows no Undo; a `make shots` setup captures the control present and absent.

### 5.3 — One confirm

**Ships.** `ConfirmPrompt`: an action registers a label and a cost line; the first click arms it and states the cost, the second commits, Esc cancels. The bleeder shot moves onto it, and the registration is where First Gauge, a sluice opening and dispatch attach later.

**Done when.** The bleeder shot behaves exactly as today through the new path (existing test stays green); arming then moving the hover cancels; the prompt text names the cost and never a probability (UI §1).

### 5.4 — Housekeeping

**Ships.** UI §5 and §18 ticked for what is built, and the committed row naming Watch set (7.4); the Trauma Kit registered as a confirm action pending the MEDEVAC slice.

**Done when.** `make test` green, docs match the code, and nothing in `fight_view` decides a tier.

---

## 4. Explicitly out of scope

- The full fight save, quickload and mid-fight persistence (plan 4.6's line stays: save at fight end only).
- Interact gizmos, authored machines on the terrace, and the sluice's redirection preview (`plans/06`).
- The MEDEVAC window rules (GDD 1.11); only its confirm registration is here.
- Redo. A taken-back move is not replayable.
- Enemy-phase undo. History is the player's own phase only.
- Any rule change to make a move reveal more or less.

---

## 5. Verification

1. `make test` green.
2. **One tier function.** `grep` finds no `anything_revealed` read outside `CommitPolicy` and the history.
3. **Undo is exact.** After undo, `state` equals the state before the move field for field, and a branched copy is unaffected (isolation test).
4. **A reveal is never undoable**, by every cause in `RevealResult` (peel, Watch by entry, enemy line, act).
5. **The confirm is one path.** The bleeder test passes through `ConfirmPrompt`, and there is no second hand-rolled confirm in `fight_view`.
6. `make shots` shows the Undo control only when it can act (UI §14: not colour alone).

---

## 6. Sequencing note

5.0 and 5.1 are headless and independent of the view; do them first and in order. 5.2 and 5.3 are independent of each other and can land in either order once 5.1 exists. 5.4 last.

---

## 7. Decisions

### 7.1 — Does a reveal clear all history, or only the move's own entry? **Clear everything behind it.**

Locked. The alternative keeps earlier unrevealing moves undoable, but then undoing them replays a position the player has since learned things about. Raise to the GDD only if playtests find the clear too harsh.

### 7.2 — Does undo refund AP? **Yes.**

Locked. The whole state returns, AP included, because a taken-back move was never committed (UI §5). Free movement before contact has no AP at all (GDD §3.1), so this matters only once phases start.

### 7.3 — How many steps back? **Unbounded within a phase, cleared at phase end.**

Locked. A cap is a rule nobody asked for; the reveal boundary already limits it.

### 7.4 — Is a Watch set a reversible move? **No, it is committed.**

Locked. Setting a Watch spends AP and reveals nothing, but UI §5 does not list it as committed. It is an act, because the Watch can trigger on the enemy's very next step and the player would be undoing around a reaction. UI §5's committed row names it in 5.4.

---

## 8. What comes after

`plans/06` is **interact gizmos**: the hatch, the pump house and the sluice authored on the terrace as data, their previews, and the sluice's redirection preview (UI §3 mid-fight water), which is the first real test of the water plane and the first user of the confirm mechanism from 5.3. Table mode (UI §8) stays a separate spine.
