#!/usr/bin/env bash
set -euo pipefail
cd /workspace
mkdir -p docs/reports/evidence_wo028
GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64

$GODOT --headless --path . --script res://tests/wo028_s3_rederive.gd -- START=1000 COUNT=125 WORKER=w0 \
  > docs/reports/evidence_wo028/s3_w0.log 2>&1 &
$GODOT --headless --path . --script res://tests/wo028_s3_rederive.gd -- START=1125 COUNT=125 WORKER=w1 \
  > docs/reports/evidence_wo028/s3_w1.log 2>&1 &
$GODOT --headless --path . --script res://tests/wo028_s3_rederive.gd -- START=1250 COUNT=125 WORKER=w2 \
  > docs/reports/evidence_wo028/s3_w2.log 2>&1 &
$GODOT --headless --path . --script res://tests/wo028_s3_rederive.gd -- START=1375 COUNT=125 WORKER=w3 \
  > docs/reports/evidence_wo028/s3_w3.log 2>&1 &
wait
echo ALL_S3_DONE

python3 <<'PY'
import csv, math, statistics, glob
rows=[]
for p in sorted(glob.glob("docs/reports/evidence_wo028/s3_rederive_w*.csv")):
    with open(p) as f:
        for r in csv.DictReader(f):
            rows.append(r)
print("merged", len(rows))
def stats(key):
    vals=sorted(float(r[key]) for r in rows)
    n=len(vals)
    mean=sum(vals)/n
    sd=statistics.stdev(vals)
    def pct(p):
        idx=p*(n-1); lo=int(math.floor(idx)); hi=int(math.ceil(idx)); t=idx-lo
        return vals[lo]*(1-t)+vals[hi]*t
    return dict(n=n,mean=mean,sd=sd,min=vals[0],max=vals[-1],p01=pct(0.01),p99=pct(0.99),p005=pct(0.005),p995=pct(0.995),m3=mean-3*sd,p3=mean+3*sd)
for k in ["ratio","rout","left"]:
    s=stats(k)
    print(f"{k} n={s['n']} mean={s['mean']:.6f} sd={s['sd']:.6f} min={s['min']:.6f} max={s['max']:.6f} p01={s['p01']:.6f} p99={s['p99']:.6f} p005={s['p005']:.6f} p995={s['p995']:.6f} m3sd={s['m3']:.6f} p3sd={s['p3']:.6f}")
flank=sum(1 for r in rows if r["flank_wins"]=="true")
print(f"flank_wins={flank}/{len(rows)}")
with open("docs/reports/evidence_wo028/s3_rederive_merged_summary.txt","w") as out:
    for k in ["ratio","rout","left"]:
        s=stats(k)
        out.write(f"{k} n={s['n']} mean={s['mean']:.6f} sd={s['sd']:.6f} min={s['min']:.6f} max={s['max']:.6f} p01={s['p01']:.6f} p99={s['p99']:.6f} p005={s['p005']:.6f} p995={s['p995']:.6f} m3sd={s['m3']:.6f} p3sd={s['p3']:.6f}\n")
    out.write(f"flank_wins={flank}/{len(rows)}\n")
print("WROTE merged summary")
PY
