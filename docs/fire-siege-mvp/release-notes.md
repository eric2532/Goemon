Fire Siege v0.2 is now a playable MVP on the previous Fire Siege build.

- Start with **10 gold**, **12 empty tower sites** and an unbuilt mine.
- **Hold B** at a front pad to construct: arrow tower **5 gold / 3 seconds**; mine **10 gold / 4 seconds**. Release reverses progress; moving interrupts work. Payment happens once on completion.
- Towers launch visible **50-damage arrows every 0.5 seconds** and consume **0.1 gold/sec** during combat. At zero funds they pause. The mine earns **2 gold/sec during spawning**.
- **Hold Y for 3 seconds** after unlimited preparation. Ten waves each spawn **300 enemies over 60 seconds**, then wait for clearance. Wave N pays **10 × N gold**; kills retain XP/healing but give no gold or items.
- Hero death keeps the siege running. Enemies move 35% faster until automatic revival after five seconds. Beta offers **V / Revive Now**; right-drag looks around while downed.
- Updated economy and hero HUD. Existing characters and their designs are preserved.

Reuses the newly published arrow-tower, gold-mine and construction-FX assets from `codex/fire-siege-economy-assets-v1` (`9b63371`). No replacement character art is included.

**Downloads:** macOS universal ZIP (Apple Silicon + Intel) and Linux x86_64 ZIP. On Linux keep the executable and PCK together; launch instructions are included. macOS is ad-hoc signed, not notarized.

**Verification:** 478 acceptance/regression checks pass across six suites. The exported macOS app passes 40 integration checks and the complete graphical walkthrough. The exported Linux resource pack passes 117 campaign checks on macOS; native Linux execution is untested. Source asset inventory/checksums pass. See [verification](https://github.com/eric2532/Goemon/blob/fire-siege-v2.32.0-mvp/docs/fire-siege-mvp/verification.md) and [MVP decisions](https://github.com/eric2532/Goemon/blob/fire-siege-v2.32.0-mvp/docs/fire-siege-mvp/decisions.md).

This prerelease establishes the gameplay loop. Next polish should focus on mine-first versus tower-first balance, clearer combat/build feedback, and broad performance testing. Character redesign remains deferred.
