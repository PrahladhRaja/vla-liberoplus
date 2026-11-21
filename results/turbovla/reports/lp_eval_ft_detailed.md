# TurboVLA on LIBERO-Plus: released vs fine-tuned (detailed, paired)

All 10030 tasks: **45.5% → 68.9%**, Δ = +23.5 points (95% CI ±1.0). Solved by both 4138, neither 2695, baseline only 422, fine-tuned only 2775.

## By category and difficulty level (success %, baseline → fine-tuned)

| Category | L1 | L2 | L3 | L4 | L5 | all (Δ ± 95% CI) |
|---|---|---|---|---|---|---|
| Camera | 44→79 <sub>n=199</sub> | 25→70 <sub>n=360</sub> | 21→70 <sub>n=325</sub> | 22→70 <sub>n=228</sub> | 16→74 <sub>n=487</sub> | 23.3→72.5 (+49.2 ±2.6) |
| Robot | 61→73 <sub>n=248</sub> | 55→58 <sub>n=292</sub> | 32→45 <sub>n=374</sub> | 20→24 <sub>n=285</sub> | 8→11 <sub>n=351</sub> | 33.3→40.3 (+7.0 ±2.3) |
| Language | 78→84 <sub>n=328</sub> | 76→78 <sub>n=280</sub> | 76→80 <sub>n=259</sub> | 70→79 <sub>n=328</sub> | 43→47 <sub>n=342</sub> | 67.9→73.1 (+5.2 ±2.0) |
| Light | 66→82 <sub>n=111</sub> | 80→91 <sub>n=197</sub> | 75→88 <sub>n=244</sub> | 65→89 <sub>n=242</sub> | 65→84 <sub>n=227</sub> | 67.8→85.0 (+17.3 ±2.7) |
| Background | 69→91 <sub>n=233</sub> | 56→87 <sub>n=271</sub> | 46→81 <sub>n=263</sub> | 37→71 <sub>n=163</sub> | 12→62 <sub>n=146</sub> | 47.7→80.8 (+33.1 ±3.2) |
| Noise | 45→68 <sub>n=177</sub> | 48→79 <sub>n=500</sub> | 35→73 <sub>n=300</sub> | 17→68 <sub>n=383</sub> | 6→71 <sub>n=241</sub> | 31.5→73.1 (+41.5 ±2.6) |
| Layout | 64→72 <sub>n=348</sub> | 64→72 <sub>n=302</sub> | 60→71 <sub>n=329</sub> | 50→65 <sub>n=257</sub> | 33→46 <sub>n=289</sub> | 54.8→65.3 (+10.5 ±2.2) |
| **all** | 63→78 | 55→76 | 47→71 | 40→66 | 25→55 | 45.5→68.9 |

(121 tasks have no difficulty level; included in 'all'.)

## By original LIBERO task (all perturbations of it), sorted by gain

