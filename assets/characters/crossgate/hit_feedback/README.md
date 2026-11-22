# Blue Cross Gate hit feedback

崩擊 uses the prepared Magic Power `h_guard_break` assets. The base-rank
charge uses the existing `110103` sheet in `../skill_tiers/` and sound 251
(`cgefc00.wav`, SHA-256
`615a771ca3d4ac2fccf71c82a078966667d902e7ea0d136c4213631caea9ff78`).
`guard-break.png` preserves the 110139 contact sheet, eight frames at
68 ms each. Its SHA-256 is
`fe25595db3da28ce512e0bf5143cee91b9a8fcecc164a34717a25a8fda43744a`.
The source manifest is in the sibling Magic Power project's
`godot/assets/humanoid-spells/`. The contact sheet has no embedded sound
marker. The equipped weapon supplies its normal impact sound.
`guard-break-icon.png` uses the fourth frame of 110139, cropped and fitted to
64×64 with transparent padding for Equipment and the numbered hotbar.

`joint-attack.png` preserves the original HitCombo display: graphic serials
23140–23148 are counts 2–10; 23158–23165 are H, i, t, C, o, m, b and Great!.
The second o reuses 23162. All 17 decoded RGBA images and their origins are
unchanged inside 96×64 atlas cells. `joint-attack.json` records source rows,
pixel hashes and the preserved client memory hash.

Shin's corner counter uses the same atlas for the word and counts 2–10.
`hitcombo-01.png` separates 1 and 0 from the original 10 for the first hit
and counts above 10. Compositing the two digits back at their original
positions reproduces the source sprite pixel for pixel.

The client's layout at `0x41D800..0x41DAA8` supplies count selection, x offsets
`0,34,54,66,88,108,131,152,171`, entry order `0,8,7,6,5,4,3,2,1` at four
updates per glyph, and Great! at `(88,-32)` for ten participants. Goemon uses
the existing bounded effect batches, source glyphs and spacing, a decelerating
sideways entry and four-second lifetime. World-space size/placement, entry
direction and fade are adaptations; full original battle choreography/timing
has not been recovered or claimed. Existing normal player/pet motions remain
under their shared combat controllers.

Normal Cross Gate player melee plus native companion/bear melee on one enemy
within a fixed 0.35-second window forms 合擊. Distinct participants count once,
up to ten, with the player required. After normal hit/defense calculation,
the group total is `sum(normal damage) * (1 + 0.1 * participants)`; later hits
settle only the unpaid difference as the group grows. For example, 100 + 50
becomes 180 for two participants. Pet-only contacts, skills, counters and
projectiles do not earn this bonus. Existing attack-chain bonuses still apply
before this separate joint bonus. An expired group starts fresh.

