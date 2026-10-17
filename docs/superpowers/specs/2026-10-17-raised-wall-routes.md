# Raised wall routes map

User wants actual tall walls extending from the main gate, enemies spawning and walking on their tops, and real visible portals at wave starting positions. User selected two routes joining near the gate.

Build a new default `Twin Ramparts` layout: two long stone wall walkways, a shared elevated junction and central approach, a gradual ramp down to the existing main gate. A visible animated portal sits at the far end of each wall. Wall tops are 18m high and 30m wide so the existing giant can physically fit. Keep its gameplay dimensions and speed. Retain the shrine, economy, training dummy and fort.

The original map remains immutable and accessible from the editor's Original Map button. Add a Twin Ramparts preset button and retain custom-map editing/saving/loading, including raised terrain metadata. Do not overwrite saved user maps or balance/settings. Default new games use the new preset; an explicitly selected custom/original layout wins.

Enemy spawn roots, navigation points, movement, hits and native collision must agree on elevation. The routes guide all four enemy roles; cliff sides prevent shortcutting or knockback off the wall. Portals are visible landmarks before the first wave. Player can physically walk up the ramp and fight on the wall. Building view frames both routes and portals. Existing flat maps continue using their original behavior.

Scope: fixed authored raised-terrain segments with saved metadata; no general 3D terrain sculpting tool. Editor roads/portals can still be edited on top. Keep ordinary construction clear of the fixed raised terrain.
