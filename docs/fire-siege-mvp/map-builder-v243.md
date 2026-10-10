# Map builder · v2.43

User requested an in-game map builder and new assets. Implemented only in latest `codex/fire-siege-mvp` worktree; prior v2.42 Ranger work preserved.

## Use it

Open **BUILD YOUR OWN MAP** on the main menu. Start with the editable Fire Siege Garden or choose Blank. The first version uses a flat160×310m field, one enemy route and up to512 pieces/64 route waypoints. Grass floor and perimeter are supplied automatically.

Choose a piece from the scrolling library; click the map to place it. R rotates the placement preview. Choose Select / V, click a piece, G then click to move it, R to rotate, Duplicate to copy, Delete to remove. Required hero/entrance/shrine markers move rather than duplicate and cannot be deleted. Right/middle drag or WASD pans; wheel zooms; Fit shows the field. Snap chooses1/2/4m. Undo/Redo or Ctrl/Cmd+Z / Shift+Z restore edits.

The route automatically connects the enemy entrance, numbered waypoints in order, and shrine. Add/move route points; Route ↑/↓ changes their order. Zoomed-out T/M labels are tower/mine sites. Other pieces are ground, structures or nature. The game validates the whole route corridor, site footprints, hero and all16 ally formation slots before Play Map; it explains any blockage.

Enter a name, Save, then Load to reopen named maps. Replacing a different map with the same filename asks first; errors preserve the draft. Unsaved changes prompt Save & continue / Discard / Cancel before leaving or replacing a map. Play Map uses a copy of the draft. During play, Esc → Return to map builder keeps it available. Save files are independent of the application bundle.

Saved JSON lives at `user://maps` in the Fire Siege user's data directory (normally `~/Library/Application Support/Godot/app_userdata/Goemon Fire Siege/maps`). The editor preserves the loaded save slot across play/edit. The standard Fire Siege menu continues to use the original map.

## New asset kit

Four ground pieces: grass, sand, stone paving and road. Eleven scenery pieces: stone wall, fence, torii, pavilion, lantern, crates, banner, bamboo, cherry, cedar and boulder. Six gameplay pieces: hero spawn, enemy entrance, shrine, route waypoint, arrow tower site and mine site. Native meshes and collision boxes are authored in `scripts/map_pieces.gd`; they require no download or third-party dependencies. Existing supplied tower/mine art remains in playable maps.

## Architecture

MapDocument provides bounded schema validation, history and atomic saving. MapPieces shares geometry/collision footprints across edit/validation/play. MapBuilderWorld adapts a document to existing Fire Siege world interfaces. MapEditor has an isolated3D preview, so editing never attacks or changes underlying actors. Custom route traversal and knockback recovery support horizontal/reversed paths; both native enemy breach checks require reaching the final segment. HUD structure totals use actual custom map site counts.

## Verification

All497 source checks and233 exported-package checks passed. A separate fresh app process reloaded the map saved by the preceding process. Native mouse/keyboard tours captured3 screenshots each from source and package. Strict signature verification passed, and installed executable/PCK hashes match the tested export. A v2.42 backup is at `build/Goemon Fire Siege before Map Builder v2.42.app`.

Verification details and packaged identity are recorded in `build/map-builder/build-info.json`; rendered source/package screenshots and test logs are in that directory. Existing headless shutdown resource warnings are documented in the logs. No commit, push or publication requested or performed.
