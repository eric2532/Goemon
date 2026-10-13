# Fire Siege MVP v2.37 — Linux package

The user requested a Linux build alongside the published v2.37 macOS build.
Both use the runtime source at `f567028c01e7f6c3520fb0e8e3fb21936e70c6a6`,
tagged `fire-siege-v2.37.0-mvp`. This follow-up only changes publication docs.

Exported with the existing **Fire Siege Linux** preset in Godot 4.6.1. The
executable is a stripped Linux x86_64 ELF, with its resource pack kept alongside
it. The ZIP preserves executable permission and includes launch instructions.

The exported Linux PCK was loaded from outside the source checkout using the
local macOS Godot engine. It passed 41 equipment/combat checks and 13 scarf
checks, covering the current character models, airborne Dragoon landing,
Ranger timing/projectiles and scarf animation/reset behavior.

This validates the exported game data and scripts. Native Linux executable
startup, graphics drivers, input and audio have **not** been tested on Linux;
no Linux runtime is available on this host. The packaged Mac binary disables
external PCK overrides, so the local Godot engine was used for these checks.

Download `Goemon-Fire-Siege-v2.37.0-Linux-x86_64.zip` from the existing
[v2.37 MVP release](https://github.com/eric2532/Goemon/releases/tag/fire-siege-v2.37.0-mvp).
Extract the entire folder, keep its executable/PCK together, and launch:

```sh
./Goemon-Fire-Siege.x86_64
```

If extraction dropped the executable bit, run
`chmod +x Goemon-Fire-Siege.x86_64` first. `SHA256SUMS.txt` on the release covers
both platform ZIPs and the review assets.

Local export/test/upload evidence is under
`build/releases/fire-siege-v2.37.0-mvp/`.
