# Seeded map shuffle and ground encounters · 2026-10-03

Y and the pause-menu button start a fresh descent with a new run seed. Key repeat is ignored, reconstruction runs outside the input callback, and a loading message renders first. Restart preserves the current seed. Both paths clear combo tickets, queued attacks, projectiles, navigation caches and encounter state through the existing run reset.

The seed controls the 784 island positions, 308 sparse crossings, scattered clouds, 45 closed town buildings, nine outpost courts/shrines and 16 furnished districts (96 buildings). The coastline, central landmarks and three original enterable houses remain anchored. Placement preserves reserved routes, court clearances and map boundaries. Twenty sampled seeds each retain all 48 town buildings. Terrain pads and collision follow the moved districts.

Island enemies start alerted and pursue players approaching or jumping within 26 metres vertically and 40 metres horizontally of their arena. Distant islands retain bounded patrol simulation. Landing queues 50 giants and 24 nearby normal raiders, using at most four arrivals per frame and the existing 3 ms spawning budget. Full-body collision and floor checks protect spawning; the global actor cap still applies. While giants remain, raiders refill every eight seconds and distant raiders recycle without rewards. Once giants are gone, the remaining raiders must actually be defeated to liberate the ground.

Combo speed now adds 5% per confirmed link after the first, capped at 1.5×. The one-second hit grace, separate red bonus hits, immediate chained melee contact, and existing level/orb modifiers remain.

Validation commands:

```sh
godot --headless --path . --fixed-fps 60 -- --map-shuffle-test
godot --path . --fixed-fps 60 -- --map-shuffle-visual
godot --headless --path . --fixed-fps 60 -- --descent-test
godot --headless --path . --fixed-fps 60 -- --district-test
godot --headless --path . --fixed-fps 60 -- --world-performance-test
godot --headless --path . --fixed-fps 60 -- --attack-chain-test
godot --headless --path . --fixed-fps 60 -- --legacy-survival --direct-attacks-test
```

The final headless shuffle suite passes all 21 assertions, including map reset, seed repeatability, actor spawning budgets/caps, pursuit, reinforcement pause behavior, and ground victory. Regression suites pass: descent 26 assertions, furnished districts 48, terrain/patrol/navigation 10, confirmed combos 54, direct attacks 28. Rendered shuffle checks passed all 19 assertions before the final boundary tightening and two additional victory checks; captures show both layouts, the pause button and 50 giants / 24 raiders in the ground HUD. Some headless suites emit pre-existing resource/ObjectDB cleanup warnings on exit. No new frame-rate claim is made.

The exported universal macOS app passes all 21 final shuffle assertions and strict code-signature verification. Updated release: `build/Goemon.app` and `build/Other Files/Goemon.zip`. Previous release: `build/Other Files/before-map-shuffle-20261003/`.

Follow-up: Y replaces F5. The updated 22-assertion suite also verifies that Y is bound and F5 is unassigned. Combo damage scaling and validation are documented in `tests/attack-chain/README.md`.