| Suite | Original task | tasks | baseline | fine-tuned | Δ |
|---|---|---|---|---|---|
| 10 | put both moka pots on the stove | 233 | 21.5 | 75.5 | +54.1 |
| 10 | put the yellow and white mug in the microwave and close it | 278 | 35.6 | 87.8 | +52.2 |
| 10 | put the black bowl in the bottom drawer of the cabinet and close it | 304 | 31.6 | 81.9 | +50.3 |
| spatial | pick up the black bowl next to the ramekin and place it on the plate | 198 | 22.2 | 69.2 | +47.0 |
| object | pick up the ketchup and place it in the basket | 214 | 37.9 | 81.8 | +43.9 |
| spatial | pick up the black bowl in the top drawer of the wooden cabinet and place it on the plate | 280 | 35.4 | 77.1 | +41.8 |
| 10 | put the white mug on the left plate and put the yellow and white mug on the right plate | 287 | 44.9 | 85.0 | +40.1 |
| 10 | pick up the book and place it in the back compartment of the caddy | 237 | 58.2 | 90.7 | +32.5 |
| spatial | pick up the black bowl next to the plate and place it on the plate | 180 | 58.9 | 90.6 | +31.7 |
| object | pick up the bbq sauce and place it in the basket | 292 | 58.6 | 89.4 | +30.8 |
| spatial | pick up the black bowl on the ramekin and place it on the plate | 256 | 52.0 | 80.5 | +28.5 |
| spatial | pick up the black bowl on the cookie box and place it on the plate | 246 | 58.1 | 86.6 | +28.5 |
| goal | put the bowl on the stove | 156 | 14.7 | 42.9 | +28.2 |
| 10 | put both the alphabet soup and the cream cheese box in the basket | 194 | 61.9 | 89.7 | +27.8 |
| object | pick up the salad dressing and place it in the basket | 264 | 62.1 | 89.0 | +26.9 |
| object | pick up the cream cheese and place it in the basket | 173 | 61.3 | 87.9 | +26.6 |
| object | pick up the tomato sauce and place it in the basket | 251 | 58.6 | 84.9 | +26.3 |
| goal | put the bowl on top of the cabinet | 243 | 17.7 | 42.8 | +25.1 |
| spatial | pick up the black bowl next to the cookie box and place it on the plate | 232 | 66.4 | 90.5 | +24.1 |
| object | pick up the chocolate pudding and place it in the basket | 257 | 65.8 | 89.5 | +23.7 |
| spatial | pick up the black bowl between the plate and the ramekin and place it on the plate | 231 | 73.2 | 95.7 | +22.5 |
| object | pick up the orange juice and place it in the basket | 280 | 55.0 | 76.4 | +21.4 |
| spatial | pick up the black bowl from table center and place it on the plate | 267 | 69.7 | 91.0 | +21.3 |
| object | pick up the butter and place it in the basket | 273 | 64.8 | 85.3 | +20.5 |
| goal | push the plate to the front of the stove | 270 | 14.4 | 34.1 | +19.6 |
| goal | put the bowl on the plate | 235 | 54.9 | 74.0 | +19.1 |
| object | pick up the milk and place it in the basket | 272 | 50.7 | 69.9 | +19.1 |
| 10 | put both the cream cheese box and the butter in the basket | 210 | 69.0 | 87.1 | +18.1 |
| goal | put the wine bottle on the rack | 302 | 25.8 | 43.7 | +17.9 |
| 10 | turn on the stove and put the moka pot on it | 281 | 66.2 | 83.6 | +17.4 |
| object | pick up the alphabet soup and place it in the basket | 242 | 69.4 | 86.0 | +16.5 |
| goal | put the cream cheese in the bowl | 291 | 12.0 | 27.1 | +15.1 |
| 10 | put both the alphabet soup and the tomato sauce in the basket | 212 | 11.8 | 26.9 | +15.1 |
| goal | put the wine bottle on top of the cabinet | 270 | 21.9 | 35.9 | +14.1 |
| goal | open the top drawer and put the bowl inside | 324 | 7.7 | 13.9 | +6.2 |
| goal | open the middle drawer of the cabinet | 268 | 54.9 | 60.8 | +6.0 |
| goal | turn on the stove | 232 | 32.3 | 37.1 | +4.7 |
| spatial | pick up the black bowl on the stove and place it on the plate | 269 | 42.0 | 45.0 | +3.0 |
| 10 | put the white mug on the plate and put the chocolate pudding to the right of the plate | 283 | 66.4 | 60.1 | -6.4 |
| spatial | pick up the black bowl on the wooden cabinet and place it on the plate | 243 | 44.9 | 35.4 | -9.5 |

## Where the fine-tuned model still fails most (suite × category, fine-tuned success %)

| Suite | Category | tasks | baseline | fine-tuned |
|---|---|---|---|---|
| libero_goal | Robot | 409 | 15.2 | 17.6 |
| libero_goal | Language | 410 | 28.0 | 32.4 |
| libero_goal | Layout | 425 | 37.4 | 37.2 |
| libero_goal | Noise | 379 | 20.1 | 37.7 |
| libero_spatial | Robot | 350 | 35.7 | 43.4 |
| libero_object | Robot | 398 | 38.7 | 43.7 |
| libero_goal | Background | 281 | 26.7 | 52.0 |
| libero_goal | Camera | 408 | 12.0 | 55.6 |

## Regressions (solved by the baseline, not by the fine-tuned model)

422 tasks (4.2% of all). Largest groups: object/Robot 39, spatial/Language 37, 10/Robot 30, 10/Light 28, 10/Background 27, 10/Language 26.

## Episode time (seconds per task, mean)

| | baseline | fine-tuned |
|---|---|---|
| all | 26.0 | 19.4 |
| successes (each run's own) | 14.3 | 16.9 |
| Sensor Noise | 113.5 | 79.2 |
| total worker-hours | 72.3 | 54.1 |
