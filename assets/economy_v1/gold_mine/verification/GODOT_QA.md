# Godot 4.6.3 isolated asset checks

Both tested routes pass without engine errors or warnings:

1. Runtime import with `GLTFDocument.append_from_file` followed by `generate_scene(state, 30.0, false, false)`
2. Standard editor import to a PackedScene with `animation/remove_immutable_tracks=false` and `nodes/use_name_suffixes=false`

## Assertions

- 248 MeshInstance3D nodes, 9,404 triangles, 18 distinct named materials, no missing surface materials
- Four clips with exact names and durations: build 2 s, reverse_build 2 s, work_loop 4 s, upgrade_preview 2 s
- Build at 0 seconds shows only shared site geometry and unbuilt stakes
- Build at 1 second shows foundations, growing posts, and temporary scaffold; the working cart is still hidden
- Build at 2 seconds shows complete base mine, no construction scaffold or survey stakes, and the cart at its intended Z=1.56 position
- Repeated forward/backward seeking restores the same partial-build transforms
- Reverse endpoints equal the opposite build endpoints
- The working cart travels along Z and returns exactly; the interior pick rotates; looping can be set explicitly
- Godot-space sockets remain build `(0,3.2,0)`, income `(0,2.4,1.3)`, entrance `(0,0,1.25)`

## Issues found and fixed

- Exact-zero scale endpoints caused Godot basis-decomposition errors. Hidden-stage scales now use 0.00001 in the GLB and editable Blender source
- Godot’s default immutable-track optimization dropped the cart’s constant translation track. Disable that option to preserve placement during scale-only construction animation
- Godot’s editor name-suffix processor renamed work_loop to work. Disable name suffixes to preserve the shared clip contract

The import settings are also recorded in `godot_import_settings.json`. Godot 4.6.3 recognized the work_loop name as looping even with name preservation; an explicit LOOP_LINEAR assignment remains a portable integration choice.

## Reuse the runtime check

From the unpacked goldmine_v1 folder, run:

```
godot --headless --path verification/godot_import --script check_mine.gd
```

The default source path is resolved relative to the harness. An absolute GLB path can instead be passed after `--`. In a locked-down environment, set HOME and XDG_DATA_HOME/XDG_CONFIG_HOME/XDG_CACHE_HOME to writable temporary folders before launching Godot.

The editor route additionally requires copying the GLB into the harness folder as `mine_under_test.glb`, importing it with Godot, setting the two import parameters above, and reimporting. Then run the same command with `-- --packed`.

Reports: `godot_import_report.json` and `godot_editor_playback_report.json`. These are isolated asset tests, with no game project changes or gameplay/economy verification.
