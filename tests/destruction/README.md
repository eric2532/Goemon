# Building destruction, growth and 100-link attacks

The 157 houses, furnished buildings and temples have 240 health. All outgoing weapon/spell damage uses the existing per-cast combo ticket and multiplier. Buildings award combo credit on contact, growth once on destruction, and no enemy kill or level rewards. Static geometry is hidden and its collision disabled; enemy navigation is invalidated once per frame. Cosmetic rubble has no collision, expires after 4.6 seconds and is capped at 96 pieces.

Every destroyed building adds 2% player size and attack reach, with a 2× cap. The physical capsule and camera accommodate growth. Melee, red follow-ups, coins, chain attacks, fireballs, beam, shield, meteors and movement-attack blast areas scale with size. Growth resets with the run.

At 100 links, Goemon's mouse and number attacks bypass startup, recovery and the pending queue. Each light pipe input resolves its three-hit sequence immediately. Edo's 1/2/3 release volley/giant fireball/meteor rain; mouse casts, shield, beam startup, dash, teleport and Sky Strike also release immediately where applicable. Projectile travel and sustained pulse cadence remain physical. Expiry restores ordinary timing; pause still blocks input.

Validation on 2026-10-03:

- Destruction suite: 33 assertions passed both headless and rendered. Covers actual input dispatch, real projectile/building collision, cover, exactly-once hits and growth, collider removal, size cap, expanded reach, grounded enlarged player, repeated instant casts, 99/100 threshold, combo expiry, Edo spells, movement attacks, cutaway visibility and restart cleanup.
- Existing suites: confirmed combos 61, direct attacks 28, firecaster 49, furnished districts 48, map shuffle 22 and terrain/patrol/navigation 10 assertions passed headless.
- Rendered captures inspected: building before/after, 2× character and reach HUD, and instant multi-attack effects with the UNLEASHED HUD. No new runtime errors were logged. This is functional validation, not a frame-rate benchmark.

```sh
godot --headless --path . --fixed-fps 60 -- --destruction-test
godot --path . --fixed-fps 60 -- --destruction-visual
```

The fixture tests use a simple building collider and prime combo tickets to isolate threshold behavior. The building registry assertion checks the actual generated map; furnished-room destruction checks the real cutaway logic. Test captures are generated locally and ignored by Git.

The exported universal macOS app also passed all 33 destruction assertions and strict code-signature verification. Its headless exit logged one dummy-renderer shader RID leak; no script errors occurred, and the source headless/rendered runs logged no errors. Current release: `build/Goemon.app`, with its ZIP under `build/Other Files/Goemon.zip`. The previous app and ZIP are preserved under `build/Other Files/before-destruction-20261003/`.

## Regular-building follow-up

Building health is now 240, with an on-screen health bar, throttled hit debris/audio and a destruction/growth confirmation. The earlier 600-health version passed direct contact checks against real geometry; the reported failure was not reproduced. The follow-up improves feedback and makes demolition practical with a few connected swings rather than assuming that fixture tests alone establish the player experience.

`--building-contact-test` passes 31 checks, exercising normal attack inputs against reachable sides of actual closed town-house variants, furnished buildings and a temple. It also fires a normal key-2 projectile into a real town house and destroys that house with three subsequent right-click presses, awarding growth once. `--building-contact-visual` passes seven checks for a real regular house; inspected captures `05-real-house-hit.png` and `06-real-house-broken.png` show its HUD health and removal. The existing destruction suite passes all 33 checks with the new health. These tests do not claim that every approach to every building was sampled.

The installed feedback release passed all 31 contact checks and strict signature verification. Its headless exit has the same dummy-renderer shader cleanup warning noted above. The previous release is preserved under `build/Other Files/before-building-feedback-20261003/`.
