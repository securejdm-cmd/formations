# ESCALATION REPORT — WO-030 S8 root cause

**Status:** AWAITING GREEN LIGHT — no combat fix written (prime suspect falsified).  
**Branch:** `cursor/wo-030-s8-frontage-fd84`  
**Base:** WO-029b tip `02fb0d94`

---

## Work order
WO-030 — S8 root cause (ContactFrontage% / sublinearity by construction)

## Blocker (plain English)
The Technical Director’s prime suspect was that several attackers at once were each being credited with more of the defender’s front edge than they physically share (double-counting), so three attackers could deal ~3× damage.

We measured every one of the 20 failing seeds. **That never happens.** On every failing seed, only **one** attacker is locked to the defender at a time. A second attacker walks up **after** the first has already finished its fight and then deals a large extra pile of damage. A third attacker never reaches the fight. So the ≥3× ratio is **two sequential waves**, not overlapping frontage math.

Because the prescribed defect is not present, implementing a “normalize overlapping frontage” patch would not fix the 20 failures — and inventing a different combat rule (e.g. banning the second wave) would be a silent design decision.

## Worst failing seed (1321) — required deliverables

| | Single (1 atk) | Triple (3 atk) |
|--|--:|--:|
| Defender damage taken | 15.5467 | 59.9599 |
| Ratio | — | **3.8568** |
| Combat duration (s) | 54.2 | 35.2 |

**Per-attacker damage actually applied (triple):**
- `attacker_1`: **15.5467** (identical to the single-attacker battle)
- `attacker_2`: **44.4132**
- `attacker_3`: **0.0** (never engaged)

**Contact frontage (triple, all contact ticks):**
- Defender front-edge width: **40.0 m**
- Max concurrent contact partners: **1**
- Ticks with 2+ partners: **0**
- Therefore summed attacker frontage on the defender front **never exceeds** the defender’s front edge (no overlap double-count). The single partner in contact is credited with full front-edge span (40 m / 40 m → ContactFrontage% = 1.0 under the head-on path).

**QoD (σ=0.045):** defender=1.046; atk1=0.878; atk2=1.022; atk3=1.015  
Weak first attacker softens little; strong second wave finishes the defender.

## All 20 ge3 seeds

`SEEDS_WITH_2PLUS_PARTNERS = 0 / 20`  
Universal pattern: `attacker_1 ≈ single_damage`, `attacker_2` adds the rest, `attacker_3 = 0`, `max_partners = 1`.

Evidence: `docs/reports/evidence_wo030/s8_ge3_scan.log`, `s8_frontage_diag_1321.log`.

## (2) Does summed frontage exceed the defender front edge?
**No** — for these failures. Simultaneous double-counting is not the defect.

## Variance root-cause (folded from WO-029b, 40% CV)
Not a small-sample artifact. Bimodal because:
- **Low single_damage** (weak QoD / first-wave loss): triple still gets a fresh second wave → ratio spikes (all ge3 live here).
- **High single_damage** (first wave already wrecks the defender): second wave adds little or nothing → ratio ~1×.

## Related observation (not the ge3 driver)
Head-on melee (`CombatResolver.resolve_engagement`) always uses `contact_frontage_pct = 1.0`, ignoring `EdgeContact.attacker_frontage_pct`. That would matter for a **side-by-side** shared-front blob; it does not create the sequential-wave ge3 pattern above.

## Options
- **A)** Keep S8 as total-battle damage ratio, and change design so a depth-stacked column cannot auto-commit a second wave (only the front rank fights until explicitly ordered / until front rank is removed and space is clear). Tradeoff: real gameplay change to reserves/columns; needs designer intent.
- **B)** Respawn S8 as a **side-by-side** blob on one front edge (simultaneous shared frontage), then implement edge-interval allocation so Σ occupied frontage ≤ defender front width and head-on uses that ContactFrontage%. Tradeoff: scenario change + allocation work; matches Combat Core “stacked on one Front edge” wording more literally.
- **C)** Change the S8 assertion to a **simultaneous rate / frontage-normalized** check (not total battle damage). Tradeoff: accepts sequential waves as in-rules; redefines the acceptance instrument.
- **D)** Something else the TD names after this evidence.

## Recommendation
**B** if the blob test is meant to police simultaneous frontage share; **A** if depth columns must not free-commit. Do not ship a no-op frontage normalize that leaves ge3=20.

## AWAITING GREEN LIGHT — no combat code written for a falsified defect.
