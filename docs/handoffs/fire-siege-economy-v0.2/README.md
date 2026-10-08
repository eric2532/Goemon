# Fire Siege economy assets and redesign handoff

## Status

This is an **asset and implementation-specification handoff** for later Astra or
Codex implementation. The editable 3D assets, runtime GLBs, authoring sources,
and isolated asset validation reports are included. **The redesign is not
integrated into the game.** No existing gameplay script, scene, project setting,
or release package is changed by this handoff.

The package is based on repository `eric2532/Goemon`, commit
`81b9f0b69ea6b0fef3c3b832d24641ca64eb8640`. Its intended publication is a new
asset-handoff branch; it does not update `main` or the original
`codex/fire-siege-universal-controls` branch.

## Read first

Start with `ASTRA_START_HERE.md` for the concise Astra implementation prompt,
then read the complete specification and exact contracts below.

1. `fire_siege_redesign_v0_2.md` is the implementation specification
2. `fire_siege_redesign_decisions_v0_2.json` separates confirmed decisions,
   unresolved questions, and proposals
3. `fire_siege_asset_contract_v0_2.json` maps assets to the implementation
4. The matching DOCX is an editable review copy
5. The asset-specific README files and QA JSON give exact node, animation,
   dimensions, and import contracts
6. `SPEC_README.md` is the specification author's original overview
7. `assets/economy_v1/presentation/combined_demo/` contains a separate editable
   Blender demonstration with the actual tower, mine, and effects together,
   one hero render, authoring scripts, and its validation report

Treat unresolved values and visual upgrade proposals as unresolved. Illustrative
preview animation lengths are not approved gameplay build, decay, or fire rates.

## Runtime assets

From the repository root:

- `assets/economy_v1/arrow_tower/exports/`: four construction-stage GLBs,
  an optional wall collar, the animated tower, and the standalone arrow projectile
- `assets/economy_v1/gold_mine/goldmine_v1.glb`: mine with build, reverse-build,
  work-loop, and optional visual-upgrade clips
- `assets/economy_v1/construction_fx/exports/`: hammer loop, progress frame,
  optional B prompt, and completion pulse

All 12 runtime GLBs embed their mesh/material data. They require no external
texture files. Asset orientation is Blender +Z up / -Y front, converted by the
standard glTF exporter to +Y up / +Z front. Read each asset's root and socket
contract before applying any gameplay-parent rotation.

The tower animation should be imported at 24 FPS to preserve its authored short
endpoints. Its stable identifiers are retained in glTF extras, but Godot does
not automatically expose arbitrary extras as node metadata. Use the retained
unique node names and supplied manifest as the integration interface.

For the mine, set `animation/remove_immutable_tracks=false` and
`nodes/use_name_suffixes=false` in Godot's import settings so constant tracks
and authored node names that restore the correct stage state are retained.
Use its included isolated QA harness and report to check the exact behavior.

## Editable sources and reproducibility

Each Blender source is stored as `*.blend.gz`, with deterministic gzip metadata.
Decompress it before opening it in Blender 4.3.2 or a compatible newer version:

    gzip -dk path/to/asset.blend.gz

The decompressed bytes match the original source SHA-256 recorded in
`SOURCE_PROVENANCE.json`. The tower and mine were already internally compressed
by Blender; the outer gzip wrapper is a portable archive without a source edit.
Do not commit the decompressed copies as duplicates.

Included Python scripts preserve the original authoring workflow. Some use
producing-workspace absolute paths. Set their input/output paths for your own
workspace before rebuilding; those historical paths are not runtime dependencies.
The authoring scripts are not loaded by the game. QA subprojects and tooling
directories have `.gdignore` files to avoid accidental import into the game.

Selected readable PNG contact sheets are included. Full videos, per-frame render
directories, caches, Blender backup files, logs, Library-transfer metadata, and
duplicated delivery ZIPs are deliberately excluded. Some original package README
files mention those omitted delivery previews. They are not runtime inputs.
The original asset manifests may also list omitted delivery previews; the
handoff-level `INVENTORY.json` is the exact committed package inventory.

## Verification boundary

The supplied reports record Blender 4.3.2 round-trip validation and isolated
Godot 4.6.3 import/playback checks. See the exact checks in each report. These
tests do not validate the target game's gameplay or presentation.

The later implementation still needs target-project import settings, scene
attachment, collider/hitbox/navigation setup, runtime LOD/batching decisions,
input and UI wiring, authoritative economy state, pause/setup gating, game
balance, save behavior, and end-to-end gameplay acceptance tests. A successful
asset import is not evidence that those features exist.

The optional combined demonstration is presentation-only, with explicitly
illustrative timing. It is excluded from Godot import with `.gdignore` and does
not add an integrated game scene. Its animated preview is delivered separately;
the original demo README's video reference is not a committed repository file.

## Integrity

Run from the repository root:

    python3 docs/handoffs/fire-siege-economy-v0.2/verify_inventory.py

`INVENTORY.json` lists payload SHA-256 and Git blob SHA-1 values. It excludes
itself and `SHA256SUMS.txt` to avoid self-referential hashes. `SHA256SUMS.txt`
also covers the inventory. The repository commit supplies integrity for the
checksum file itself.

See `PROVENANCE.md` for asset origin and licensing scope.
