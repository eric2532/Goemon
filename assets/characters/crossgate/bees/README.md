# Recovered Cross Gate bees

The Bees category contains exactly the first 21 reviewed source IDs below. The 11 historical base-art/animation versions are excluded. Existing hound, mantis and dragon-lizard keys keep their order and saved selections. Color/effect labels are descriptive, not verified official event names.

| Source ID | Exact source key | Appearance |
| --- | --- | --- |
| 101310 | original:2862 | 殺人蜂 |
| 101311 | original:2863 | 異型蜂 |
| 101312 | original:2864 | 虎頭蜂 |
| 101313 | original:3170 | 黃蜂 |
| 101314 | original:2866 | 死亡蜂 |
| 102360 | ex:1599 | 青藍 |
| 102361 | ex:1600 | 橙黃 |
| 102362 | ex:1601 | 粉紫 |
| 102363 | ex:1602 | 紫色 |
| 102364 | ex:1603 | 綠色 |
| 108208 | joy-ex:552 | 紫紅 / 金翼 |
| 108333 | puk2:705 | 粉紅 / 橙翼 |
| 117136 | puk3:337 | 白色 |
| 109879 | puk3:822 | 雪花 · 舊檔案 |
| 116562 | puk3:708 | 雪花 |
| 118949 | v3:1929 | 閃電光環 |
| 119190 | ch1:891 | 殺人蜂 XL |
| 119191 | ch1:892 | 異型蜂 XL |
| 119192 | ch1:893 | 虎頭蜂 XL |
| 119193 | ch1:894 | 黃蜂 XL |
| 119194 | ch1:895 | 死亡蜂 XL |

## Rebuild and source preservation

Run `python3 tools/recover_crossgate_bees.py '/Users/eric/Desktop/Projects_Codex/Magic Power'`. This reuses the hound/mantis indexed-pixel packer and combined pet bank. All visible RGBA pixels, palettes, frame offsets, animation durations, source cue markers and recovered WAV PCM hashes are checked during recovery. Source archives and the three existing families are untouched.

The approved bees archive 1,352 source clips / 15,000 frame references, including eight facings and the extra preparation action on 108333. The existing six army presentation states use the same source actions as the other companion families. All other recovered actions and cues remain in the family manifest. The original field bee in the Explore enemy roster is unchanged.

The portrait sheet has five columns and enough rows for every choice; the twenty-first portrait is explicitly checked for visible pixels. The shared guard bank references existing atlas pages and concatenates lookups/palettes. Its source hashes and every combined frame offset/rectangle are tested by `tests/asset-toolkit/test_pet_sprite_bank.py`. Rebuilding an older family keeps the bee bank appended.

Keep 109879 at `puk3:822`; its latest ID-only lookup `puk3:908` contains unrelated artwork. Both approved snow IDs remain separate choices despite identical recovered artwork/timing. Yellow uses `original:3170`, not the earlier `original:2865`. No older 101310–101314 source records are included.

## Runtime and size

Bees append skins 61–81 in the shared native kind-19 companion owner. The total catalog is 82 choices; at most five selected/queued/live companions remain allowed. P still summons only missing selections. Bees and Aura & effects filters reuse the current image picker; the latter includes both snow IDs and lightning.

Original flight height and shadow remain in the sprite frames. Ordinary bees use .0375 source pixel density; the five double-resolution XL sources use .01875 and the existing doubled-origin ground adjustment. The fitted core is 32×52×34 source pixels, raised 24 pixels above the ground anchor, before the existing hound world scale. Wings, ground shadow and effects are excluded from the hurtbox. Existing ground navigation/escort rules remain; this does not introduce a second flying-unit simulation.

Native source contact 143 joins the existing impact cues, preserving the original one/two-contact timing. Swing 117 and buzz 161 play through the shared attack audio pool without causing extra damage. Existing 137 contacts remain unchanged. Team HP/damage progression, cooldown ownership, player controls and fallback footstep/landing sounds are unchanged.

The 17 new R8 2048×2048 atlas layers add 68 MiB of prepared texture storage. The combined bank now has 83 layers / 332 MiB before runtime overhead. Assets are prepared during setup; there is no new renderer, controller, pool, per-hit loading or per-pet army scan.

## Verification

The full desktop launcher loadout test checks image/category selection, last portrait, old-key exclusion, persisted saves, wounded-survivor preservation, death replacement, failed saves, empty packs, five simultaneous ordinary/snow/lightning/XL bees, small-window layout and repeated UI reuse. `bee_pet_test.gd` exercises repeated native attacks and original sound cues on all 21 skins. The native pet-geometry fixture checks all 82 skins, contact-vs-presentation cues and real projectiles below/through/above a hovering body.

Fresh results, source hashes, captures and limits are recorded in `build/Other Files/Asset Toolkit/Cross Gate Bees/implementation-verification.json`. The original review files remain there separately. Standalone combat checks emit teardown resource/RID warnings; the full desktop loadout fixture exits without engine errors. No app export or full-army/long-session soak was run.
