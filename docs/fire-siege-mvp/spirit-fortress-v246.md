# Fire Siege · Spirit Fortress effects · v2.46.0

## Result

This version starts from the latest pushed Fire Siege v2.45 source,
`origin/codex/fire-siege-mvp` at `8758b7369f158c86a05a0fdb0558f3d1f6a2ef2a`.
It adapts the eight techniques from the exact standalone source asset in
`marc-prototypes-macos-2026-10-10`. The automatic GitHub source archive
is a full-game reference snapshot and is not the demo's source.

The playable standard Fire Siege map now includes existing emissive materials
with bloom, four nearby warm lantern accent lights plus a cool shrine light,
116 CPU petals/motes, distance haze, two animated water/foam pools on the
field shoulders, shader wind in existing banners, six hovering stones
beyond the playable boundary, and a shrine rune pulse. Every addition is
visual; routes, movement, construction footprints, economy, hero mechanics,
map serialization and collision bodies remain as in v2.45.

The module belongs to the world and uses its pausable process clock. Restart
or mode change frees it with that world. The existing Graphics quality setting
controls the added rendering work: Medium enables it without new shadow maps;
High enables one shrine accent shadow; Low stops particles, lights and effect
processing, hides new scenery, restores original haze, and leaves existing
banners visible with static cloth. No renderer change is made: the game uses
Forward+ on Metal; the standalone demonstration retains Compatibility.

Playable custom maps receive spawn petals, shrine motes/runes/light, haze and
wind on every authored banner. No pools or hovering stones are inserted into
custom maps. Piece metadata identifies duplicate/rotated banners reliably;
the saved document schema stays unchanged. The map editor retains its clear
lighting and unmodified authored pieces.

## Source and build

The source ZIP and its full manifest were checksum-verified before use. See
[shader provenance](../../assets/vfx/spirit_fortress/README.md). The original
project was extracted separately under Downloads and launched successfully
with official `4.6.3.stable.official.7d41c59c4`.

The new universal macOS build uses that same Godot version and its matching
official macOS export template. The editor archive's SHA-512 matched the
official release digest. Only the macOS template entry and version file were
retrieved from the official template archive using HTTP ranges; both archive
entry CRCs and all entries of the nested macOS template ZIP were verified.
No claim is made to have downloaded or hash-verified the full 1.2 GB template
archive. Apple strict/deep signature verification and both binary architecture
checks are performed on the delivered app.

The finished app/ZIP is delivered separately in Downloads as
`Goemon-Fire-Siege-v2.46.0`. The prior v2.45 application is preserved.

## Verification

Regression commands use Godot 4.6.3. The original repository acceptance runner
`tools/verify_fire_siege.py` covers state, structures, integration, campaign,
controls and the older three-gate mode. Additional checks cover automatic
construction/attacks, both current Ranger suites, map building and equipment
combat. The new effects suite checks original sites/routes/funds, collision
isolation, quality switching, advancing/frozen clocks, restart cleanup, all
custom banners, custom geometry preservation, editor clarity and mode changes.
Rendered runs capture standard and custom maps on an Apple M3 using Metal
Forward+, validating shader compilation and visible output. No measured FPS or
hardware performance target is claimed.

Reproduce all headless checks after asset import:

```sh
python3 tools/verify_spirit_fortress.py --godot /absolute/path/to/Godot
```

To verify the exported resources with the editor executable, add
`--pack /absolute/path/to/Goemon\ Fire\ Siege.pck`. To run the exported app's
built-in acceptance suites, use its executable for `--godot` and add `--native`.
Release templates disallow path/script overrides, so standalone script suites
use the editor executable with the exported PCK. For rendered effects captures:

```sh
/absolute/path/to/Godot --path . --script res://scripts/spirit_fortress_tests.gd -- --spirit-captures
```

Detailed logs, test summaries, exported identity/hashes and any export-template
shutdown diagnostics are in `build/spirit-fortress`. The previous v2.45 manifest
also recorded Dummy-renderer/resource cleanup diagnostics in exported headless
tests; such diagnostics are listed separately from assertion/script failures.
The code review's duplicate-banner finding was reproduced (one animated banner
for three authored pieces), corrected with metadata, and covered by the suite.
