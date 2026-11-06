# Cannon impact

`impact.tscn` prepares five original CannonTowerMissile death emitters using their
native textures, colors, size curves, velocity and gravity at .06 metres per
Warcraft unit. The original short emission windows become one-shot bursts. The
flight-only emitter is excluded from the impact. Native model/texture originals
are preserved under `assets/references/warcraft_human_buildings/original/`.

The existing Rogue projectile visual pool warms and reuses shells and bursts.
`forest_tower_arrows.gd` resets emission, transforms, visibility and lifetime;
`forest_workforce.gd` owns flight, collision and one native splash delivery.
The scene has no attack callbacks and cannot deal damage. Preparation workbench:
`build/Other Files/Asset Toolkit/Human Cannon Tower/prepare_burst.gd`.
