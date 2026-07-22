WORK ORDER 036 - Rotated Contact Detection (OBB Unification)
Project: FORMATIONS - Phase 3 (UI) - Issued by Technical Director
GREEN LIGHT: proceed immediately. Escalate per governance triggers.
Design authority: WO-035 TD review (rotated-footprint contact miss);
FormationGeometry OBB SAT; Combat Core edge contact; WO-024 surface-gap family.
Base: WO-035 branch.

=========================================================
CONTEXT

Designer debug: blue interpenetrating red while STATE=marching, STR/COH 100/100,
0 defeated — sim does not register contact. Unifies "overlap" and "no damage /
never engages" into one cause: contact miss on rotated footprints.

Hypothesis: contact/edge path uses AABB or insufficient orientation vs true
rotated OBB used for render and allied separation. Same family as WO-024
center-vs-surface.

=========================================================
TASKS

(1) Report exact geometry (AABB vs OBB) on contact path vs true footprint.
    Any AABB approximation in contact path IS the defect — unify on OBB.
(2) Headless repro: 30–60° off-square engagement (+ gravity rotation at
    contact). Assert contact detected (leave marching, combat resolves) AND
    OBB no-overlap tick-by-tick.
(3) Permanent smoke: rotated-contact detection AND rotated-OBB no-overlap.
    Overlapping enemy footprints ⇒ in-contact-and-resolving OR separated —
    never interpenetrating-and-marching.
(4) Head-on scenarios byte-identical.

BATTLE SPEED (log only, non-blocking): presentation control for battle-view WO
— default ~3–4× with 1×/2×/4×/16× selector. Do NOT touch tick rate / speeds.

=========================================================
ACCEPTANCE

[x] Geometry report; contact unified on oriented footprint
[x] Angled-contact smoke PASS (engage + OBB no-overlap)
[x] Permanent assertions in suite
[x] Head-on byte-identical; suite exit 0 (PASS=91)
[x] Designer build; Assumptions NONE; raw report URL
