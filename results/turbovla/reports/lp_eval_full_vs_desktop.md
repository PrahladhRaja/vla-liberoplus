# TurboVLA on LIBERO-Plus: Turing vs desktop

- Desktop: 10030 tasks evaluated; Turing: 10024 tasks evaluated; compared: 10024 tasks (of 10030).
- Turing hang/crash records: 12 on 6 tasks; skipped after two: 6.
- Turing episode time: 70.9 worker-hours (desktop full run: 86.5 h of episodes).

## Success rate (%), compared tasks; Δ = Turing − desktop

| | Camera | Robot | Language | Light | Background | Noise | Layout | Total |
|---|---|---|---|---|---|---|---|---|
| libero_spatial | 21.8 → 22.6 (+0.8) | 34.0 → 35.7 (+1.7) | 74.9 → 76.2 (+1.3) | 80.1 → 78.8 (-1.4) | 57.0 → 54.7 (-2.3) | 41.6 → 42.5 (+0.9) | 56.1 → 59.5 (+3.4) | **51.5 → 52.3 (+0.8)** |
| libero_object | 32.6 → 31.8 (-0.8) | 40.2 → 38.7 (-1.5) | 94.1 → 94.6 (+0.6) | 92.3 → 91.2 (-1.0) | 82.3 → 79.4 (-2.8) | 32.2 → 31.8 (-0.5) | 64.8 → 64.0 (-0.7) | **59.5 → 58.6 (-0.9)** |
| libero_goal | 15.2 → 12.0 (-3.2) | 15.4 → 15.2 (-0.2) | 22.7 → 28.0 (+5.4) | 40.9 → 41.9 (+1.1) | 21.0 → 26.7 (+5.7) | 20.3 → 20.1 (-0.3) | 33.4 → 37.4 (+4.0) | **23.5 → 25.2 (+1.7)** |
| libero_10 | 26.0 → 27.0 (+1.0) | 43.8 → 44.5 (+0.8) | 77.3 → 77.3 (+0.0) | 48.5 → 56.9 (+8.4) | 32.5 → 34.6 (+2.1) | 31.4 → 33.0 (+1.6) | 60.6 → 60.9 (+0.3) | **45.0 → 46.8 (+1.8)** |
| all suites | 23.9 → 23.3 (-0.6) | 33.2 → 33.3 (+0.1) | 66.0 → 67.9 (+1.9) | 66.1 → 67.8 (+1.7) | 46.8 → 47.7 (+0.8) | 31.2 → 31.7 (+0.4) | 53.0 → 54.8 (+1.8) | **44.6 → 45.5 (+0.8)** |

## Task-by-task agreement

| | Turing success | Turing failure |
|---|---|---|
| **Desktop success** | 3853 | 622 |
| **Desktop failure** | 707 | 4842 |

Same outcome on 86.7% of tasks; 1329 differ (622 desktop-only, 707 Turing-only).
McNemar test (are flips biased in one direction?): z = 2.30, p ≈ 0.0212 (significant difference at 5%).

Per category, share of tasks whose outcome differs:

| Category | differing | of tasks | % |
|---|---|---|---|
| Camera | 205 | 1599 | 12.8 |
| Robot | 228 | 1550 | 14.7 |
| Language | 187 | 1537 | 12.2 |
| Light | 159 | 1142 | 13.9 |
| Background | 153 | 1076 | 14.2 |
| Noise | 165 | 1595 | 10.3 |
| Layout | 232 | 1525 | 15.2 |
