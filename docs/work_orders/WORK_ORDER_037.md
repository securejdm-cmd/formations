WORK ORDER 037 - Facing Unit-Length Invariant
Project: FORMATIONS - Phase 3 (UI) - Issued by Technical Director
GREEN LIGHT: proceed immediately. Escalate per governance triggers.
Design authority: WO-036 residual TD finding (unnormalized facing);
FormationGeometry OBB; Combat Core contact.
Base: WO-036 branch.

=========================================================
CONTEXT

Designer debug: blue_cav_1 Facing: (-1.0, -1.0) while MARCHING and visually
interpenetrating — unnormalized facing (mag √2). TD: all oriented geometry
derives from facing; non-unit basis skews OBB and can break SAT contact.

=========================================================
TASKS

(1) Audit EVERY write to facing; report each site and whether it normalizes.
(2) Enforce normalization at the boundary (normalized-on-write property
    and/or normalize inside FormationGeometry AND every setter).
(3) Permanent invariant: abs(facing.length()-1) < eps every unit every tick
    (same class as no-overlap / contact-coherence).
(4) Defensive normalize axes inside rectangles_overlap / _obb_overlap.
(5) Headless smoke: cavalry charges, engages, rotates while engaged —
    facing stays unit-length; contact remains; no free OBB merge; combat
    continues. Permanent suite assertion.
(6) Head-on byte-identical; S1–S55 / certs unchanged.

=========================================================
ACCEPTANCE

[ ] Facing-write audit report
[ ] Normalize-on-write + defensive OBB/SAT
[ ] Facing unit-length invariant every tick
[ ] Rotate-while-engaged smoke PASS
[ ] Suite exit 0; Assumptions NONE; raw report URL
