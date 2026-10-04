# Level-scaled coin volleys — 2026-10-03

Toggle 2 now throws one coin per character level: 1 at level 1, 10 at level 10, through 99 at the level cap. The next volley reflects a level-up immediately, without toggling off/on. R makes the whole volley piercing giant coins; the robe retains its single additional regular coin. The HUD shows the live per-volley count.

Each extra coin has its own physical swept path and damage. The central coin preserves exact nearest-visible-target aim; the remaining coins form a bounded forward fan. Coin hits still advance and refresh the combo, with one link per landed volley rather than one per coin. All coins in that volley share the same damage snapshot. Coins, including manual coin attacks, never trigger red bonus slashes. Pipe strikes, wind spins and melee chain sweeps retain their red bonus attacks.

## Performance implementation

Large volleys use one `coin_volley.gd` controller and shared MultiMesh instances, rather than one scene and physics callback per coin. Each volley filters nearby enemies once per physics step, reuses its ray-query object, and merges damage feedback by victim within each step. This preserves total damage and individual wall/piercing checks while reducing repeated scene creation, sounds and damage labels. Instances cast no shadows and do not create a separate trail node for every coin. The existing 0.42-second base cadence and 0.12-second minimum remain.

At level 99, maximum growth and with the robe, the four-second sustained-fire test peaked at 1,000 live coins across 20 projectile controllers / 10 instanced volleys. With four speed pickups and 100 combo links it peaked at 600 coins across 12 controllers / 6 volleys. The stress test checks bounded lifetime/scene growth; it is not a claim of a measured FPS improvement.

## Validation

Godot 4.6.1, fixed physics at 60 Hz:

- `--coin-scaling-test`: 37 assertions, zero failures.
- `--coin-scaling-visual`: the same 37 assertions, zero failures; inspected level-10, level-99 and sustained-volley captures.
- `--attack-chain-test`: 61 assertions, zero failures, including removal of the old ranged red bonus and preservation of melee bonus damage.
- `--destruction-test`: 33 assertions, zero failures.
- `--sky-combat-test`: 45 assertions, zero failures.

The new suite verifies the full level curve, exact coin counts, instanced rendering, each coin's real damage, shared combo attribution, aggregated feedback, live level-ups, R/robe behavior, melee-only red bonuses, two-target piercing with no repeated damage, cover, building destruction/growth, pause/resume, expiry, maximum-level stress and reset cleanup.

The exported macOS app also passes all 37 coin-scaling assertions. Signature verification passes using `codesign --verify --deep --strict`. The known single `RendererDummy...DummyShaderE` RID warning still occurs at packaged headless shutdown; there are no script errors or assertion failures. Rendered validation has no engine errors.

## Release

- Current launcher: `build/Goemon.app`.
- Current ZIP: `build/Other Files/Goemon.zip`.
- Previous app and ZIP: `build/Other Files/before-coin-scaling-20261003/`.

Use the current launcher to play the new version; already-running game processes need to be reopened.
