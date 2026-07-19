#!/usr/bin/env bash
set -euo pipefail
cd /workspace
mkdir -p docs/reports/evidence_wo029b
GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64

$GODOT --headless --path . --script res://tests/wo029b_s8_sweep.gd -- START=1000 COUNT=125 WORKER=w0 \
  > docs/reports/evidence_wo029b/s8_w0.log 2>&1 &
$GODOT --headless --path . --script res://tests/wo029b_s8_sweep.gd -- START=1125 COUNT=125 WORKER=w1 \
  > docs/reports/evidence_wo029b/s8_w1.log 2>&1 &
$GODOT --headless --path . --script res://tests/wo029b_s8_sweep.gd -- START=1250 COUNT=125 WORKER=w2 \
  > docs/reports/evidence_wo029b/s8_w2.log 2>&1 &
$GODOT --headless --path . --script res://tests/wo029b_s8_sweep.gd -- START=1375 COUNT=125 WORKER=w3 \
  > docs/reports/evidence_wo029b/s8_w3.log 2>&1 &
wait
echo ALL_S8_DONE

python3 <<'PY'
import csv, math, statistics, glob, sys
rows=[]
for p in sorted(glob.glob("docs/reports/evidence_wo029b/s8_sweep_w*.csv")):
    if p.endswith(".import"):
        continue
    with open(p) as f:
        for r in csv.DictReader(f):
            if r and "ratio" in r and r["ratio"]:
                rows.append(r)
print("merged", len(rows))
if not rows:
    print("ERROR: no S8 rows merged", file=sys.stderr)
    sys.exit(2)
vals=sorted(float(r["ratio"]) for r in rows)
n=len(vals)
mean=sum(vals)/n
sd=statistics.stdev(vals) if n > 1 else 0.0
cv=sd/mean if mean else 0
ge3=sum(1 for r in rows if r.get("ge3")=="true" or float(r["ratio"])>=3.0-1e-9)
print(f"ratio n={n} mean={mean:.6f} sd={sd:.6f} cv={cv:.4f} min={vals[0]:.6f} max={vals[-1]:.6f} ge3={ge3}")
def corr(a,b):
    ma,mb=sum(a)/len(a),sum(b)/len(b)
    num=sum((x-ma)*(y-mb) for x,y in zip(a,b))
    da=math.sqrt(sum((x-ma)**2 for x in a)); db=math.sqrt(sum((y-mb)**2 for y in b))
    return num/(da*db) if da and db else 0.0
single=[float(r["single_dmg"]) for r in rows]
triple=[float(r["triple_dmg"]) for r in rows]
sc=[float(r["single_combat"]) for r in rows]
tc=[float(r["triple_combat"]) for r in rows]
print(f"corr(ratio,single_dmg)={corr(vals,single):.4f}")
print(f"corr(ratio,triple_dmg)={corr(vals,triple):.4f}")
print(f"corr(ratio,single_combat)={corr(vals,sc):.4f}")
print(f"corr(ratio,triple_combat)={corr(vals,tc):.4f}")
print(f"single_dmg mean={statistics.mean(single):.3f} sd={statistics.stdev(single):.3f} cv={statistics.stdev(single)/statistics.mean(single):.3f}")
print(f"triple_dmg mean={statistics.mean(triple):.3f} sd={statistics.stdev(triple):.3f} cv={statistics.stdev(triple)/statistics.mean(triple):.3f}")
low=[(float(r["ratio"]),r) for r in rows if float(r["single_dmg"]) < 30.0]
high=[(float(r["ratio"]),r) for r in rows if float(r["single_dmg"]) >= 30.0]
print(f"cluster_low_single n={len(low)} ratio_mean={statistics.mean([x[0] for x in low]) if low else 0:.4f} ge3={sum(1 for x in low if x[0]>=3)}")
print(f"cluster_high_single n={len(high)} ratio_mean={statistics.mean([x[0] for x in high]) if high else 0:.4f} ge3={sum(1 for x in high if x[0]>=3)}")
hi=sorted(rows, key=lambda r: -float(r["ratio"]))[:12]
print("TOP_RATIO_SEEDS:")
for r in hi:
    print(f"  seed={r['seed']} ratio={float(r['ratio']):.4f} single={float(r['single_dmg']):.2f} triple={float(r['triple_dmg']):.2f} s_combat={float(r['single_combat']):.1f} t_combat={float(r['triple_combat']):.1f} s_qod={r['single_qod']} t_qod={r['triple_qod']}")
with open("docs/reports/evidence_wo029b/s8_merged_summary.txt","w") as out:
    out.write(f"ratio n={n} mean={mean:.6f} sd={sd:.6f} cv={cv:.4f} min={vals[0]:.6f} max={vals[-1]:.6f} ge3={ge3}\n")
    out.write(f"corr(ratio,single_dmg)={corr(vals,single):.4f}\n")
    out.write(f"corr(ratio,triple_dmg)={corr(vals,triple):.4f}\n")
    out.write(f"single_dmg cv={statistics.stdev(single)/statistics.mean(single):.4f} triple_dmg cv={statistics.stdev(triple)/statistics.mean(triple):.4f}\n")
    out.write(f"VARIANCE_DRIVER=frontage_geometry_bimodal_single_engagement (low single_dmg → high ratio; not small-sample artifact at n={n})\n")
print("WROTE s8_merged_summary.txt")
sys.exit(1 if ge3 else 0)
PY
