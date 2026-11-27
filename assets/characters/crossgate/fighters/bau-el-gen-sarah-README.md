# Bau, El, Gen and Sarah

Stable playable IDs are **52 Bau, 53 El, 54 Gen and 55 Sarah**. Existing IDs,
saved loadouts, character recordings and the older shared skins remain intact.

| Character | Skin entries | Native weapon sets |
| --- | ---: | ---: |
| Bau | 19 | 104 |
| El | 17 | 102 |
| Gen | 18 | 98 |
| Sarah | 21 | 115 |

The reviewed inventory and exact source keys are in
`tools/crossgate_bau_el_gen_sarah.json`. It includes classic and updated sprites,
recolors, Bau's martial-artist colors, Sarah's pink lightning and gold companion,
and her red weapon set. The table counts visible gallery entries. Gen owns
115257 (gold dragon fist) and 124999 (silver martial sword), formerly misassigned
to Bau. Their original art and weapon/audio/head routes now live under Gen;
`hidden_bau_skins` retains the former Bau loadout keys for compatibility.
Special/event artwork is included regardless of its original unlock condition;
the local archives do not establish original server event names or unlock rules.

The raw discovery pass inspected 12,936 catalog records. Shape matches are only
a shortlist: standing and contact artwork were reviewed against the chosen
characters. The initial pass wrongly seeded those two Gen-family specials as Bau;
124999's lower-body idle/walk/run pixels match Gen in all 128 frames/eight facings.
The report folder retains the unavailable records and rejected
matches rather than silently assigning them to a character. No downloaded
client or server executable is run.

Keep these source exceptions explicit:

- Bau's red/black/purple martial artists reuse numeric ID 105608. Their source
  keys are pinned independently; new saved choices 900060/900061 distinguish
  red and black, while purple retains 105606. Kaz's existing 105608 stays intact.
- Bau 120168 supplies the unarmed pose for his matching 120166–120171 weapon
  family, whose five other records were absent from the earlier family list.
- Gen 100780 and 105112 are different green/blue looks despite being grouped
  together by the source index. Gen 100236 uses the six original Gen records;
  106192–106197 are Pippin and must never be substituted. Emilia's unrelated
  CH1 100230 skin also remains unchanged.
- Sarah's 120400/120406/120412 archive revisions retain their own complete weapon
  sets. Her 120433 red weapon set has five source weapons and no invented bare
  hand stance. Her companion skin keeps its source staff; the lightning skin
  keeps its source fist attack and complete baked effect pixels.
- GA1 125001 duplicates GA10 124999 and does not need another skin card. The
  report includes a full original frame/clock/event comparison for this alias.

The shared atlas packer preserves pixels, origins, clocks and source frame flags
for idle, walk, run, attack, cast, hurt, guard and fall in eight facings. Native
10000-series markers produce combat contacts; 20000-series markers remain
audio-only cues. Embedded weapon stances use the existing timed combat and bow
paths. Compatible unarmed sets also use the existing curved boomerang recovery.
No new per-character combat, renderer, targeting owner or runtime retargeting is
introduced. Textures, materials, cues and attachments are prepared at selection;
combat advances the existing prepared state. Footsteps and landings keep the
shared prepared Goemon defaults.

Rebuild in this order from the complete source:

```sh
python3 tools/recover_crossgate_four_cast.py '../Magic Power'
python3 tools/prepare_crossgate_boomerangs.py '../Magic Power'
python3 tools/prepare_crossgate_boomerangs.py '../Magic Power' --check
python3 tools/prepare_crossgate_heads.py
python3 tools/prepare_crossgate_player_audio.py '../Magic Power'
python3 tools/prepare_crossgate_cosmetics.py
python3 tools/recover_crossgate_four_cast.py '../Magic Power' --check
python3 tools/prepare_crossgate_heads.py --check
python3 tools/prepare_crossgate_player_audio.py '../Magic Power' --check
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py check
'/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/four_crossgate_cast_test.gd
'/Users/eric/Desktop/Play Goemon.command' --headless --script res://tests/forest-shrine/mirror_movement_test.gd
'/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/four_cast_cosmetics_test.gd
'/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/crossgate_movement_feel_test.gd -- --visual --four-cast
```

For an addition-only attachment update, `--extend-heads-from PATH` accepts the
exact previously preserved `model-head-provenance.json` receipt. It rejects a
receipt with the wrong hash, changed old head records or modified attachment
outputs; unchanged atlas points are retained and new regions are fitted. The
first integration's verified receipt is `heads-before.json` in this report
folder. Omit the option when changing an existing head crop.

The regular weapon preparer also knows these four roots for future full catalog
rebuilds. The recovery publishes head catalog entries and the individually
reviewed crop rectangles through the existing head preparer. Preserve painted
masters and conversation portraits.

Evidence belongs under `build/Other Files/Asset Toolkit/Bau El Gen Sarah/`.
These are source additions; app export is a separate user-requested action.
