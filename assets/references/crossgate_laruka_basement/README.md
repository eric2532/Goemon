# Recovered Saint Laruka interior

Immutable server-map references from `linv2/Crossgate_Docker`, commit
`dd8690ed3df11e4eb5a038a54079a8f40d8e93b3`. Exact URLs and SHA-256 hashes are in
`provenance.json`. These are data files, not executable dependencies.

- `02307_sozai` (2307, 原料店) fills the absent client cache. It contains the
  original 20×20 ground/object planes and 97 object placements.
- `02306_syokuryo` (2306, 食品店) is a comparison reference: both planes match
  the archived BlueCrossgate client map exactly.
- `02303_tikaroom` (2303, 地下工房) is a second comparison: its ground and
  nonzero object identities/placements match the client. Ninety empty/blocked
  sentinel cells differ. The existing client map remains authoritative for 2303.

The pinned warp table connects 2306 (7,3) ↔ 2307 (6,5). Do not fabricate another
connection or copy the server collision sentinels over an available client map.
The previous church labels were incorrect; the source headers identify a food
shop and materials shop. The ascending stair in 2306 and descending stair in
2307 identify the materials shop as the upper floor. Existing NPCs, dialogue
and quest owners remain. The old dungeon roof classification was a placeholder;
the recovered room uses the same cutaway presentation as other village rooms.

`tools/build_freyja_destinations.py` reads 2307 using its existing LS2MAP parser.
`tools/prepare_il_laruka.py` prepares its floor, furnishings and source manifest.
Original-map and fixed-camera renders are under
`build/Other Files/Asset Toolkit/Il and Laruka/`.
