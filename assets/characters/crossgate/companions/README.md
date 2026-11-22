# Cross Gate companion families

Non-attack audio uses the original sound markers in each variant's prepared
`clips`: idle 0, walking 1, running 3 (or its authored `run_action`), hurt 8
and death 10. `PetCatalog.make_mesh` prepares that immutable lookup with the
existing sound bank. `army_presentation.gd` follows the native snapshot in its
existing unit pass and reuses its voices/effect queue; do not add a species
controller, runtime asset loading or damage behavior for an audio marker.
Movement stops with its owner and source loops reuse the same voice. Hurt/death
cues retain source timing; unavailable samples and source-silent states stay
silent. Run `tests/forest-shrine/pet_audio_test.gd` through Play Goemon for all
616 identities/eight attack facings, pooled original clip playback, real moving
bee/mixer capture, native hurt/death, cleanup and repeated five-pet reuse.

The catalog preserves 616 saved identities. The original 82 are followed by 534 reviewed additions across twenty-two categories. The picker shows 604 distinct choices after hiding twelve duplicate 猶大 archive aliases. Saves use source keys because the archives reuse numeric sprite IDs.

| Family | Added appearances |
| --- | ---: |
| Catfolk | 14 |
| Mice | 39 |
| Bears | 13 |
| Panthers | 13 |
| Griffins | 25 |
| Large bats | 12 |
| Skeleton warriors | 26 |
| Ghosts | 14 |
| Zombies | 17 |
| Scorpions | 12 |
| Tree spirits | 28 |
| Cacti | 14 |
| Shadows | 16 |
| Elemental spirits | 10 |
| Living blades | 18 |
| Golems | 5 |
| Wyverns | 16 |
| Lizard warriors | 13 |
| Giants | 11 |
| bosses · 猶大 family | 36 |
| 灰熊厲害 · A/S rewards | 126 |
| 贊助 · sponsor rewards | 56 |

## 贊助 rewards — 2026-11-14

Later character-size direction supersedes the enlarged size for human-looking
character skins, including 歌姬雪蕾潔. The sixteen reviewed keys and standing
body pixel heights live in `scripts/forest/crowd/pet_dimensions.gd` under
`CHARACTER_BODY_PIXELS`. They render at Kaz's base body height in both Arena and
Explore; weapons, wings, head ornaments, shadows and effects do not determine
body height. Animals and monsters retain their authored sizes below.
The existing setup cache derives render scales and native contact bodies together;
source profiles, textures, frame tables, saved keys and combat timing stay intact.
When adding a human-looking skin, review its standing body and extend this same
table rather than changing its source pixels or adding another runtime owner.
Run `tests/forest-shrine/kaz_character_size_test.gd` through Play Goemon for
Cross Gate skin, exact contact, five-pet skill and rendered lineup checks.

Size follow-up: 33 large sponsor appearances now use twice their preceding
linear size: 熱帶龍、墨丸、雷公、獨角黑馬、蛇姬小青、蛇姬白素貞、月見紗、
星幻冥神、煉焰飛龍、大天使里雍、超夢、普托坎克、海洋牛頭怪、紫耀牛頭怪、
戰鬥暴龍獸、毒角仙、烏金鬼鍬、珊瑚鯨、紫金神龍、白金神龍、卡比獸、閃電鳥、
黑夜迅狼、白晝迅狼、急凍鳥、滿開神木櫻花依代、火山鯨、烈焰黑虎、黃金龍、
黑龍、聖龍、多拉姆糖、歌姬雪蕾潔. A further 50% increase puts 歌姬雪蕾潔
at 3× her original size; the other 32 enlarged pets remain at 2×.
The other 23 retain their sizes. Authored `visual_scale`
and all six fitted `body` coordinates scale together, including hover offsets.
Keep the review list, sponsor motion metadata and composed catalog synchronized.
Original frame tables, textures, saved identities, damage and contact timing
remain unchanged. Size evidence is under
`build/Other Files/Asset Toolkit/Sponsor Pet Sizes/`.

