#!/usr/bin/env bash
# WO-030: S8 n=500 DIRECTION sweep (restaged side-by-side + edge allocation).
set -euo pipefail
cd /workspace
mkdir -p docs/reports/evidence_wo030
GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64

$GODOT --headless --path . -s res://tests/wo030_s8_sweep.gd -- START=1000 COUNT=125 WORKER=w0 \
  > docs/reports/evidence_wo030/s8_w0.log 2>&1 &
$GODOT --headless --path . -s res://tests/wo030_s8_sweep.gd -- START=1125 COUNT=125 WORKER=w1 \
  > docs/reports/evidence_wo030/s8_w1.log 2>&1 &
$GODOT --headless --path . -s res://tests/wo030_s8_sweep.gd -- START=1250 COUNT=125 WORKER=w2 \
  > docs/reports/evidence_wo030/s8_w2.log 2>&1 &
$GODOT --headless --path . -s res://tests/wo030_s8_sweep.gd -- START=1375 COUNT=125 WORKER=w3 \
  > docs/reports/evidence_wo030/s8_w3.log 2>&1 &
wait
echo ALL_S8_DONE

python3 <<'PY'
import csv, math, statistics, glob, sys
rows=[]
for p in sorted(glob.glob("docs/reports/evidence_wo030/s8_sweep_w*.csv")):
    if p.endswith(".import"): continue
    with open(p) as f:
        for r in csv.DictReader(f):
            if r and r.get("ratio"): rows.append(r)
print("merged", len(rows))
if not rows:
    sys.exit(2)
vals=sorted(float(r["ratio"]) for r in rows)
n=len(vals)
mean=sum(vals)/n
sd=statistics.stdev(vals) if n>1 else 0.0
cv=sd/mean if mean else 0
ge3=sum(1 for v in vals if v>=3.0-1e-9)
print(f"ratio n={n} mean={mean:.6f} sd={sd:.6f} cv={cv:.4f} min={vals[0]:.6f} max={vals[-1]:.6f} ge3={ge3}")
open("docs/reports/evidence_wo030/s8_merged_summary.txt","w").write(
    f"ratio n={n} mean={mean:.6f} sd={sd:.6f} cv={cv:.4f} min={vals[0]:.6f} max={vals[-1]:.6f} ge3={ge3}\n"
)
sys.exit(0 if ge3==0 and n==500 else 1)
PY
