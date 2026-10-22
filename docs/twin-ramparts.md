# Twin Ramparts

The preserved Twin Ramparts preset has two solid stone wall routes, each with an animated spawn portal. Both wall tops are 18m above ground. They join at a shared approach with a continuous ramp down to the existing main gate. All four enemy roles follow the route at its real elevation; the 30m wall tops preserve the giant's clearance. Players can walk up the ramp and fight on top.

The original shrine, fort, mines, worker jobs and infinite-health dummy remain. The map editor provides **Twin Ramparts** and **Original Map** buttons. Saved custom maps retain their own layout and raised terrain metadata; selecting an original/custom map takes precedence over the default. Construction keeps the fixed wall terrain and ramp entrance clear. The new preset is `assets/maps/forest_twin_ramparts.json`; `assets/maps/forest_shrine_original.json` is unchanged.

The renderer, native collision, AI, portal spawns, picking and height queries share `forest_ramparts.gd`. Optional `ramparts` metadata is backward-compatible with existing schema1 maps. Existing flat-map regression fixtures can request `--original-map`; production now defaults to Four Gates; this preset remains available in the map editor.

Verification and before snapshots: `build/Other Files/twin-ramparts-20261017/`.
