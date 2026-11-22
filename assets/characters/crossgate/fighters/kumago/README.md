# 熊哥 playable sprites

Stable playable ID **51**, native mirror kind **151**, shared Cross Gate model,
combat, equipment, save and portrait owners. The undersea boss remains unchanged.
The user confirmed source actor 100802 (熱砂的歐茲尼克) as the requested 雄哥/熊哥.
His default is the original red outfit and unarmed attack, at the common player
body height rather than the boss's larger encounter fit.

`tools/crossgate_kumago.json` is the editable, pack-qualified source inventory:

| Appearance | Supplied weapons | Source |
| --- | --- | --- |
| 100800 · Original red / blue | Fist, axe, bow, sword, staff, spear | original:2795–2800; unarmed actor 100802 is original:2797 |
| 120443 · Dark red / black | Fist | puk3:665 |

Do not invent dark weapon siblings or recolor the original images. The six
original weapon records retain their whole poses, grips, offsets, RGBA pixels,
source durations and contact/audio markers in all eight directions. Source
20000-series cues are audio only, not extra hits. Sword, axe, staff and spear
wind reuse the existing downward-stroke presentation after source sequence
review. Fists use the existing punch gust; bows use pooled arrows.

The source family contains these two appearances. A standing-silhouette search
of 864 catalog appearances (862 readable idle sets) also finds the related Bog
family 100150/100156/100162/100168/100625/100942/105597. These are not silently
assigned to 熊哥. Older duplicated records original:422/1212/2002 retain other
standing drawings in the source archive; joy:658 duplicates original:2797.
Contact sheets and the search receipt are in the Kumago toolkit folders.

Rebuild only this identity, preserving other prepared character artwork:

```sh
python3 tools/recover_crossgate_special_skins.py '../Magic Power' --cast-only --character 51
python3 tools/recover_crossgate_special_skins.py '../Magic Power' --cast-only --character 51 --check
python3 tools/prepare_crossgate_player_audio.py '../Magic Power'
```

After changing atlas coordinates or adding a look, refresh the head catalog
using `skin_head_hud_test.gd -- --catalog`, review its explicit crop in
`assets/ui/portraits/crossgate/model-head-crops.json`, then run
`prepare_crossgate_heads.py` and `prepare_crossgate_cosmetics.py`. Never replace
painted or conversation portraits. Original source archives remain untouched.
The three default atlas pages total about 46.8 MiB as raw RGBA, shared by the
hero and its copies; the dark atlas is about 6.7 MiB. Setup owns loading and
material preparation. No attack-time loads, new renderer, target scan or pool
are added.

Run `tests/forest-shrine/kumago_playable_test.gd` for both looks, seven actual
weapon choices, all original animation frames, exact combat, audio previews,
save/reload, weapon cycling, sprint release, shared native copies and repeated-use
resource checks. Its desktop captures are visual evidence separate from the
technical assertions. Normal development uses Play Goemon; no app export is
needed.
