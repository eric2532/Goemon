# Azure Ember v2.2 validation

Released 2026-09-24. Names: Goemon / Edo. Approved character geometry unchanged.

The standalone Metal build passed all 55 feature checks with no runtime warnings or errors. Real mouse-motion events steer the active beam left and right and damage newly swept targets. The three-second beam automatically grants fire-shield immunity and nearby burn damage, supports an independently timed R shield, works during R cooldown, and cleans up on expiry, character/weapon switch, evade and travel.

Regular enemies respawn indefinitely in fixed encounter slots. All six forward/backtracking transitions work without guardian kills. Large animated portals, labels, minimap diamonds, a direction marker and clear entrance foliage improve visibility.

## Results

- `packaged.log`: 55 passed.
- `visual.log`: 55 passed.
- `features.log`: 53 passed.
- `combat-regression.log`: 41 passed.
- `controls-regression.log`: 30 passed.
- `expansion.log`: 305 passed.

Headless feature tests explicitly skip OS mouse capture; the rendered source and packaged suites exercise it. Some source headless runs retain the existing ObjectDB/resource-at-exit warning. The final packaged Metal test is clean.

`codesign --verify --deep --strict` passed. Bundle version is 2.2.0. The prior v2.1 app and zip are preserved in `backups/edo-beam`. Current app and zip are in `build`.

Approved master SHA-256 remains `3542e31714cc4571e076f5b99b0dc81eb7cdbd859cf9d38393102f2b14d2004c`.
