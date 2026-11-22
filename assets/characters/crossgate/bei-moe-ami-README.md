# Bei, Moe and Ami — complete reviewed local inventory

Stable fighter IDs 48 / 49 / 50 add Bei, Moe and Ami to the shared Cross Gate
roster. Their default skins are 105125 / 105275 / 105300. The existing skin
picker, equipment validation, per-skin saves, original model heads, shared
combat and native army copies remain the owners. Walking and landing use the
prepared Goemon defaults. No companion species or targeting loop is added.

| Fighter | Appearances | Supplied weapon combinations |
| --- | ---: | ---: |
| Bei | 23 | 128 |
| Moe | 28 | 158 |
| Ami | 21 | 121 |
| Total | 72 | 407 |

`tools/crossgate_bei_moe_ami.json` is the authoritative reviewed input. Every
weapon names its archive key explicitly. The inventory includes classic and
remodel colors, alternate armor/ribbons, and pet/effect records:

- Bei 120386: silver hair, black pirate hat, purple coat and original purple sword effect (`update-ex:1915`), sword only. The six coat/color sets include the explicitly requested 100937.
- Bei 109876: original blue flames, fists only (`puk3:819`).
- Moe 106708: glowing gold sword only (`original:3224`).
- Moe 120110: gold staff only (`v3:1182`); normal navy Moe uses skin 120328.
- Ami 115258: original crescent sword effect only (`update-ex:1913`).

Several archive IDs collide across packs. For example `ch1:822` is green-haired
Bei while `joy-ex:528` uses the same numeric ID for another character. The
pirate Bei outfits uses the reviewed CH1 keys; its brown fist record is the
recoverable `v3:1270` because `ch1:840` has missing artwork. Source weapon labels
for gray/purple Moe and pink Ami are also wrong: visual neutral/contact review
establishes the ordinary six-weapon order at `joy-ex:842–847` and `61–66`.
Never substitute numeric-ID siblings or infer weapons for fixed pet records.
Existing other characters' saved appearances and assets remain preserved.

The discovery scan covers all 12,936 catalog records, with family previews and
1,353 additional artwork groups reviewed. Another 1,911 omitted index rows
have identical animation tables to cataloged aliases; recoverable representative
artwork samples also match. Records without standing poses, unavailable artwork
keys and undecodable images are recorded, not reconstructed. This is the complete
reviewed recoverable inventory found in the supplied archives, not a claim about
unavailable assets or other clients. Discovery, source comparisons and gameplay
evidence live under `build/Other Files/Asset Toolkit/Bei Moe Ami/`.

Rebuild from this project, preserving all source archives:

```sh
python3 tools/recover_crossgate_special_skins.py '../Magic Power' --cast-only
python3 tools/recover_crossgate_special_skins.py '../Magic Power' --cast-only --check
python3 tools/prepare_crossgate_weapons.py '../Magic Power' --check
'/Users/eric/Desktop/Play Goemon.command' --headless --script res://tests/forest-shrine/skin_head_hud_test.gd -- --catalog
python3 tools/prepare_crossgate_heads.py
python3 tools/prepare_crossgate_heads.py --check
python3 tools/goemon_assets.py check
'/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/bei_moe_ami_test.gd
```

The original-head preparer uses the reviewed per-skin crop table; preserve that
editable table and existing painted/conversation masters. Future new skins need
an explicit crop before rebuilding heads. Source preparation preserves original
RGBA pixels, anchors, event flags, durations, audio and exact supplied weapons.
The native copy validator accepts kinds 148–150 alongside existing hero kinds;
retired 141 and the out-of-range 151 remain rejected. Rebuild that extension
with `native/terrain_math/build.sh` after native changes; it is not an app export.


Verified 2026-11-16 with the Shin follow-up: all 86 added appearances / 465
weapons pass 84,097 desktop checks, including five simultaneous native attackers
for seven representative looks. The shared exporter verifies 237,200 original
frames/origins. The head cache has 272 checked routes; the full weapon inventory
has 271 appearances. The focused frame sample is documented in the performance
guide and is not a full-army or long-session claim. Source effects and rendered
attack captures were visually reviewed separately. No app was exported.
