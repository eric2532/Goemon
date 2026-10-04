# Manual combat adventure update · 2026-10-03

Combat remains manual. Hit grace is 1.75 seconds, with HEATED at 25 links, BLAZING at 50 and the existing instant-cast UNLEASHED state at 100. The earlier speed/damage caps remain. Milestone notifications require confirmed hits.

Buildings gain two visible damage stages: shared procedural crack overlays below 75% health, then a missing authored roof below 40%, including removal of its collision. Cutaway updates preserve the missing roof. Whole-building destruction still clears collision and navigation, grants growth once and leaves bounded cosmetic rubble. Each regular building reveals one existing combat pickup (attack speed, ice or fire), capped at 96 loose pickups with the existing expiry timer. Elemental set effects now run in descent mode; survival-mode magnet spawning remains specific to survival. Objective shrines grant an island upgrade instead of a pickup.

Growth increases ordinary enemy knockback up to 2.5×, elite knockback up to 1.6×, and giant/boss knockback up to 1.2×, before existing resistance. Elites have 1.6× size and 2× health and remain part of the existing roster/spawn budget.

Islands cycle through elite, guarded-shrine and 25-second ambush objectives. Survival advances only near that island and while gameplay is active. Only nearby shrines allocate scene nodes; unfinished shrine health and damage stage survive unloading. An objective grants one banked reward and stops that island's reinforcements. Defeating remaining guards marks it fully cleared. F opens a paused upgrade menu; Escape defers without losing the choice. Power grants +10% damage (10 ranks), Vitality +10% maximum health (10 ranks), and Tempo +5% attack speed (5 ranks). Upgrades add within their category and multiply existing bonuses. A capped choice becomes a heal. New runs and Y clear rewards, upgrades and objective progress; character switches preserve them.

Validation:

- Adventure: 38 headless assertions passed, including no automatic attacks, each objective, shrine streaming, real manual input completing an elite, pause/off-island timers, UI choice/deferral, duplicate prevention, upgrade cap, elemental pickup effects and reset from the upgrade menu.
- Rendered adventure: 37 assertions passed before the added elemental-pickup assertion. Inspected the elite encounter, upgrade menu and guarded shrine. Removed redundant shrine label overlap after inspection.
- Existing checks: combos 61, destruction 33, real-building contact 31, map shuffle 22 and terrain/navigation/patrol 10 passed headless.
- Rendered building contact: seven assertions passed; normal inputs damage a regular house, progressively remove its roof, destroy it and grant growth. Captures are under `tests/destruction/` and ignored by Git. Crack appearance was iterated against these captures.

```sh
godot --headless --path . --fixed-fps 60 -- --adventure-test
godot --path . --fixed-fps 60 -- --adventure-visual
godot --path . --fixed-fps 60 -- --building-contact-visual
```

These checks validate behavior and visual layout, not a new frame-rate claim. No extra rigid-body destruction simulation or per-island offscreen actors were introduced.

The universal macOS release passed all 38 adventure assertions and strict code-signature verification. Its headless exit logged the same single dummy-renderer shader RID cleanup warning as the previous release, with no script errors. Installed at `build/Goemon.app`; the ZIP is under `build/Other Files/Goemon.zip`, and the previous release is preserved under `build/Other Files/before-adventure-20261003/`.
