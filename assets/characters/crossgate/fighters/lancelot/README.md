# Lancelot / ランスロット

Playable character 43 uses the shared Cross Gate model and combat owner, with
the original equipped-bow records for every recovered appearance:

| Skin group | Label | Bow record | Archive key |
| --- | --- | --- | --- |
| 106125 | White / Silver | 106126 | ex:457 |
| 106131 | Gold / Purple | 106132 | ex:463 |
| 106137 | Black / Red | 106138 | ex:469 |
| 106143 | Blue / Brown | 106144 | ex:475 |
| 106550 | Silver / Green | 106551 | joy:693 |
| 105206 | Black Lancelot | 105207 | joy-ex:332 |
| 105212 | Emerald / Black | 105213 | joy-ex:338 |
| 105907 | Mint / Blue | 105908 | joy-ex:98 |

These are the eight identified groups in the reviewed archives; unidentified
raw actor IDs are not evidence that every possible future skin is covered.
Color descriptions are local labels except the documented Black Lancelot name.
Day/night palettes are not additional skins. Each appearance retains all 152
native clips, their source frames, offsets, timing and sound markers.

Rebuild from the preserved sibling project, without altering its archives:

```sh
python3 tools/recover_crossgate_lancelot.py '../Magic Power'
```

The recovery checks every exported frame against source pixels and origins.
Attack action 5 lasts .986 seconds: draw cue 114 is on frame 5, release cue
10116 on frame 11. Original arrows #22050–22065 (starting at graphic row 19119)
are packed losslessly into `arrow.png`; `arrow-source.png` preserves the first
direction. These are the sixteen native angles used by client state 18. Original
bow icon #20800 is shared through `assets/ui/crossgate/weapons/bow.png`.
The three byte-identical bow/impact WAVs and hashes are recorded in
`assets/audio/crossgate/lancelot/provenance.json`. Footsteps and landing reuse
the prepared Goemon defaults; character-local Sound Studio overrides still win.

Both mouse buttons fire the bow. Auto-aim shares the kunai's local native
candidate query, visibility and cover checks; each release updates its locked
target's position. Arrows travel straight at 72 m/s for a base 120 m, use swept
world/enemy contacts, and deal the same base 250 damage as kunai. They reuse
the existing character projectile pool. Native ally bodies use ranged reach
inside the same army owner. Skin selection persists as `lancelot_skin`.

Key 1 is 亂射: the original nine-frame physical shine and sound, followed by
twelve rapidly repeated bow actions aimed at random visible, unobstructed
targets. The pinned client protocol is 95, state 18 uses a 33% animation clock,
and its projectile call supplies arrow #22050. The preserved client trace and
asset assertions are recorded in `random-shot.json`. The existing charge sheet
is pixel-identical to resource 110100, so no duplicate effect was authored.
The source's classic rank 10 count is also documented in the
[skill reference](https://guide.bluecg.net/blue-cg/452292).

This real-time adaptation retains Goemon's arrow damage/range/contact contracts
and the shared five-second skill cooldown. It does not reproduce server accuracy,
repeated-target damage reduction, or unverified R11/EX behavior. Skin changes,
dodge and character switches cancel pending arrows; arrows already in flight
keep their existing projectile lifecycle. The native allies use the same skill.

Normal LMB/RMB attacks can overlap 亂射. One pending normal attack joins the
next original bow release (frame 11), with its own attack ticket and ordinary
bow recovery interval; repeated clicks cannot bypass that cadence. All twelve
skill arrows retain their independent tuning and random targeting. Existing
auto-attack can add normal arrows too. A click after the last skill release
starts an ordinary bow windup when the volley finishes. This reuses the current
bow motion rather than adding another pose/controller. The shared arrow pool
prepares overlap headroom at setup (four extra slots for the default volley).
The existing interruption paths clear pending normal arrows with the volley.

Lancelot also has native **2 乾坤**, **5 亂射影分身**, and **6 陽炎**.
乾坤 charges and fires one original arrow at the bow's draw/release markers.
Its recovered burst now detonates at the actual enemy or wall contact, dealing
5,000 base damage once per enemy within an 8 m radius. Solid cover blocks the
blast; a miss expires silently without detonating. The five-second cooldown,
arrow range/speed, skill tuning and original animation remain. 陽炎 is
the existing guaranteed-dodge toggle using Lancelot's own prepared afterimages.

Key 5 leaves five copies at 65% opacity (30% less transparency than before) on clear ground around the caster for
30 seconds, using the existing 22-second mirror cooldown. They remain in place
and repeat only 亂射, including its twelve-arrow volleys and normal cooldown.
Each arrow uses the caster's current damage (including level stats, attack
allocation, food and run bonuses); each volley snapshots his chain, critical
chance and 亂射 skill tuning. Native army targeting, life/death, local cover
checks, prepared sprites and projectile leases remain the owners. Ordinary
shared Mirror Image keeps its existing following/skill behavior. Recasting
replaces the old group; expiry, player death or character switching retires
copies and their remaining projectiles. Saved skill overrides remain intact;
choose Original in Q → Loadout to restore a native slot.

`tests/forest-shrine/lancelot_arrow_explosion_test.gd` checks actual charged-arrow
flight/contact, native area damage, cover/wall impact, misses, cancellation and
normal-arrow lease reuse. Its rendered evidence is under
`build/Other Files/Lancelot Arrow Explosion/`.

`tests/forest-shrine/lancelot_shadows_test.gd` checks these numbered keys, damage,
five simultaneous repeated volleys, stationary placement, resource reuse and
cleanup. Run it through Play Goemon for captures under
`build/Other Files/Lancelot Shadows/`.

Each selected atlas is approximately 12.91 MiB of RGBA texels, excluding engine
overhead. Load at selection/setup, never from attack or animation callbacks.
All eight cached appearances total approximately 103.2 MiB after browsing them.

Regression: `tests/forest-shrine/crossgate_lancelot_test.gd`. Run through
`/Users/eric/Desktop/Play Goemon.command --script` for the rendered check.
Evidence goes to `build/Other Files/Asset Toolkit/Lancelot/`.
