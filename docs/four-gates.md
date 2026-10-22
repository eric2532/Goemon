# Four Gates

Fresh Forest runs now use **Four Gates**: one gate on each of the north, east, south and west sides, with two defending towers and two portal approaches per side. The eight portals feed four matching pairs of 18m-high stone wall routes. Each pair joins before a continuous ramp down to its gate. The exterior fort, roads, raised terrain and portal exits are quarter-turn copies of the southern design.

Both mines sit inside the tower ring with clear worker entrances. Existing wave totals, combat, character stats and enemy roles are unchanged; scheduled arrivals rotate through all eight portals. Portal floor swirls keep the east/west entrances readable from the overhead building camera.

The building camera opens centered on the full map. Mouse-wheel zoom now reaches 600 so the expanded layout can be framed again after zooming in. **Map Editor → Four Gates**, **Twin Ramparts**, and **Original Map** load separate presets. Existing named custom maps retain priority and are never replaced by this default. The former two-portal map and the protected original JSON are unchanged.

`tools/build_four_gates_map.py` deterministically creates `assets/maps/forest_four_gates.json` from the preserved Twin Ramparts template. Model validation exercises all four roles from all eight origins, physical-surface continuity, rotational footprints/roads, exact scheduled wave counts and old preset access. Scene validation checks the new default, eight visible physical portals, four ramp colliders, camera framing, editor preset buttons and custom-map priority.
