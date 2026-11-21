# Standard LIBERO: baseline vs new model (paired episodes)

- Baseline: `libero_std/released` (2000 episodes); new: `libero_std/finetuned` (2000 episodes); paired: 2000.

| Suite | baseline | new | Δ | baseline only | new only | paired test |
|---|---|---|---|---|---|---|
| libero_spatial | 95.0 | 97.4 | +2.4 | 12 | 24 | z = 1.83, p ≈ 0.0668 (not significant at 5%) |
| libero_object | 98.2 | 99.6 | +1.4 | 2 | 9 | z = 1.81, p ≈ 0.0704 (not significant at 5%) |
| libero_goal | 95.2 | 96.2 | +1.0 | 14 | 19 | z = 0.70, p ≈ 0.486 (not significant at 5%) |
| libero_10 | 86.6 | 93.0 | +6.4 | 25 | 57 | z = 3.42, p ≈ 0.000618 (significant at 5%) |
| **all** | 93.8 | 96.5 | +2.8 | 53 | 109 | z = 4.32, p ≈ 1.55e-05 (significant at 5%) |

Per task (success % baseline → new), tasks whose rate changed by 10 points or more:

- libero_spatial: task 5: 80 → 96
- libero_object: none
- libero_goal: task 3: 94 → 80; task 9: 86 → 100
- libero_10: task 0: 80 → 98; task 3: 76 → 86; task 5: 88 → 100; task 6: 92 → 78; task 8: 54 → 82
