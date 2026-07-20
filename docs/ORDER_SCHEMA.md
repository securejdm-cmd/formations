# FORMATIONS — Order & Battle-Type Schema (WO-031)

**Authority:** DESIGN_RULINGS R23–R25; WORK_ORDER_031; TD green light 1A–7A.

## Per-unit order queue (R23)

Cap: **3 steps**. Rally contingency is a separate field (outside the cap; not built this WO).

Each step:
```json
{
  "primitive": "<name>",
  "params": { },
  "trigger": { "type": "<trigger>", ... }   // optional; omit or type at_start → immediate
}
```

Steps run in sequence. A step with a trigger **waits** until the trigger fires, then executes. When a step completes, the next begins. After the last step completes, the unit remains in that step’s **terminal behavior**.

### Primitives (v1)

| primitive | params | terminal behavior |
|-----------|--------|-------------------|
| `advance_to` | `point: {x,y}` (meters, battlefield frame) | HOLD at point (engage via normal gravity en route) |
| `hold` | — | HOLD; fight if attacked; normal gravity/orders |
| `absolute_hold` | — | HOLD at post; see Absolute Hold below |
| `attack_nearest` | — | seek nearest **non-routing** enemy; on engage, grind |
| `attack_target` | `unit: "<id>"` | seek named enemy; on engage, grind |
| `feign_retreat` | `dist: <m>` | after retire+turn: attack_nearest terminal |
| `flank_move` | `side: "left"\|"right"`, `point: {x,y}`, optional `flank_arc_offset_m` | HOLD at point |
| `swing_and_charge` | `side: "left"\|"right"`, `target: "<id>"`, optional `flank_arc_offset_m` | charge-commit target (R17); terminal HOLD if target gone |

**attack_* terminal semantics (4A):** when the seek target **routs or is removed**, the step **completes** and the queue advances. If the queue is exhausted, terminal behavior = **hold**. Pursuit remains deliberate/scripted (not implied by attack_*).

**flank_move / swing_and_charge (3A):** v1 headless form uses one intermediate waypoint offset laterally by `flank_arc_offset_m` (default **100** from constants; per-step override in params). Explicit waypoint lists (Option C) are reserved for the UI-authored assignment screen later.

### Triggers (v1)

| type | params | fires when |
|------|--------|------------|
| `at_start` | — | immediately (battle start / step reached) |
| `after_seconds` | `t: <sec>` | sim time ≥ t since battle start |
| `enemy_within` | `x: <m>` | any non-routing enemy within x meters (center) of self |
| `unit_engages` | `unit: "<id>"` | named friendly enters ENGAGED/WAVERING with a contact partner |
| `unit_routs` | `scope: "any"\|"enemy"\|"friendly"`, optional `unit: "<id>"` | matching unit begins ROUTING |
| `my_cohesion_below` | `c: <0–100>` | self cohesion < c |
| `horn_sounded` | — | this unit’s side has sounded the horn |
| `unit_order_started` | `unit: "<id>"`, `primitive: "<name>"` | named unit **begins executing** that primitive (6A) |

### Absolute hold (2A)

- Gravity **may rotate facing** toward contact (square up) but **must not translate** the unit (no magnetism closure, no march, no pursuit).
- **Combat push ground-shift** remains lawful physics.
- S44 asserts against **order/pursuit/drift** displacement only.

### Army order — sound_horn (R24 / 1A)

Once per battle per side. Immediately **aborts** every unit’s queue on that side (including in-progress `feign_retreat` / flank arcs). Units: fighting-withdrawal if contacted, then orderly retirement toward own map edge under ordered-retreat drain × Retreating Skill. Braced / absolute_hold units abandon post and comply. Deployment-reset after horn is backlogged (out of scope).

### Retreating Skill drain

`effective_drain = ordered_retreat_drain_per_sec * max(0, 1 - retreating_skill/100)` per second while feigning or horn-retreating.

---

## Battle-type schema (R25) — structure only

Scenario metadata (GDScript / future JSON):

```json
{
  "battle_type": "pitched",
  "deployment_zones": {
    "red":  { "x": -300, "y": -150, "w": 120, "h": 300 },
    "blue": { "x":  180, "y": -150, "w": 120, "h": 300 }
  },
  "victory": { "mode": "rout", "extensible": true },
  "units": [
    {
      "id": "anvil",
      "team": "blue",
      "profile": "test_infantry",
      "posture": "normal",
      "order_queue": [ ... ]
    }
  ]
}
```

| field | values | notes |
|-------|--------|-------|
| `battle_type` | `pitched` (default) | more types later |
| `deployment_zones` | per-side axis-aligned rects (meters) | UI later; schema only |
| `posture` | `normal` \| `concealed` | WO-032 Sec 10 concealment |
| `victory` | existing rout conditions | extensible object |

No new mechanics in this schema task.

---

## Trace observability (5A)

When any unit has a non-empty queue or a horn is active/scheduled, emit per-second:

`EVENT,order_state,unit=<id>,step=<i>,phase=<waiting|executing|terminal>,primitive=<name>,trigger=<type|none>,trigger_live=<bool>,prim_phase=<...>`

Legacy scenarios (empty queues, no horn) emit **no** new lines → S1–S40 byte-identical.
