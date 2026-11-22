# Saizo (サイゾウ)

Saizo is fighter 39. Shigure (106477, `joy:676`) is his default skin.
The skin picker saves the original sprite ID for each of the thirteen looks.
Every skin has a sword record and an unarmed record. Kunai and Fist use the
unarmed movement frames. The wardrobe uses the source standing portrait.

Recover the prepared atlases from the preserved Magic Power archives:

```sh
python3 tools/recover_crossgate_saizo.py '../Magic Power'
```

The atlas keeps the original eight directions, frame origins and pixels.
Idle, walk, run, cast, hurt, guard and fall keep their source frame order and
duration. The shared jump controller selects takeoff and landing poses from
those clips. Sword attacks keep their original fourteen frames over one second,
with one swing on frame 5 and one contact on frame 6. Existing attack-speed
modifiers scale that clock through the shared controller. Punch and throw
drawings retain Maze's existing contact and release times.

The shared Maze controller owns the moveset, targeting and cooldowns. Prepared
source audio follows each selected clip; rebuild it with
`python3 tools/prepare_crossgate_player_audio.py '../Magic Power'` after recovery.
Goemon's prepared footstep and landing samples are the defaults.
Mirror Image copies the current skin and weapon when it casts and shares the
selected atlas across the five pooled bodies.