The `sponsor` family appends all 56 distinct confirmed sponsor appearances that
were missing from the preceding 507-entry catalog. The review list records each
2018–2026 reward citation, exact source key and pixel-match proof. Explicit
B-tier 卡拉龜 is excluded. Older unranked rewards remain included; the letter
in `汪汪召喚書B` is an item variant, not a published B rarity. Already available
appearances keep their original slots and families. The two rabbit and golden
mouse remodellings reuse their original appearance, not duplicate choices.

All six gameplay states, eight facings and every required frame were decoded
before enabling the family. 雷公 (`joy-ex:963`) death action 10, direction 1,
frame 9 references graphic 436171. Its index incorrectly declares 100×153;
the intact encrypted image header declares 96×149, with a valid 8,851-byte
payload and full palette. The authored `graphic_dimensions` correction uses
the existing decoder's index-row and SHA-256 guards. Its pixel bytes match the
next source image; original placement, frame count and timing are retained.
Original client/index files remain unchanged.

獨角黑馬 has original audio-only marker 332, while 珊瑚鯨 and 火山鯨 use 321.
Neither ID has a mapping in the recovered client sound table. Their explicit
`missing_audio` declarations preserve those source markers as silent audio-only
cues; real impact flags still determine damage. No guessed sound or extra hit
is supplied. Other original WAVs retain their PCM hashes. Body fits and ground
shifts are prepared data; the family adds no runtime loader, renderer or
targeting owner. Pets use Goemon's existing stats and assignable skills; the
original turn-based innate skills and balance are not installed.

Research, full-frame audits, the original dimension record, staged resources,
preservation checks and rendered/gameplay evidence live under
`build/Other Files/Asset Toolkit/Sponsor Pets/`. Use the source Play Goemon
launcher and Shift+P → `贊助`; no app export is needed.

## 灰熊厲害 A rewards — 2026-11-20

The `bear_challenge_a` bank appends 29 A-medal reward appearances found in
the 2014–2026 tables. These include both 2020 bone dragons, 比比紅鳥 and
比比藍鳥, and the 2024 超級電龍 evolution. The 2026 high- and low-profile
dragon lizards match two existing Dragon lizards choices. Other matched
appearances such as 白之意志 and 帕布提斯馬 use their existing family slots.

The additions use native frame timing and directional cues. 蒼羽神鷹 adds
sound 152 from the supplied client WAV. 尾立's eight authored hurt clips are
empty. Its hit reaction displays the existing idle art with the shared flash.
Its attack and fall clips are complete. Existing saved slots end at 586.
The remaining unconfirmed A appearances include 喵喵, 大蔥鴨 and 超級大比鳥.
The damaged 布路亞 graphic has no intact duplicate in the thirteen original
graphic containers checked in this pass.

