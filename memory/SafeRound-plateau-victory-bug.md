---
name: Safe Round plateau/victory bug fix (F6)
description: Fixed two bugs in Safe Round where non-activators incorrectly got the GdV cap applied and couldn't win at 100.
type: project
---

## Bug Discovered During F6 Test Discovery

**Symptom:** `test_safe_round_non_adv_99_plus_1` expected plateau=100 with winner=p2, got plateau=99, no winner.

### Root Cause (Bug #1 — Plateau Cap)
The plateau computation logic at line 456 of `games/roadto100/rules.py` checked `sr_active and not is_plus11` for ALL `special_round_type` values. Safe Round should allow non-activators to win at 100 normally — the SR only blocks card TYPES, not victory conditions.

**Fix:** Added check for `special_round_type == "advantage"` before applying the GdV cap (100→99). Safe Round non-activators now get normal play (win at 100, normal bounce 200-raw_total).

### Root Cause (Bug #2 — Victory Condition)
The victory check `elif not sr_active and (plateau == TARGET_SCORE or plateau > TARGET_SCORE)` blocked non-activators from winning during Safe Round because `sr_active` was True.

**Fix:** Added a new condition for Safe Round type that allows normal victory at 100/above for all players.

### Files Modified
- `games/roadto100/rules.py` — `apply_action()` plateau computation + victory check (lines 456-488)
- `engine/RoadTo100Rules.gd` — same fix mirrored in GDScript (lines 433-470)

### Tests Added During F6 Discovery
1. **TestSafeRoundLifecycle** — 1 test: SR ends after activator's next turn
2. **TestSafeRoundNonActivatorPlay** — 3 tests: non-adv 99+1→win at 100, 97+8→95 bounce, 99+5→96 bounce
3. **TestAdvantageNonActivatorExact100** — 1 test: GdV non-adv 99+1→99 no win (explicit type="advantage")

### Test Results
- Python suite: 54 tests, ALL PASS (was 49 before F6 additions)
- Godot suite: all 7 suites pass (domain_test, rules_test 131/0, provider_test, presenter_test, board_test 44/0, game_controller_test, card_animator_test)

### Fix Verified
Both fixes confirmed by test pass. No regressions in existing tests. The distinction between "advantage" (GdV) and "safe" special_round_type is now correct in both Python and GDScript implementations.
