# Matchup matrix

## Configuration: `FRONTAL_VS_STANDING`

What this measures:
- Attacker marches into a **standing** defender (flat, 200 m approach, 11 seeds).
- Archer rows are **inverted** (shooter HOLDs; defender marches through fire — S12).
- Pierce defenders are **pre-braced**.
- Mirror cells at ~100% (cavalry / infantry_charge / archer) are **setup artifacts** (first-mover / doctrine), not profile divinity.

What this does **not** measure: flank, rear, unaware defender, already-engaged.
Cavalry's win condition is outside `FRONTAL_VS_STANDING`.

| Attacker \ Defender | infantry | infantry_charge | spears | archer | cavalry | skirmisher |
|---|---|---|---|---|---|---|
| **infantry** | 64% | 64% | 100% | 100% | 100% | 100% |
| **infantry_charge** | 100% | 100% | 100% | 100% | 100% | 100% |
| **spears** | 0% | 0% | 55% | 100% | 100% | 100% |
| **archer** | 0% | 0% | 0% | 100% | 0% | 0% |
| **cavalry** | 0% | 0% | 0% | 100% | 100% | 100% |
| **skirmisher** | 0% | 0% | 0% | 100% | 0% | 73% |

### Cell detail (mean combat / winner STR / loser STR@rout)

| Config | Attacker | Defender | Win% | Combat_s | WinSTR | LoseSTR |
|---|---|---|---:|---:|---:|---:|
| FRONTAL_VS_STANDING | infantry | infantry | 63.6 | 80.0 | 69.4 | 58.4 |
| FRONTAL_VS_STANDING | infantry | infantry_charge | 63.6 | 80.0 | 69.4 | 58.4 |
| FRONTAL_VS_STANDING | infantry | spears | 100.0 | 54.0 | 97.0 | 47.1 |
| FRONTAL_VS_STANDING | infantry | archer | 100.0 | 35.3 | 90.7 | 59.1 |
| FRONTAL_VS_STANDING | infantry | cavalry | 100.0 | 47.4 | 95.8 | 64.1 |
| FRONTAL_VS_STANDING | infantry | skirmisher | 100.0 | 36.2 | 97.4 | 57.7 |
| FRONTAL_VS_STANDING | infantry_charge | infantry | 100.0 | 52.9 | 80.4 | 44.6 |
| FRONTAL_VS_STANDING | infantry_charge | infantry_charge | 100.0 | 52.9 | 80.4 | 44.6 |
| FRONTAL_VS_STANDING | infantry_charge | spears | 100.0 | 56.8 | 95.2 | 30.1 |
| FRONTAL_VS_STANDING | infantry_charge | archer | 100.0 | 28.0 | 95.1 | 48.5 |
| FRONTAL_VS_STANDING | infantry_charge | cavalry | 100.0 | 39.8 | 96.5 | 65.1 |
| FRONTAL_VS_STANDING | infantry_charge | skirmisher | 100.0 | 30.6 | 97.8 | 50.3 |
| FRONTAL_VS_STANDING | spears | infantry | 0.0 | 54.0 | 97.0 | 66.3 |
| FRONTAL_VS_STANDING | spears | infantry_charge | 0.0 | 54.0 | 97.0 | 66.3 |
| FRONTAL_VS_STANDING | spears | spears | 54.5 | 375.2 | 71.7 | 67.6 |
| FRONTAL_VS_STANDING | spears | archer | 100.0 | 102.5 | 87.7 | 77.5 |
| FRONTAL_VS_STANDING | spears | cavalry | 100.0 | 296.5 | 72.0 | 78.5 |
| FRONTAL_VS_STANDING | spears | skirmisher | 100.0 | 104.1 | 92.3 | 74.2 |
| FRONTAL_VS_STANDING | archer | infantry | 0.0 | 35.4 | 90.7 | 59.1 |
| FRONTAL_VS_STANDING | archer | infantry_charge | 0.0 | 28.0 | 95.1 | 48.5 |
| FRONTAL_VS_STANDING | archer | spears | 0.0 | 102.6 | 87.7 | 77.5 |
| FRONTAL_VS_STANDING | archer | archer | 100.0 | 87.9 | 97.1 | 60.5 |
| FRONTAL_VS_STANDING | archer | cavalry | 0.0 | 25.4 | 95.5 | 83.7 |
| FRONTAL_VS_STANDING | archer | skirmisher | 0.0 | 151.4 | 76.3 | 54.9 |
| FRONTAL_VS_STANDING | cavalry | infantry | 0.0 | 52.4 | 93.5 | 66.1 |
| FRONTAL_VS_STANDING | cavalry | infantry_charge | 0.0 | 52.4 | 93.5 | 66.1 |
| FRONTAL_VS_STANDING | cavalry | spears | 0.0 | 90.4 | 92.5 | 80.2 |
| FRONTAL_VS_STANDING | cavalry | archer | 100.0 | 25.4 | 95.5 | 83.7 |
| FRONTAL_VS_STANDING | cavalry | cavalry | 100.0 | 60.5 | 91.2 | 84.9 |
| FRONTAL_VS_STANDING | cavalry | skirmisher | 100.0 | 30.8 | 97.4 | 81.9 |
| FRONTAL_VS_STANDING | skirmisher | infantry | 0.0 | 36.2 | 97.4 | 67.7 |
| FRONTAL_VS_STANDING | skirmisher | infantry_charge | 0.0 | 36.2 | 97.4 | 67.7 |
| FRONTAL_VS_STANDING | skirmisher | spears | 0.0 | 104.2 | 92.3 | 75.2 |
| FRONTAL_VS_STANDING | skirmisher | archer | 100.0 | 151.2 | 76.3 | 54.9 |
| FRONTAL_VS_STANDING | skirmisher | cavalry | 0.0 | 73.0 | 94.5 | 70.6 |
| FRONTAL_VS_STANDING | skirmisher | skirmisher | 72.7 | 125.1 | 69.9 | 62.4 |
