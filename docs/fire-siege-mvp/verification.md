# Fire Siege v2.32.0 MVP verification

Verified 8 October 2026 with Godot 4.6.1 on macOS / Apple M3. The implementation
starts at `81b9f0b69ea6b0fef3c3b832d24641ca64eb8640` and imports economy assets from
`codex/fire-siege-economy-assets-v1` at `9b63371`. Current user instructions authorize
implementation, delegated decisions and GitHub release publication. The copied
handoff remains an immutable reference; its older publication/decision instructions
do not replace that authorization.

## Automated acceptance

Run `python3 tools/verify_fire_siege.py` from the checkout. It runs each suite with a
240-second timeout, checks the result marker and exit status, and rejects script
errors even if Godot exits zero. Logs and JSON results go to `build/verification`.

| Suite | Command after `godot --headless --path .` | Result |
|---|---|---|
| Deterministic state | `--script scripts/fire_siege_state_tests.gd` | 63 checks, 0 failures |
| World, GLBs and projectiles | `--script scripts/fire_siege_structure_tests.gd` | 65 checks, 0 failures |
| Main-scene integration | `-- --fire-siege-mvp-test` | 40 checks, 0 failures |
| Ten-wave campaign and edge cases | `-- --fire-siege-campaign-test` | 117 checks, 0 failures |
| All twelve heroes and shared controls | `-- --fire-siege-controls-test` | 134 checks, 0 failures |
| Legacy Three Gates / mode transitions | `-- --tower-defense-test` | 59 PASS assertions, 0 failures |

Total: **478 checks/assertions, zero failures**, all processes exit zero. The campaign
uses actual game actors and production damage/breach/settlement paths for all 3,000
scheduled enemies, with accelerated ticks and controlled enemy physics. This proves
accounting and transitions; it is not a ten-minute human balance playtest.

Coverage includes fractional income/upkeep, zero-funds firing, atomic purchases,
hold/release/decay, Y rearming, movement cancellation, stale generations, true arrow
impacts and world obstruction, all ten rewards, base-loss precedence, victory while
dead, five-second automatic revival, Beta skip and Hard restrictions. Existing
Goemon/Edo combat, twelve hero controls and other mode transitions are exercised.

A fresh independent code review found movement not interrupting work and the dead
hero camera being unavailable. Both were reproduced, fixed, and re-reviewed with
five additional regression assertions. No outstanding findings remained.

Early fast headless runs reported leaked WAV playback resources during exit. Both
integration and campaign teardown now use the existing 300 ms audio drain pattern.
Fresh verbose runs passed 40/0 and 117/0 without errors, warnings or leaked objects.

## Asset and visual evidence

`python3 docs/handoffs/fire-siege-economy-v0.2/verify_inventory.py` passes all 98
payload entries, checksum inventory, source provenance and self-contained GLB checks.
`shasum -a 256 -c docs/handoffs/fire-siege-economy-v0.2/SHA256SUMS.txt` passes all 99
listed entries. Added Godot import settings retain immutable tracks and exact names;
the authored GLB bytes are unchanged. No diff exists under `assets/rogue`,
`assets/characters`, `assets/models` or `assets/textures` against the pinned baseline.
No new character design was imported.

The Metal rendered walkthrough `--fire-siege-mvp-tour` completed both from source
and the unpacked release app. Eleven screenshots cover opening, half-build,
release/decay, completed tower, purchased mine, Y confirmation, mine working,
live arrows, native hero HUD, death and revival. Original Goemon portrait and native
hero portrait were visually inspected; long hero names fit beside the level label.
The separate real-asset rendered test also passed 65 checks and its screenshot was
inspected, although that standalone Metal test required termination after its
completed shutdown. The full packaged walkthrough exited normally.

Source captures: `tests/fire-siege-mvp/` (generated, ignored).
Packaged captures: `user://fire-siege-mvp-captures/`.

## Export verification

macOS export command:

```sh
godot --headless --path . --export-release 'Fire Siege macOS' 'build/releases/Goemon-Fire-Siege-v2.32.0-macOS.zip'
```

The universal app contains arm64 and x86_64, version 2.32.0, and passes
`codesign --verify --deep --strict`. ZIP integrity passes. Its executable was launched
outside the source directory and passed all 40 integration checks using its own
resource pack. The packaged graphical walkthrough completed, and a normal launch
showed the new difficulty and hero selection menus. It is ad-hoc signed, not notarized.

Linux export command:

```sh
godot --headless --path . --export-release 'Fire Siege Linux' 'build/fire-siege-linux/Goemon-Fire-Siege.x86_64'
```

The ZIP contains the x86_64 ELF executable, PCK and launch instructions. ZIP integrity
passes. Loading the exported PCK through the local Godot engine outside the checkout
passes all 117 campaign checks. Native Linux execution and Intel Mac hardware were
not available for verification. Neither export reported script or resource errors;
the expected warning about ignoring the supplied asset-validation subproject is benign.

## MVP limits and next work

The selected upkeep, timings, speed multiplier and clearance economy are delegated
MVP choices documented in `decisions.md`, not claims of final balance. Mine-first
investment is powerful; compare opening strategies and upkeep affordability in
human playtesting before changing approved prices or rewards. No new character art,
boss escalation, cards, tower tiers, mine upgrades or ammunition systems were added.

Historical beta/tactics/fire fixtures that expect old starter batteries, cards and
wallets are retained as legacy references and are not redesigned-mode acceptance
tests. This report does not claim that every historical repository suite passes.
Graphics were checked at 1440×900; broad hardware/performance and resolution testing
remain polish work.
