# v2.47.0 performance comparison

Godot 4.6.3 Forward+ / Metal on the local Apple M3 Mac (8 GB RAM).
Both versions were tested serially with the same fixed camera and 300 real
active enemies. The requested window was 1280×800; the viewport texture-size
API reported 1138×712. This is an API-reported texture size, not a verified
physical framebuffer resolution.

Each effects-on sample has a two-second warmup and three seconds of measured
wall-clock frame timings. On/off/on samples are recorded; below are the two
effects-on samples per comparison. Effects-off disables the Spirit Fortress
module only; it does not remove the new map art or enemy roles.

| Test | v2.46.1 mean frame time | v2.47.0 mean frame time | v2.46.1 p95 | v2.47.0 p95 |
| --- | --- | --- | --- | --- |
| Medium, VSync | 16.66–16.68 ms | 16.66–16.67 ms | 19.14–19.70 ms | 19.49–19.56 ms |
| High, VSync | 16.67–16.76 ms | 16.66–16.68 ms | 19.65–19.82 ms | 19.35–19.59 ms |
| Medium, uncapped | 7.35–7.75 ms | 7.75–7.85 ms | 16.75–17.30 ms | 17.81–18.06 ms |

Both builds averaged approximately 60 FPS in the VSync runs. The uncapped
samples show a small increase in some new-build frame times, including p95;
these short runs do not establish a statistically precise overhead. Mean
visible primitives increased from about 228,500 to 242,400 (roughly 6%) with
the more detailed new enemies. Medium effects-on mean draw calls were
638–645 versus 651–652, with actors naturally moving during each sample.

The new trim is three opaque MultiMesh batches with no collision or shadows.
The two additional enemy species use single-surface opaque crowd batches,
shared atlas/material resources, and the existing GPU limb animation.
There are no new per-enemy lights, particles or skeletal rigs. Existing
decorative shadow and banner-sharing performance fixes are retained.

These are fixed-camera, short, windowed crowd fixtures, with actor positions
reset before each sample. The new roster's differing speeds are part of the
new game workload. Player controls/camera follow and the wave director are
disabled in the fixture; hero abilities, allied crowds, fullscreen resolution,
long sessions and every possible camera position are not covered. The tests
do not establish that the user's earlier gameplay lag is resolved.

Metal's GPU timing monitor returned zero on this setup, so GPU milliseconds
are unavailable. `Performance.TIME_PROCESS` can include rendering/VSync waits
and is not used as proof of pure CPU time. Raw wall-frame timings and render
counters are retained in `build/neon-shrine/*active300.json` and copied with
the delivered build's verification data.

Reproduce from this checkout using the exact 4.6.3 editor executable:

```sh
Godot --path . --script res://scripts/spirit_fortress_performance.gd -- \
  --label=neon-medium --quality=1 --vsync --crowd --active --300
```

For the older build use the editor's `--main-pack` with v2.46.1's exported PCK
and the absolute path to this same diagnostic script. Use `--quality=2` for
High, or omit `--vsync` for the uncapped capacity comparison. Run serially
with other Godot apps and heavy jobs stopped.
