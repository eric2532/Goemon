# Forest portals and roads

Extend the building-view editor with rotatable enemy spawn portals and paintable dirt roads. User selected flexible lanes: enemies follow a road toward the base but may leave it to engage nearby targets, then resume remaining forward progress. Existing destructible walls/gates can block and shape routes; enemies keep their existing collision, attacks and breaching behavior.

Portals replace default edge spawning only when at least one is authored. Preserve wave composition, batch size, cadence and active cap. Distribute releases across portals, avoid terrain/building/actor overlaps, and allow visible portal arrivals. Portal facing defines the exit. Invalid or congested exits never consume pending enemies. Giants require their existing full clearance; map validation rejects blocked exits/road corridors that would strand them.

Paint roads with click/drag and selectable one-, three- or five-cell width (default five for giant clearance). One stroke is one undo; painting clears trees in that footprint and saves all changes together. Roads are walkable ground, permit structures/walls/gates on top, and do not change allied pathfinding or visibility. Connected road paths choose progress toward the base; disconnected scenery roads do not affect enemies.

Save portals/roads as optional additions to schema1 so existing custom maps and the immutable Original Map keep working. Extend selection, delete, undo, preview, save/load and restart. Render inexpensive procedural portals and batched road tiles; retain low-fidelity enemies. Rebuild and verify native packaged app; preserve previous build and original snapshot.
