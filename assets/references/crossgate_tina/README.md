# Tina map references

The adjacent Magic Power BlueCG client is authoritative for every recorded
cell. These read-only LS2MAP files come from the same pinned reference already
used by the western recovery: `linv2/Crossgate_Docker`, commit
`dd8690ed3df11e4eb5a038a54079a8f40d8e93b3`. `references.json` records each URL,
Git blob identity and SHA-256. They contain layout data, not executable code.

`tools/recover_original_crossgate_maps.py` fills only cells without the client
recorded flags. It preserves all three original planes and keeps the three
daytime client sign variations. The night layout matches all 4,126 recorded
client cells; daytime matches except for those three signs. The food shop
(4206) and night teleport room (4232) have no client snapshot and are labelled
`reference_only` in the runtime catalog. Their reference provenance must not
be described as verified original BlueCG data. Unproven entrances are not
invented. Original source dimensions, native serials and coordinate anchors
are retained; 3D depth and unseen faces remain reconstructions.

The exported runtime uses the prepared catalog/atlases; this source folder is
excluded from Godot scanning and exports. Verify with
`python3 tests/forest-shrine/test_tina_source.py` and the recovery tool's `--check`.
