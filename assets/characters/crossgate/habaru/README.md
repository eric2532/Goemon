# Habaru recovered sprites

The shared army uses `motions.json`, `frames.bin`, the indexed atlas pages and
`palette.png`. The 穴熊 summon uses appearance 4, retaining actor #101010's
original frames at the Venoa bear fit. The larger Habaru encounter and Venoa boss
appearances share those recovered frames with their existing independent fits.

`bear-icon.png` preserves the original bear portrait: a 64×64 transparent canvas containing
the unchanged face pixels from actor #101010 (`original:2807`), idle action 0,
direction 5, frame 0. Its source rectangle is `(12, 2, 56, 57)` in the original
68×90 frame. No recoloring or generated character artwork is used.

`tools/recover_habaru_encounter.py` is the authoritative recovery script. Its
`recover_bear_icon(cg)` helper refreshes the face and skill icons without rebuilding the
encounter atlases. From the project root:

```python
import sys
sys.path[:0] = ["tools", "/Users/eric/Desktop/Projects_Codex/Magic Power/tools"]
import cg_assets as cg
from recover_habaru_encounter import recover_bear_icon
recover_bear_icon(cg)
```

Refresh Godot imports after recovery. The summon skill uses the shared
`assets/ui/crossgate/skills/summon-bears.png`: the unchanged full-body sprite
from the same source frame with two smaller half-opacity copies behind it.

## Defense and counter opening

The Habaru bank appends original action 9 (Defend) as its seventh clip, after
the six existing clips. All eight directions retain the source pixels, crop,
foot placement and one-second source duration. The shared sprite renderer's
guard wire clip 6 reads this slot directly; the ten-action slime bank keeps
its existing slot-9 mapping. Other encounter recovery modes retain six clips.

Regenerate with `python3 tools/recover_habaru_encounter.py "../Magic Power"`.
`tests/forest-shrine/test_habaru_defense.py` checks defense against preserved
actor `original:2759` and the one-time pre-change snapshot checks every existing
clip's decoded pixels, offsets, scale, duration and frame count. Evidence is in
`build/Other Files/Asset Toolkit/Habaru Counter/`. Original archives stay intact.