The 2024 10 A reward adds 蘿蔔兔（皇冠） at slot 616 (`ex:1102`). Its
original frame matches the published reference exactly. The two rabbit
appearances share a body fit and scale and have separate animated records.
[2024 rewards](https://guide.bluecg.net/blue-cg/864833) · [Rabbit reference](https://guide.bluecg.net/blue-cg/452464)

## 灰熊厲害 S rewards — 2026-11-19

The S-medal review covers the published 2014–2026 BlueCG exchanges and their
rare color rewards. Twenty-four missing appearances use the appended
`bear_challenge_s` bank and the existing 灰熊厲害 picker category. Its source
keys occupy slots 563–586. The 2016 堤風 and 2019 堤風R share the native `joy:3`
appearance. 大可愛優奈 was already selectable in Catfolk and now has her
verified label. Other already-listed appearances keep their own families.

The red-gloved cactus is 拳擊火焰舞者, the 2026 40 S reward at slot 564
(`ex:1705`). The four other glove colors in the original archive have no
verified A/S reward listing. [Pet reference](https://guide.bluecg.net/blue-cg/1002921)

Each new entry records its reward citation, the compared reference frame and
the native frame hash. Some GIFs have palette quantization. Gameplay takes
the pixels, animation timing, hit markers and available audio directly from
the supplied client archives. The prepared body fits use the normal companion
scales and keep the matching colors equally sized. 布路亞 remains pending an
intact death frame for `ex:971`. Both supplied client archives have the same
damaged graphic 392107.

## 灰熊厲害 A/S rewards — 2026-11-14

The user requested A- and S-medal rewards only. The appended `bear_challenge`
family contains 73 newly available source appearances from the 2019–2026 lists,
including A/S evolution exchanges. B rewards and D/C exchanges are excluded.
Already selectable appearances keep their existing slots and families. The four
elemental names 吉瓦登、雷克爾、萊卡翁、伊利諾 share one source appearance and one
picker choice, `ex:938`. Original turn-based stats and innate skills are not
installed; these pets use the shared Goemon combat and assignable skills.

Each review-list entry records its A/S reward provenance and exact pixel-match
proof. The earlier research gallery accidentally grouped two multi-row tables
with evolution descriptions: `v3:784` is 花瓶妖精 and `puk2:38` is 化石龍骨R,
not 超級電龍. The original evidence establishes the identities used here.
Unknown image identities remain unverified, rather than receiving guessed names.

All six runtime states and eight directions are prepared from the original
clips. Humanoid extra actions are archived too. 中土巨蟒 and 摩羯魚怪 have explicit
source flag `10000` at attack frame six: it is a silent impact. The shared packer
and native cue validation preserve this contact without inventing a sound or a
new attack owner. Additional audible cues must still be explicitly tagged and
validated; unrelated untagged cues remain rejected.

草莓環尾兔 and 衝浪神龍 expose frame-zero impacts. The shared native advance
path now delivers those contacts after the start event, without advancing the
pose or duplicating audio. Focused regressions cover event ordering and damage
at 20, 30 and 60 Hz; later-frame contacts keep their existing dispatch.

Rendered review found that some native pivots put visible feet below the ground.
Each new appearance records a fixed `ground_shift` in source pixels and an
authored visual/body fit. Preparation translates the original Y placements by
that constant; pixels, X anchors, relative motion, durations and contact frames
stay original. The original 434 entries, their sizes and saved identities are
unchanged. There is no combat-time retargeting or asset loading.

`布路亞` (`ex:971`) remains withheld: death action 10, direction 1, frame 0
references damaged graphic 392107; the current NewClient copy also cannot decode
it. No guessed death frame is published. Research, source audits, prepared-origin
measurements and rendered/gameplay evidence are in
`build/Other Files/Asset Toolkit/Bear Challenge Pets/`.

The `bosses` category appends all 24 approved main 猶大-family choices and twelve
historical source entries. It preserves exact keys even when
numeric IDs collide with other pets or Kaz skins: `puk3:916` is the remodeled
gold armored body, while Kaz's unrelated `puk3:834` is unchanged. Thirty-six
choices link to 44 source records after grouping exact copies. Selection
evidence and full-frame source checks are under
`build/Other Files/Asset Toolkit/Cross Gate Judas Family/`. Color labels describe
the artwork; they do not establish original boss names or tameability.

Rendered attack review corrected the earlier shortlist's description of the
twelve older entries: their duplicate animation indexes refer to superseded
graphic layouts, and several attack frames now resolve to hurt/fall art. They
are not verified standalone older animation sets. Each keeps its selected
source key and source portrait, while its explicit `motion_key` prepares the
matching current body/color's valid motions. No guessed artwork or runtime
retargeting is used. The unmodified initial indexed export is retained under
the evidence directory's `Original Source Export/`; original client files are
unchanged. These twelve are compatible archive entries, not twelve additional
independent gameplay designs.

## Runtime and preservation

猶大 adjustment (2026-11-14 follow-up): all 36 saved boss identities are 35%
smaller than their preceding size, including the hidden aliases. The picker
retains 24 distinct choices; the twelve `motion_key` archive aliases have
identical six-state/eight-direction frames, placements, palettes, timing and
bodies to six main colors. `PetCatalog.listed` excludes them from every picker
filter. Their indices, exact saved keys, resources, skill assignments and
learned pet levels remain valid, including previously selected archive pets.
The earlier 2.5× boss baseline is now 1.625×; normal/XL sizes are unchanged.

Normal/XL distinction (2026-11-14): across the sixteen families with XL choices,
all 70 XL appearances are 1.5× their preceding family baseline and all 212
normal appearances are 0.9×. The XL source-resolution compensation remains;
doubling source pixels is not itself a larger world body. Existing family
adjustments below are baselines before this normal/XL factor. Families without
an XL choice retain their prior sizes, including 猶大 bosses and griffins.
Expansion families store the final values in the authored review list and
matching motion/catalog metadata. Mantis, dragon-lizard and bee slots use the
shared `size_variant_scale` in `pet_dimensions.gd`; this factor scales artwork,
fitted bodies, hover offsets and native contact sizing together at setup.

Size tuning (2026-11-14): all 36 猶大 bosses use 2.5× their previous size;
all 25 griffins and 12 large bats use 2×, including the five XL bats.
Their authored `visual_scale` and fitted `body` values live in
`tools/crossgate_pet_families.json`; keep each family's motion metadata and the
composed catalog synchronized when changing them. All 21 bees, including XL,
use `BEE_SCALE = .8` in `scripts/forest/crowd/pet_dimensions.gd`.
Rendering, fitted hitboxes, hover offsets and native contact sizing use the
same proportions. Original pixels, source frame tables, timing and saved keys
are preserved. Relaunch Play Goemon to load size edits; an app export is unnecessary.

All choices use native kind 19, its existing scattered-target preference, exact local contacts, player-threat priority, escort/reachability, F/G/H orders, missing-only P summons and five-pet limit. Existing selected keys, wounds, skill assignments, learned pet levels, wave counts, terrain and player controls are preserved. Flying artwork retains the current ground escort/navigation owner. Stats and skills use Goemon rules; original turn-based AI and balance are not installed.

The authoritative review list is `tools/crossgate_pet_families.json`. `tools/recover_crossgate_pet_families.py` calls the existing hound/mantis lossless indexer. Visible RGBA pixels, palettes, anchors, eight facings, source durations, frame markers and supplied WAV PCM hashes are checked during recovery. All six runtime states are complete for every enabled appearance. Available extra source actions are archived; ten damaged extra clips are explicitly marked unavailable and are not sampled by gameplay. Originals and reusable scenery remain untouched.

The combined timeline has 42 values per direction, enough for twenty cues.
Its prepared wire codes distinguish impact cues (10000 + sound ID) from
audio-only cues (20000 + sound ID). Original raw flags stay in metadata.
The S-reward bank uses source flags 10000–19999 for contacts. This preserves
all twenty of 時雨's cues with one hit on frame 46. Earlier banks keep their
prepared contact interpretation. Water impact 10265 remains silent because the
supplied client has no sound-table entry or WAV for 265.

Body fits and prepared visual scales are data in the review list. Rendered review lowered/tightened the bat core to match its hovering body and raised the silver/gold/pink golem cores for their taller original bodies. Wings, blades, tails, surrounding effects and foliage do not enlarge the body. Double-resolution XL sprites retain their pixels and half pixel size, with the existing doubled-origin adjustment. No combat-time asset loading, new renderer, retargeter or species-specific targeting owner is introduced.

Boss fits exclude swords, shoulder spikes and surrounding effects. For the 31
boss sources with a single-frame sprint pose, `run_action: 1` prepares the
original walking loop in the shared movement slot. The prepared family retains
the valid motion source's unmodified sprint pose, extra actions, durations and anchors.
This setup mapping changes no attack/contact timing and adds no runtime loop.

New atlas pages group a pet's frames together. The shared renderer prepares only pages needed by the selected pack and any remaining companion corpses when setting up/changing a loadout. It reuses those textures during combat. The first griffin dropped from 74 required pages in the initial packing to 4 without changing its art. Palettes are stored as eight 256-color strips per physical row, keeping all textures below the GPU dimension limit while preserving each logical palette row.

## Rebuild and verify

Run from the complete source used by the desktop Play launcher:

```sh
python3 tools/recover_crossgate_pet_families.py '/Users/eric/Desktop/Projects_Codex/Magic Power'
python3 tools/recover_crossgate_pet_families.py '/Users/eric/Desktop/Projects_Codex/Magic Power' --compose
python3 -m unittest discover -s tests/asset-toolkit -p 'test*pet*py'
python3 tools/goemon_assets.py audit assets/characters/crossgate/companions
python3 tools/goemon_assets.py check
```

If adding verified records, append them to the review list and keep the catalog, native count, dimension table and shader capacity synchronized; the catalog regression checks those contracts. Rebuild the native extension before running the updated source. Refresh Godot imports through the desktop launcher. Run `pet_family_combat_test.gd`, `pet_family_expansion_test.gd`, `pet_family_skills_test.gd` and `pet_family_visual_review.gd` through Play Goemon. The old loadout fixture protects save rollback, five-slot limits, wounds/death replacement and the original families. No app export is needed.

## Source records still withheld

The following 28 identified or suspected records are preserved in the review list and evidence, but are not selectable. They have unavailable required frames, an unverified palette, or an unverified combat/body origin. No small-sprite substitution, guessed decoder bytes or palette replacement is published. A longer independently verified stream, original key or intact source would allow another recovery attempt.

| Sprite ID | Exact source key | Limitation |
| --- | --- | --- |
| 119204 | `ch1:905` | Verified CH1 db03 resource stream is 26009 bytes; some source frames exceed it. No independent longer plaintext match found. |
| 119205 | `ch1:906` | Verified CH1 db03 resource stream is 26009 bytes; some source frames exceed it. No independent longer plaintext match found. |
| 119233 | `ch1:934` | Verified CH1 db03 resource stream is 26009 bytes; some source frames exceed it. No independent longer plaintext match found. |
| 119234 | `ch1:935` | Verified CH1 db03 resource stream is 26009 bytes; some source frames exceed it. No independent longer plaintext match found. |
| 119235 | `ch1:936` | Verified CH1 db03 resource stream is 26009 bytes; some source frames exceed it. No independent longer plaintext match found. |
| 119236 | `ch1:937` | Verified CH1 db03 resource stream is 26009 bytes; some source frames exceed it. No independent longer plaintext match found. |
| 102001 | `ex:1759` | Bear-shaped indexed pixels have a visibly corrupt/rainbow palette; no verified palette recovered. |
| 119131 | `puk3:608` | The artwork key for this source has not been recovered yet |
| 119132 | `puk3:609` | The artwork key for this source has not been recovered yet |
| 119133 | `puk3:610` | The artwork key for this source has not been recovered yet |
| 119134 | `puk3:611` | The artwork key for this source has not been recovered yet |
| 119208 | `ch1:909` | The artwork key for this source has not been recovered yet |
| 119209 | `ch1:910` | The artwork key for this source has not been recovered yet |
| 119206 | `ch1:907` | The artwork key for this source has not been recovered yet |
| 119207 | `ch1:908` | The artwork key for this source has not been recovered yet |
| 119148 | `puk3:625` | The artwork key for this source has not been recovered yet |
| 119139 | `puk3:616` | The artwork key for this source has not been recovered yet |
| 119140 | `puk3:617` | The artwork key for this source has not been recovered yet |
| 119141 | `puk3:618` | The artwork key for this source has not been recovered yet |
| 119142 | `puk3:619` | The artwork key for this source has not been recovered yet |
| 109917 | `puk3:860` | The artwork key for this source has not been recovered yet |
| 119262 | `ch1:963` | The artwork key for this source has not been recovered yet |
| 119276 | `ch1:960` | The artwork key for this source has not been recovered yet |
| 119277 | `ch1:961` | The artwork key for this source has not been recovered yet |
| 119247 | `ch1:948` | The artwork key for this source has not been recovered yet |
| 119248 | `ch1:949` | The artwork key for this source has not been recovered yet |
| 115282 | `update-ex:1929` | No source hit markers and an unstable embedded body origin below/away from the native unit; a usable original combat contract is unverified. |
| 108120 | `ex:971` | 布路亞: required death frame 392107 is damaged in the original source and unavailable in the current NewClient copy. |

The 19 later-discovered failed frame samples were compared at their referenced offsets across ten preserved installations: all 190 byte comparisons matched. A fresh db03 stream-extension search found no independent longer plaintext match. Detailed inventories, source/copy probes, the ten optional-clip failures, logs and rendered captures are under `build/Other Files/Asset Toolkit/Cross Gate Pet Expansion/`. Budget warnings do not authorize removing or redesigning any source artwork.
