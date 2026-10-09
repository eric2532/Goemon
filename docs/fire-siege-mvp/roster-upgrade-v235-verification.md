# Fire Siege MVP v2.35.0 — roster upgrade verification

Implemented in the existing `codex/fire-siege-mvp` worktree, preserving the
previous movement/camera, construction and combat changes. The older Desktop
checkout and remote releases were not changed.

## Delivered changes

All twelve heroes have three times their former basic-attack reach or projectile
travel distance. Growth applies once; heavy and utility range remain unchanged.
Goemon's pipe/coin and Edo's volley/empowered primary are included.

Magic Swordsman's second-jump basic attack dives forward/down into one violet
energy impact (260 base damage, 8-metre radius). Pirate fires a visible piercing
round with ten times the former shot-streak radius. All four Mage fireball tiers
pierce successive enemies in a straight line. Pirate and Mage retain terrain
blocking, including the enlarged Pirate round's full sphere at low cover.
Dragoon's first and second jump launch speed scales by sqrt(2), producing twice
the clear-flight height with unchanged gravity.

Ninja and Explorer gain 20 energy per completed light attack. Five earn one free
manual RMB/3 heavy, which bypasses and preserves the existing normal cooldown.
The HUD shows progress and a ready state. Cancelled/rejected attacks do not
charge it; a press before full energy cannot spend a subsequently earned credit.
Pause retains earned energy, while death, hero changes and new runs clear it.

The remaining eight Rogue heroes adopt the accepted coordinated skull, painted
face, hair and headwear direction. Knight retains his closed helmet. Both
accepted pilots, Goemon's master and the face atlas remain exact. Sources remain
editable and reproducible from tracked originals.

## Source evidence

All final source logs contain zero assertion failures and no runtime errors:

| Suite | Checks |
| --- | ---: |
| State / structures / MVP integration / campaign | 65 / 71 / 72 / 117 |
| Three-gate defense / movement / poses | 59 / 103 / 27 |
| Motion / weapon weight | 95 / 104 |
| Existing Rogue combat / controls | 76 / 136 |
| New Rogue behaviors and lifecycle edges | 99 |
| Native Goemon and Edo ranges | 12 |
| Rendered full roster and ability tour | 193 |
| Final Master Thief art correction in game | 16 |

The rendered full tour produced 65 captures in the actual MVP, using live hero
selection and input. It covers front/side/three-quarter faces, complete bodies,
basic contacts, dive/impact, visible bullets, energy HUD states, measured jump
apexes and piercing fireballs. Five additional captures verify the final Master
Thief correction. Source evidence totals 1,245 checks; logs and manifests are in
`build/rogue-roster-upgrade/`.

Independent runtime review found and resolved the enlarged Pirate bullet's
low-wall collision mismatch. Lifecycle tests found and resolved premature energy
buffer consumption and jump buffering during the dive. The old motion fixture's
fixed landing time was replaced with a bounded wait for actual landing: a probe
confirmed the higher Dragoon was still airborne but upright at the old deadline.
The updated 95-check motion suite passes.

Independent art review inspected all ten in-engine faces/bodies and shared
Blender comparisons. Its one required correction aligned Master Thief's painted
nose with the physical nose tip, keeping his moustache below it. This changed
only skull UVs; all 128 object geometries/transforms remained exact. Final front,
side and three-quarter renders passed review. Ninja's small visible ear lobe was
retained after review at gameplay scale; no follow-up geometry change was made.

Art invariants: 70 native pivots and 1,018 body/weapon components exact; 72 new or
sculpted meshes pass closure/winding/degenerate checks; all exported face UV0
layouts validate. Accepted pilot and master/atlas hashes match the baseline.
Eight portraits and 160 Blender comparison renders were produced.

Python compilation and `git diff --check` pass. Godot import has one pre-existing
editor warning for the nested economy asset validation project, which is ignored.
Edo's empowered beam retains its pre-existing behavior through cover; this range
change does not redesign that ability's collision rules.

## Reproduction

```sh
godot --headless --editor --path . --import
godot --headless --path . -- --rogue-roster-v235-test
godot --headless --path . -- --native-primary-range-test
godot --fixed-fps 60 --max-fps 120 --path . -- --rogue-roster-upgrade-tour
godot --fixed-fps 60 --max-fps 120 --path . -- --rogue-roster-upgrade-tour --hero=master-thief
```

Art generation and validation commands are recorded in
`docs/art-direction/rogue-roster-upgrade.md`. Runtime and art reviews are saved as
`build/rogue-roster-upgrade/runtime-review.md` and `art-review.md`.

## Packaged verification and delivery

The final exported macOS app passed 193 rendered tour checks and 99 combat
regression checks: **292 checks, zero failures**, with no runtime errors or
warnings in either packaged run. The 65 packaged captures include the corrected
Master Thief face. Source and package verification total **1,537 checks**.

Version **2.35.0** is installed at `build/final-macos/Goemon Fire Siege.app`.
Version 2.34.1 is preserved at `build/Goemon Fire Siege before Roster Upgrade.app`.
The archive is `build/Goemon Fire Siege Roster Upgrade.zip`. The installed app
passed strict code-signature verification; both the executable and resource PCK
match the hashes of the tested staging app. Hashes, versions and paths are in
`build/rogue-roster-upgrade/build-info.json`.

The final in-game overview is `build/rogue-roster-upgrade/roster-in-game.png`.
Packaged captures and their manifest are under the app's user-data directory at
`build/rogue-roster-upgrade/`. No remote release was published.
