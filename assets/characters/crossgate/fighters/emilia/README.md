# Emilia / Ayame

Playable ID **42**, save key `emilia`. The shared Cross Gate gallery offers
twenty verified appearances: the eighteen original Ayame/Emilia looks including
Emilia + Puck, plus Special Pink Ayame (106706, original staff) and Special
Red / Black Ayame (120389, original sword). The Special skins retain their fixed
source weapons and source contact clocks. Puck is the default. Appearance selection is saved in
`emilia_skin`; spell assignments, character balance and sound overrides remain
independent of Uru and the other fighters.

Emilia uses Uru's existing staff combat controller and six empty, editable
skill slots. Spirit Shockwave, Fire, Ice, Wind, Meteor and Regrowth remain
available through the shared equipment/skill system. Basic attacks
keep Uru's two-second clock, five swing/contact markers, five 100-base-damage
contacts, reach and cover checks. Animation preparation adapts the staff
drawings to those markers. The native army owns enemy and ally life, targeting
and damage. Existing pools provide projectiles, effects, damage numbers and
audio voices; there is no additional simulation or character renderer.

Each of the eighteen original appearances retains all nineteen original actions and eight directions
(152 clips), including gestures not currently bound to player controls. Source
frame records, frame maps and original durations are in each `motions.json`.
Movement, gestures and cast drawings keep their authored sequence. Attack
drawings repeat on Uru's five contacts without discarding the source drawings.
The two Special skins retain eight gameplay actions in all eight directions;
their archived social gestures are not bundled.

Most appearances use their original equipped-staff records. Emilia #120388,
Emilia + Puck #120387 and the white costume #111669 only have unarmed artwork.
Their prepared staff versions fit the compatible Ayame staff/grip differences
from `puk3:531` / `puk3:533` offline. Palette correspondence keeps the corrected
arms in the receiving costume. Emilia's ice/sparkle artwork and Puck's long
standing animation remain in the prepared sprites. These are local authored
staff adaptations, not claimed original BlueCG staff appearances. Original
archives remain unchanged; the preparation code stays editable.

Blue and silver hair use `ch1:794` and `ch1:800`: later Joy EX records reuse
their IDs for different characters. Do not substitute those later aliases.
The selected skin loads at setup/selection. Normal animation only changes the
existing sprite's atlas region. Native allies share the same immutable pages.
Puck and the held staff are baked into those pages, requiring no extra nodes.
Footsteps and landing use Goemon's prepared defaults. Swing/contact and spell
audio reuse Uru's prepared samples through Emilia's independent sound profile.

Rebuild from the read-only compiler project:

```sh
python3 tools/recover_crossgate_emilia.py '../Magic Power'
python3 tools/recover_crossgate_emilia.py '../Magic Power' --check
```

The preparer verifies source IDs, complete action/facing coverage, preservation
of attack drawings and exact Uru cue clocks, then reopens every packed frame
and compares its pixels. Do not edit generated atlases directly. Recovery,
memory measurements, tests and rendered evidence live in
`build/Other Files/Asset Toolkit/Emilia/`.

```sh
'/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/crossgate_emilia_test.gd
```

In Play Goemon choose Emilia in Character Select. Use Skin to switch looks;
both mouse buttons run Uru's staff combo, 1–5 cast the same spells, and 6 casts
Regrowth. Jump and evade use the shared Cross Gate presentation and controls.
The export does not add bindings for the archived social gestures.

## Selection scale and green-edge correction — 2026-11-16

The shared equipment skin gallery now reuses the equipment portrait's body-height
canvas and foot alignment. Tight Special portraits no longer enlarge relative to
the older 128×160 portraits. Skin names remain visible without hover highlighting
or tooltips; double-click/Enter and equipment save/discard keep their owners.

Pink Ayame's transparent source pixels contain bright green RGB. Its atlas and
portrait imports now enable Godot's `process/fix_alpha_border`, preventing linear
filtering from pulling green into her silhouette. Original PNGs, atlas rectangles,
alpha coverage, palette, source frames and combat clocks remain unchanged. New
Special-skin imports use the same engine option; existing corrected imports stay
intact when recovering. Brown Hair / White already had this correction enabled.

The earlier `Emilia Puck Edges/` comparison checked two standing facings and
confirmed authored contours plus corrected imports. It did not validate the
attack silhouette. The subsequent moving-attack correction below supersedes
the conclusion that every reported dark edge was simply the original outline.

`tests/forest-shrine/emilia_skin_review_test.gd` exercises all twenty skins and
95 supplied weapon combinations, 60,144 frame samples, exact contacts, all eight
facings, clip endings/loops, native copies and warmed resource reuse. Desktop
captures and fresh validation receipts live in
`build/Other Files/Asset Toolkit/Emilia Skin Review/`. The source `--check` also
rebuilds the three fitted staff appearances in memory and compares every frame,
origin, ordering, source record and prepared clock without rewriting assets.

Fresh verification: the desktop replay passed 276 checks, including every
appearance, all spells, native contacts and five simultaneous allies. Repeated
use added no resources, nodes or pool misses. The existing Uru regression
passed 75 headless checks. See the performance guide for the measured scope
and selected-skin memory cost; these checks do not establish full-game FPS.

## Moving staff silhouette — 2026-11-16

The three fitted appearances (120387, 120388, 111669) previously kept pieces of
the unarmed head silhouette after the staff pose moved. The donor/receiving head
boundaries differ, so erasing only donor differences in the old neck/arm window
left a detached dark contour. Some equal donor pixels also left holes where the
receiving silhouette had been empty. Valid atlas rectangles and clocks could
not catch those visual errors.

The shared offline fitter now clears vacated upper-body pixels using the
receiving appearance's neutral body palette and fills missing donor coverage.
For Puck, comparison with the exact corresponding cat-free source frame protects
every original companion pixel before fitting. Only attack preparations change;
portraits, all other actions, original archives, weapons, five contacts and
two-second clocks remain intact. Native copies share the rebuilt pages, with
no new runtime image work, renderer, resource loading or animation owner.

After recovery, rebuild the existing audio contract from source because atlas
packing changes the hashed attack manifests:

```sh
python3 tools/prepare_crossgate_player_audio.py '../Magic Power'
python3 tools/prepare_crossgate_player_audio.py '../Magic Power' --check
python3 -m unittest discover -s tests/forest-shrine -p 'test_emilia_staff_outline.py'
'/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/emilia_attack_motion_test.gd
```

The pixel regression reproduces ten vacated-outline failures on the old pages,
checks all supplied staff silhouette coverage, and preserves all 40,573 original
Puck attack pixels across nine drawings/eight directions. The dedicated desktop
fixture replays all 38 prepared attack frames in every facing for all three
fitted skins. Review its actual arena captures separately from assertion counts.
Source comparisons, before/after art and live filmstrips/GIFs are under
`build/Other Files/Asset Toolkit/Emilia Attack Shadow/`.
