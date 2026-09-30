# Goemon 2.16.0 — robe coin attacks

- Rendered coin suite: 27 checks passed; inspected `01-spin-coin-ring.png`.
- Cloak regression: 33 checks passed, including movement, all four jumps, switching characters, E and T.
- Chain-pipe regression: 29 checks passed. The existing headless shutdown resource warning remains in that suite's log; all gameplay assertions passed.
- Exported Mac app coin suite: 27 checks passed, exit 0.
- Universal macOS export succeeded. Bundle version is 2.16.0; strict deep signature verification passed.

The coin suite verifies actual damage outside melee reach, exactly one bonus per combo contact/chain attack, 16 distinct radial projectiles per spin, full-speed buffs, normal/giant coin-weapon behavior, solid cover, removing the robe, interrupting windup, pausing/resuming and Edo isolation. The final rendered and packaged runs supersede the initial headless test log, whose observer originally counted Edo's fireballs as coins (they inherit GoldCoin) and expected paused windups to resume despite the game's existing cancellation behavior.

The previous 2.15.1 app, archive and edited source files are preserved under `backups/robe-coins/`.
