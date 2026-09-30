# Goemon 2.18.0 — elemental orb prototype

- Rendered mechanics suite: 26 checks passed. Inspected the ice burst, frozen enemy, fire explosion, orb shapes, magnet and HUD counters.
- Exported app: 27 checks passed, including the additional menu VFX cleanup check. Exit code 0.
- Survival regression: 27 checks passed, including all 60 scheduled waves, 8,700 total scheduled enemies, victory/retry, combat and live wave timing. All 100 opening enemies closed on the hero during the pursuit check.
- Universal macOS export and strict deep signature verification passed; bundle version 2.18.0.

Coverage includes early attraction lock for fast movement, automatic pickup at six metres, exclusion beyond eight metres, yellow speed bonuses, randomized 1–5 drops without the old 48-orb cap, two-second freeze despite hits/knockback, paused timers, 100-damage fire bursts, cover, independent counters and remainders, twenty map-wide magnet pickups, retained elemental triggers, valid magnet placement, spawn sectors, varied approach directions, restart and menu cleanup.

Open-ground spawn samples covered all eight octants and produced 14 distinct approach headings. The shoreline fixture covered six available land octants; terrain and map boundaries still constrain surrounding spawns. This is not a performance stress test of leaving an entire ten-minute population and all drops uncollected.

Final evidence: `rendered.log`, `survival-regression.log`, `packaged.log` and the PNG captures in this folder. The initial headless log predates the corrected magnet-expiry fixture and separate coast/interior spawn assertions.

Previous app/archive and edited gameplay sources: `backups/elemental-orbs/`.
