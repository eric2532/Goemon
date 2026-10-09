# Rogue combat, weapon poses, and construction polish

Approved in chat on 9 October 2026. This extends the latest Fire Siege MVP at `ed8c003` plus the completed, uncommitted movement/camera update. The older Desktop checkout is not the target.

## Scope and acceptance

- Natural weapon poses for all ten Rogue fighters: two-hand heavy right-side claymore carry, raised pirate sword, neutral knight and samurai, alert ranger, reverse-grip ninja and Explorer. Samurai's bow stays on his back except when shooting.
- Native Rogue secondary input accepts both RMB and 3, including hold/release behavior. Goemon's existing numbered attacks remain intact.
- Ninja dash cuts the entire travel path; larger, wider-reaching shuriken remain accessible. Samurai gains a massive red slash while retaining an accessible bow attack. Explorer alternates evasive underhand cuts and gains a dash cross slash.
- Dragoon has a wider, longer thrust and a larger blue landing shockwave with exactly three damage pulses.
- Mage fires tap/release fireballs, charging through one-, two-, and three-second sizes. Frost nova freezes for three seconds and deals no damage.
- Master Thief swings faster/wider, scales with growth, and holds a stationary red pipe guard for up to three seconds.
- Knight has longer sword reach and a two-second guard that responds to enemy hits with a huge navy shield bash.
- Four independently buildable mines, three near the starting location; construction can begin beside any accessible side of a structure. No build-pad circles. Show proximity prompts; hide untouched construction bars.

## Ownership

1. Pose work: `assets/rogue/scripts/actor.gd`, focused pose verification and reference observations.
2. Combat work: `class_actions.gd`, `effects.gd`, `rogue_roster_combat.gd`, `classes.json`, focused integration tests.
3. Construction/economy work: Fire Siege director/state/structure/HUD, world mine sites, affected MVP tests.
4. Integration: test routing, existing controls regression expectations, controls text, verification notes and rebuilt local macOS app.

## Verification

- Preserve the pre-existing movement/camera diff; baseline snapshot is in `/tmp/rogue-upgrade-baseline/`.
- Add meaningful runtime tests that fail before new combat and construction behavior is implemented.
- Run `python3 tools/verify_fire_siege.py` for state, structures, integration, campaign, controls, and legacy tower defense.
- Run the focused combat, pose, movement/camera, and turn tests. Retain collision/cover, pause/reset, and class-switch checks.
- Inspect rendered poses, attacks, charge/guard effects, and construction prompts in the actual Godot renderer.
- Export the updated Mac app, test the exported package, and verify its signature before replacing the existing launch path. Preserve the preceding app.

## Progress

- [x] Confirm latest authoritative worktree and preserve previous changes.
- [x] Approve requirements and divide independent implementation work.
- [x] Poses and visual verification.
- [x] Combat and focused runtime verification.
- [x] Mines and construction verification.
- [x] Combined regressions and independent review.
- [x] Local macOS export and delivery.

Results and delivery paths: [Rogue upgrade verification](rogue-upgrade-verification.md).