This is a classic-style rule, not a verified reconstruction of BlueCG's live
server. The [CGMSV engine author's changelog](https://bbs.cgmsv.com/thread-1885-1-1.html)
documents `comborate` default 0.1; original server rounding and special-case
defense behavior remain unverified. Goemon retains its existing defense and
floating-point HP rules. No server executable or client bytes are executed.

Rebuild from the read-only sibling archive with
`python3 tools/recover_crossgate_joint_attack.py '../Magic Power'`, then refresh
Godot imports. `tests/asset-toolkit/test_crossgate_joint_attack.py` compares
all source pixels/origins. `native/terrain_math/crowd/joint_attack_test.cpp`
checks the formula and eligibility; `tests/forest-shrine/joint_attack_test.gd`
checks real player/pet contacts and rendered titles across the Cross Gate roster.
Evidence is under `build/Other Files/Asset Toolkit/Joint Attack/`.

`exclamation.png` preserves original graphic row 19060 (graphic serial 22344),
including its 36×36 RGBA pixels. Its source origin is (-16, -116). The decoded
RGBA SHA-256 is `0900498e62193d87d205dbf68fe905075ff38cacc4a33af54d1b07dbb01e2e62`.
The shared Space dodge displays this original red ! above the fighter as the
native contact window opens. The preserved NewClient sequence at
`0x42158a..0x4215c9` queues sound ID 252 (action `0x4e`, handler `0x40a9d5`)
then graphic 22344 (action `0x43`, handler `0x409ffd`). The sequence at
`0x42f8e5..0x42f921` does the same. The audio table maps 252 to
`bin/se/cgefc01.wav`. The unchanged WAV under `assets/audio/crossgate/` has
SHA-256 `6eba17e6db23d6efade39e5e208ad1d4a038491f53a7b4b58e25558232cc7fe1`.
The warning plays it once through the pooled player audio and exposes its
level and mute in Sound Studio. The recovery command below checks the
exclamation mark's pixel hash.

The bitmap font packs original graphic rows 19026–19035, one per digit.
Each glyph keeps its source RGBA pixels and advance. Digit 1 is eight
pixels narrower than the others. The source client renders the same
orange digits for ordinary and critical damage. Goemon uses its existing
floating motion and increases the size for heavy and critical hits.

Normal hit feedback cycles through original gold sparks 110001–110003,
reusing the copies already under `../elements/wind-hit-*.png`. Each
seven-frame sheet holds two 60 Hz ticks per frame. The fighter's effective
model size is captured on the attack ticket and scales both impact layers.

The original HP recovery branch at `0x418b6a` passes kind 5 to the
battle number renderer at `0x41c950`. Its table at `0x53e4d0` selects
V3 graphic serials 243750–243759 and plus sign 243850. Their opaque
pixels are RGB `#00ff00`. Uru uses those original glyphs in a separate
bitmap font.

The critical overlay is animation 110008 from the Blue Cross Gate
NewClient archive, original animation row 3000, action and direction 0.
The sheet is the preserved four-frame export (graphics 16702–16705).
The client quantizes its 300 ms duration to four 60 Hz ticks per frame
and blends the overlay at 128/255 opacity. At the user's request (2026-11-13),
Goemon emphasizes criticals at 85% opacity and 2.8 times the attacker's impact
scale, twice the previous width and height. This applies to both layered and
quiet criticals; ordinary gold sparks and combo effects keep their existing
appearance. Reduced Flashes still dims the critical by 65%. Original pixels,
four-frame timing and effect budgets are preserved. There are no sound markers
in the overlay.

The critical sheet is 249 pixels high with its native origin at row 129,
4.5 pixels below the quad centre. Its camera-plane vertical offset therefore
uses `4.5 * .02 * effect_scale` so the ray origin stays at the impact as model
and critical sizes change. The depth offset, gold sparks and combo origin keep
their existing placement.

All damaging skills retain this overlay when their contact rolls a critical,
including quiet contacts such as assassination. Quiet contacts still omit the
ordinary spark and damage number. World-space contact visibility must go through
`forest_point_visible`, which converts exploration's scaled coordinates before
looking up map cells. Keep critical chance and damage on the shared attack ticket.

`tests/forest-shrine/critical_skill_feedback_test.gd` checks real Lancelot arrows,
亂射 and equipped magic at 0%/100%, shared damaging-skill tickets, scaled visibility
and quiet contacts. Original frame previews and current desktop evidence are in
`build/Other Files/Asset Toolkit/Cross Gate Hit Source Review/`.

Repack from the read-only sibling Magic Power project and refresh imports.

```sh
python3 tools/recover_crossgate_hit_feedback.py '../Magic Power'
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
```


Plain 護衛 (`shin/bodyguard`, 2026-11-22) reuses this preserved exclamation for
its equipment icon and activation mark, plus the existing original 護衛 sound
`assets/audio/crossgate/cgefc01.wav`. Character dash uses the selected model's
run animation; native pets use their original body with a short jump arc. No
source pixels, attack drawings or audio PCM were changed for this skill. The
pooled army effect is `bodyguard-mark`; gameplay rules are documented in
`docs/crossgate-skill-rules.md`.
