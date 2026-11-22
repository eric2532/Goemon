# Recovered Cross Gate dragon lizards

The image-based loadout includes only the twenty approved source IDs below. The eight older base-art records and unverified 109457 are excluded. Names are descriptive appearance labels, not verified event titles.

| Source ID | Exact source key | Appearance |
| --- | --- | --- |
| 101720 | original:2940 | 地龍蜥 |
| 101721 | original:2941 | 水龍蜥 |
| 101722 | original:2942 | 火龍蜥 |
| 101723 | original:2943 | 風龍蜥 |
| 103379 | puk2:1303 | 粉紫 / 白背棘 |
| 103380 | puk2:1304 | 紫色 / 黃背棘 |
| 103381 | puk2:1305 | 粉紫 / 黃背棘 |
| 103382 | puk2:1306 | 深紫 / 藍背棘 |
| 107917 | ch1:619 | 青綠 |
| 107918 | ch1:620 | 黑灰 / 藍背棘 |
| 109260 | ch1:677 | 珊瑚粉 |
| 117028 | v3:774 | 白色 |
| 117151 | puk3:352 | 黑色 |
| 109878 | puk3:821 | 雪花 · 舊檔案 |
| 116561 | puk3:707 | 雪花 |
| 109938 | puk3:881 | 綠色光環 |
| 119268 | ch1:969 | 地龍蜥 XL |
| 119269 | ch1:970 | 水龍蜥 XL |
| 119270 | ch1:971 | 火龍蜥 XL |
| 119271 | ch1:972 | 風龍蜥 XL |

## Recovery and runtime

Rebuild with `python3 tools/recover_crossgate_dragon_lizards.py '/Users/eric/Desktop/Projects_Codex/Magic Power'`. This reuses the mantis/hound indexed-pixel packer. Its per-frame asserts preserve visible RGBA pixels, source x/y anchors, palettes, timing and original WAV PCM hashes. All eight directions and eight source actions are archived; the existing six-state army presentation plays its usual subset.

Recovered 1280 clips, 18352 frame references, 17 R8 2048×2048 atlas pages and 5 original sounds. The shared bank references existing family atlases without copying them. Its 66 R8 layers total 264 MiB before runtime overhead, up from 196 MiB; new artwork adds 68 MiB of setup texture storage. No new runtime pools, per-pet controller, renderer or combat-time asset loading were introduced.

Ordinary sources use the hounds’ .0375 pixel density; four double-resolution XL sources use .01875, with the existing doubled-origin ground adjustment. Effects do not shrink the body. The fitted quadruped core is 62×55×80 source pixels before the established hound world scale, excluding tail and particles. Mantises retain their independent 85% multiplier. All families use native kind 19, shared team growth, escort, contact, audio, corpse and summon ownership. Newly recognized contact cue 138 deals the existing per-contact damage; swing 110 and aura 191 emit audio only. The five selected/queued/live-pet limit and stable source-key saves are unchanged.

Keep snow source 109878 at `puk3:821`: its current `puk3:907` artwork is unrelated. Snow IDs 109878 and 116561 have identical recovered art/timing but remain two approved choices. The old versions `original:565–568` and `original:1355–1358` are not in this loadout.

## Record 109457 investigation

See `build/Other Files/Asset Toolkit/Cross Gate Dragon Lizards/` for the index, exact-header search, archive-copy hashes and validation logs. Its 64 clips reference 328 graphics (103590–103917), totaling 1,000 frame references. The first recorded address 764027185 is also used by unrelated graphic 103918. Decrypting its header with the existing f99a key yields 376×448 / 41,092 bytes, whereas 103590 expects 192×216 / 10,524 bytes. Even the other block’s indexed payload fails compressed-pixel validation. Reading past the declared payload produces visibly corrupt data and was rejected. This is evidence of an overlapping/stale index or damaged/replaced source block, not a verified new encryption key.

Thirteen preserved CH1 archive copies, including NewClient, contain identical bytes throughout the referenced range. The alternate nested index has the same numeric addresses, dimensions and lengths, with only address sign changed. A fresh search across all 16 registered containers (25770955132 bytes) found no exact header matching four sampled missing frames under 18 known resource keys or plain RD v1/v3 headers; a synthetic positive control validates the scanner. No speculative decoder correction, borrowed artwork or new pet was installed. Membership in this family remains unverified. A distinct intact archive/index pair would be needed to resolve this candidate.

## Verification

Use `python3 -m unittest discover -s tests/asset-toolkit -p test_pet_sprite_bank.py` for stable-order/source/frame/palette preservation. `tests/forest-shrine/dragon_lizard_test.gd` exercises repeated native attacks and original sound cues for all twenty skins; `pet_loadout_test.gd` covers image filters, persisted saves, missing-only summons, wounds, deaths, failed saves, five concurrent effect/XL pets and repeated panel reuse. Native `pet_geometry_test.cpp` verifies all companion projectile bounds and distinguishes impact from swing/aura audio. Launch rendered tests with the existing desktop Play Goemon launcher. No app export is required.
