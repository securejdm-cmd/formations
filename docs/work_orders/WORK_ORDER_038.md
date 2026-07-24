WORK ORDER 038 - Facing Readout + Invariant Visibility
Project: FORMATIONS - Phase 3 (UI) - Issued by Technical Director
GREEN LIGHT: proceed immediately. Escalate per governance triggers.
Design authority: WO-037 verification BLOCKED TD finding.
Base: WO-037 branch.

=========================================================
CONTEXT

Debug panel prints literal format string for Facing — magnitude unavailable.
Realtime console reports overlap_fail=false while designer sees interpenetration.

=========================================================
TASKS (in order — no further contact/facing theory patches until done)

(1) Fix Facing readout interpolation; verify in running build.
(2) Log facing.length() every unit every tick during UI-launched rotating
    charge; report min/max and first tick |len-1|>1e-4. If clean, FALSIFY
    unnormalized-facing hypothesis plainly.
(3) Explain silent invariants: (a) assert off outside headless+fast, or
    (b) assert shares buggy geometry. Fix per finding (DEBUG realtime OBB
    check, or independent geometry source).
(4) Report whether WO-037 is in this build (branch/SHA); re-diagnose.

=========================================================
ACCEPTANCE

[ ] Facing readout correct (verified)
[ ] Facing-length min/max report; hypothesis confirm/falsify
[ ] Silent-invariant explanation + DEBUG realtime OBB fix
[ ] WO-037 presence + re-diagnosis; Assumptions NONE; raw report URL
