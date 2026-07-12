# ESCALATION REPORT — WO-006 Task 4 (Mirror Bias Audit)

**Work order:** WO-006 — Scenario 2 + Mirror Bias Audit (Task 4)  
**Date:** 2026-07-11  
**Status:** DIAGNOSTIC ESCALATION — asymmetry confirmed; **no patch applied** per Task 4 directive.

---

## Blocker

The mirror-bias audit (Scenario 1, seeds 1000–1004, sides swapped) found **5/5 asymmetric outcomes**. For every seed, the **same team color wins** in both the normal and mirrored run. The expected unbiased behavior — winner swaps with starting-position swap — does not occur.

This means Scenario 1’s red-wins-8/11 record is **not explained by starting-position luck alone**. The simulation appears to favor outcomes by **team identity** (red vs blue), not by which side of the field a unit starts on.

---

## Mirror audit results

| Seed | Normal winner | Mirrored winner | SYMMETRIC | First trace divergence (slot-mapped) |
|------|---------------|-----------------|-----------|--------------------------------------|
| 1000 | red_1 | red_1 | NO | tick **62.0 s** — left-slot strength: normal red_1 **99.6131** vs mirror blue_1 **99.5137** |
| 1001 | red_1 | red_1 | NO | tick **62.0 s** — left-slot strength: normal red_1 **99.4913** vs mirror blue_1 **99.6044** |
| 1002 | blue_1 | blue_1 | NO | tick **62.0 s** — left-slot strength: normal red_1 **99.4878** vs mirror blue_1 **99.6111** |
| 1003 | blue_1 | blue_1 | NO | tick **62.0 s** — left-slot strength: normal red_1 **99.5451** vs mirror blue_1 **99.5421** |
| 1004 | red_1 | red_1 | NO | tick **62.0 s** — left-slot strength: normal red_1 **99.4963** vs mirror blue_1 **99.6036** |

**Slot mapping used for comparison:** normal left-slot occupant (`red_1`) compared to mirror left-slot occupant (`blue_1`); normal right-slot (`blue_1`) compared to mirror right-slot (`red_1`). Position X values match at spawn; divergence begins at **62.0 s** (first combat second after ~61.7 s march contact) on all five seeds.

**Winner-level asymmetry:** mirrored winner equals normal winner on every seed — no seed flips winner when positions swap.

---

## Additional observations (diagnosis only)

- Mirrored battles also triggered **overlap assertions** during late combat (ticks ~1380–1614 depending on seed). Normal Scenario 1 runs on the same seeds do not overlap in the WO-005 band. Not investigated further per Task 4 scope.
- Trace files: `tests/traces/scenario_01_<seed>.csv` (normal), `tests/traces/scenario_01_mirror_<seed>.csv` (mirrored).

---

## Options

**A) TD rules on acceptable bias source**  
Identify whether team-color coupling (e.g. iteration order, pair-key resolution, team-tagged RNG draws, or red/blue-specific code paths) is an acceptable Phase 1 artifact or must be eliminated before further scenario acceptance. Tradeoff: may require changes to approved Scenario 1 combat code — out of scope for WO-006.

**B) Defer mirror fix; annotate Scenario 1 seed statistics**  
Treat mirror asymmetry as a known simulation limitation; interpret Scenario 1 win rates as team-biased until a future WO addresses symmetry. Tradeoff: undermines fairness claims for mirror-match scenarios.

**C) Full symmetry pass (future WO)**  
Systematic audit of combat resolver, engagement order, ground shift direction, and RNG consumption for red-vs-blue ordering dependencies. Tradeoff: invasive; needs explicit GREEN LIGHT and scope.

---

## Recommendation

**Option A** — TD should rule whether team-identity bias is expected or a defect requiring Option C, before interpreting Scenario 1 win-rate statistics or tuning push/morale constants.

---

## AWAITING GREEN LIGHT

No mirror-bias patch was applied. Per WO-006 Task 4: diagnosis only.
