# Cursed Maze creatures and guardians

Original client pixels for 迷你石像怪 (101204 / `original:2840`), 寶貝炸彈
(101521 / `original:2905`) and all three guardian appearances (101934 / 2980,
101932 / 2978, 101933 / 2979). The first five named guardians use the white/green
appearance; the two kings retain their red/orange and gold appearances. All five
use the existing native SLIME role, cave sprite mesh and pooled presentation.
Companion appearance IDs and the existing companion bank remain compatible.

Prepare with `python3 tools/recover_habaru_encounter.py '../Magic Power' --cursed`.
The indexed-pixel packer preserves source origins, palettes, foot fitting and
all eight directions. Actions are idle, run, attack, hurt, death, walk, guard
and cast; creatures without a cast use idle in that unused slot. Source action
6 provides the guardians' complete two-second sword-raising cast. Guard uses
source action 9; walking uses the animated source walk. The eight-action bank
reserves packed clip 7 for cast in the existing sprite shader. Attack contacts
and audio still come from source action 5. Complete attack motions repeat for
連擊 instead of replacing poses or squeezing several hits into one gesture.

`python3 tests/forest-shrine/test_cursed_maze_source.py` independently decodes
all **4,920 frame instances**, compares original pixels, cropped origins, clocks,
contact markers and audio bytes. The bank has 24 indexed 1024-pixel atlas pages;
original files in the supplied client remain untouched. World proportions and
hurt fits share `scripts/forest/crowd/pet_dimensions.gd`. Guardian hurt regions
reuse their authoritative companion-body fits, preserving their full original
width and height when they join this casting bank.

Prepare/check spells with `python3 tools/recover_cursed_guardian_spells.py [--check]`.
`spells/manifest.json` pins seven AI reference rows, all 42 distinct technique
records, raw condition/target/chance columns, source hashes and 43 original
client spell sheets. Identical existing sheets/audio are referenced directly.
`native/terrain_math/crowd/guardian_rules.h` is generated from those records.

Native combat selects the guardian profile from its floor and appearance.
It reuses Ruby's wards/healing/recovery, existing melee and counter contact,
confirmed life drain, bounded army queries and the ordinary spawn/death owner.
New weighted skill outcomes, multiattack counts, accuracy, status chance and
instant death use shuffle bags. Seven profiles add no alternate simulation,
renderer or per-species target search. All spell sheets are prepared at setup;
casts use the existing bounded effect batches. Ordinary spell pixels fit the
original Kaz idle body (83 pixels) to the game's Kaz height; instance scaling
keeps reused Ruby/Falken meshes and their existing presentation unchanged. Napa restores up to two fallen
attendants in their original stable slots, preventing living duplicates.

Skill roles:

- 納帕: summon, attack and Holy Shield.
- 德爾麥: physical null/absorb/reflect, four level-three super elemental spells,
  attack and guard.
- 瑟貝塔: magic null/absorb/reflect, combo, Double Edge, Sure Strike,
  magic defense, counter and attack.
- 亞爾法: heal, super heal, super recovery, attack and Holy Shield.
- 馬帝亞: all six super status spells, attack and Holy Shield.
- 凱法: magic null, blood attack, Double Edge, combo, Sure Strike, Guard Break,
  counter and guard; Magic Seal becomes eligible after his partner dies.
- 帕布提斯馬: physical null, level-six drain and super elemental spells,
  magic defense; super Death becomes eligible after his partner dies.

The client does not supply original 3D character meshes: these remain faithful
sprites in the existing solid 3D exploration. Skill lists use the pinned CGMSV
reference rather than a recovered BlueCG server. Real-time scheduling, ranges,
balance, support targets and status controls are adaptations. Status controls
are poison damage, sleep (damage wakes), stone hold, impaired drunken steering,
confusion steering and forgotten skill casting. Original status icons
110075–110080 now replace the fallback labels/cube. Native dispatch and
following callbacks verify their source anchors and single owner slot;
icons use the existing pool and clear on expiry, waking, death or recycled
native handles. The client Magic Seal rune (110155, sound 275) repeats at the
fixed chamber seal on a solid 3D floor projection. Death (110156) is proven
through protocol 86, technique 8652, queued state 132 and factory kind 25;
each eligible target gets the original one-shot skull, including failed
attempts with readable MISS feedback. Source frames, origins and clocks are
unchanged. The client has no original 3D mesh for these spell drawings.

Reproduce the archived-byte proof with
`python3 tools/recover_cursed_effect_factories.py --check`, and rebuild/check
the 43 spell sheets with `python3 tools/recover_cursed_guardian_spells.py`
(`--check` verifies without writing). The proof lives in
`assets/references/cursed_maze/effect-factories.json`. Death's general factory
uses the previously documented tier-initializer register repair; status and
Magic Seal factories do not. These fixtures never run a Windows executable.
Napa now uses the recovered default **GMN battle reinforcement entry**,
not the field-pet flash: original 110096 light, seven frames per 400 ms,
looped across 51 source updates while the original creature grows from zero
to full size. `napa-summon.json` preserves all 52 scale samples (including
the initial zero), both native video-mode flags, modern renderer alpha
128/255, one effect allocation and its exact completion/deletion path.
The original creature mesh/material is reused in the existing translucent
effect batches during its reveal; the ordinary native unit takes over when
it completes. Collision/body fits remain unchanged. Real-time entry briefly
holds combat/control until the body is ready; this is an adaptation of the
original turn sequence, not recovered server immunity data.

Reproduce with `python3 tools/recover_cursed_summon.py --check`.
`Play Goemon.command --script res://tests/forest-shrine/cursed_napa_summon_test.gd`
checks repeated two-creature restores, source growth, original light playback,
native ownership, no living duplicates and transition cleanup. The native
renderer also now preserves guardian cast action 780 as the original full
casting clip, matching its existing GDScript path.

The client supplies a default reinforcement animation and alternate walk/fly
variants. Napa's original server packets, including which entry variant they
selected and exactly when reinforcements were requested, are absent.
The original turn scheduler is not reproduced.

Run `Play Goemon.command --script res://tests/forest-shrine/cursed_guardian_skills_test.gd`
for rendered behavior and `cursed_maze_recovery_test.gd` for all sixty floors.
`cursed_original_effects_test.gd` checks and captures all six status icons,
3D Magic Seal, Death outcomes, generation cleanup and repeated batch reuse.
Evidence lives under `build/Other Files/Asset Toolkit/Cursed Maze/`.
