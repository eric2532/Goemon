# Enemy camps prototype

A disposable map for trying offensive objectives. The normal Blood Gulch map,
its wave counts, saved maps and desktop launchers are retained.

Open **Tools → Try enemy camps** during preparation. This starts a fresh run.
Use **Begin assault** to enter combat. **Tools → Return to normal map** starts a
fresh normal run. Restart preserves the selected mode for this game session.
Alternatively, run the existing launcher with the prototype flag:

```sh
/Users/eric/Desktop/Play\ Goemon.command -- --enemy-camps-prototype
```

- West, east and castle camps each have 600 HP. Live camps send continuous
  reinforcements through the existing native army system.
- The limit is **1,000 living soldiers total**, shared by all camps. A death
  frees a slot; this is not a lifetime spawn budget. Structures do not use slots.
- Destroying a camp stops its future reinforcements immediately. Soldiers
  already spawned remain alive. Destroyed camps stay destroyed until restart.
- After all three camps fall, destroy the 1,200 HP statue inside the open enemy
  castle courtyard to win. Keep your own statue alive throughout the assault.
- Red squares on the minimap mark live camps; muted squares mark destroyed
  camps. The gold outline marks the enemy castle statue.

This uses existing stone barracks, fort and statue art. Camps and the final
statue accept the existing player attack contract; castle walls are scenery.
The temporary map has no Halo portal visuals or finite waves. Reinforcements
repeat the Wave 1 mix selected in Core Game Balance, including Skullpion only
when its count is nonzero.
Its geometry and rules are kept outside the saved-map editor format, so the
editor is unavailable in this mode. No new app export is needed.

## Verification on 2026-10-23

The model test covers the 1,000-enemy cap, slot reuse, partial camp destruction,
continued spawning elsewhere, surviving soldiers, statue protection, victory,
layout preservation and restoration of normal finite waves.

The gameplay test runs Goemon's pipe and Chief's bullet path against camp
colliders, checks native movement obstacles and combat query inclusion, then
checks destruction, victory and returning to normal mode. It also supports a
rendered capture pass. The bounded combat and normal-map regressions passed,
and the asset preservation checker passed without asset changes.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/forest-shrine/enemy_camps_prototype_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/forest-shrine/enemy_camps_gameplay_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/forest-shrine/enemy_camps_gameplay_test.gd -- --capture --painterly-preview
```

Captures and logs are under `build/Other Files/`. These are functional and
rendered checks, not a sustained 1,000-soldier performance benchmark. Gameplay
balance, long battles and the eventual production layout still need playtesting.
The rendered harness currently emits resource warnings at process shutdown;
these runs do not establish whether resources grow during a long game session.
