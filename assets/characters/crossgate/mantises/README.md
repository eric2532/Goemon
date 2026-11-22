# Recovered Cross Gate mantises

The loadout offers 20 reviewed mantis sprite IDs alongside 21 hounds. These are
original recovered sprites, including effects and superseded records, not new art.
The names in the picker are descriptive English appearance labels; unidentified
archive IDs are not assigned invented official event names.

| Source ID | Exact source key | Picker label |
| --- | --- | --- |
| 101320 | original:2867 | Green |
| 101321 | original:2868 | Killer |
| 101322 | original:2869 | Red-eye |
| 101323 | original:2870 | Ash |
| 101324 | original:2871 | Deadly |
| 108165 | joy-ex:622 | Pink |
| 108166 | joy-ex:623 | Lavender |
| 108209 | joy-ex:553 | Violet |
| 108443 | ch1:486 | Crescent |
| 109271 | ch1:688 | Pale green |
| 109880 | puk3:823 | Snow (archive) |
| 109932 | puk3:875 | Red aura |
| 116563 | puk3:709 | Snow |
| 117029 | v3:775 | White |
| 117137 | puk3:338 | Black |
| 119195–119199 | ch1:896–ch1:900 | Green / Killer / Red-eye / Ash / Deadly XL |

## Search coverage and limits — 2026-11-12

Inspected the local Magic Power catalog's 12,936 records across all 11 registered
packs, including superseded source indexes. Compared neutral/movement/attack
clip patterns, reviewed 528 creature candidate thumbnails, and independently
ranked all 4,385 prepared pet/creature thumbnails by silhouette against eight
mantis designs; inspected the leading 300. This recovered 19 current entries plus
one retired entry. The 35 matching records retain older source versions; repeated
source records do not create duplicate loadout buttons.

Crucially, ID 109880's current `puk3:909` record has different artwork. The snow
mantis is `puk3:823`. Save source keys, not ID-only lookups. Both snow IDs remain
selectable even where visible frames coincide. The five XL sources retain their
higher-resolution original pixels and use half the pixel scale of the ordinary
sources, so their doubled artwork does not double their gameplay size.

Two broad-search candidates remain unreadable: `original:3286` (109606) and
`original:3420` (109739), using an unknown `3c22` resource key. The third candidate,
`ch1:382` (117154), is now recovered as a **white spider**, not a mantis. Its 320
encrypted payloads were at the correct addresses: every stored length matches
and all payloads decrypt and decompress using the known `f99a` key. The stale
index dimensions, rather than missing artwork or an unknown key, caused failure.

The Magic Power decoder now applies a per-record dimension correction from each
image's own RD header. Corrections require the exact original index fields and
the payload SHA-256; mismatched sources fail rather than accepting another image.
Both animation and individual-artwork readers use the corrected sizes. All 72
clips / 936 frame references export, retaining source pixels, palettes, timing
and original x/y offsets. No independently indexed duplicate was found, so the
original offsets remain unverified; varying source frame sizes and movement are
not smoothed or guessed. The spider was not added to Goemon's mantis loadout.

The read-only investigation compared all 11 registered packs, the NewClient
source and nine preserved installation copies. All ten backup copies have the
same referenced bytes. The Original key search rejected all unpadded decimal
suffixes 0–99,999,999 after the known `cgdev_ig_1_regber_` prefix, plus nearby
known-key candidates. This is a bounded candidate search, not proof that the key
cannot be recovered. Comparing 66,402 `3c22` graphics with 11,883 decoded
metadata-matching candidates produced no verified stream: trial streams yielded
blank/solid images and invalid compressed data. No key, location override or
substitute art was installed. The CH1 first-frame header search found no matching
copy with its known cipher across the registered containers.

The subsequent client trace found the missing-key mechanism: both restored DLLs
ask Lua `getanimedo` for a suffix. Bootstrap prototype 0.60 receives nested
Base64/RC4 configuration through `spsset` / `diyanimedo_config`; prototype 0.61
decrypts a cached suffix and builds `cgdev_ig_1_regber_` plus that suffix. Both
caches initialize empty. The older and NewClient bootstrap bytecode is identical.
No configuration payload was found in the 72 inspected restored-code/Lua files.
A second 0–99,999,999 suffix search checked signature and stored length without
assuming the index dimensions; it also found no match. A preserved runtime key
configuration or original operator-side key data is the missing evidence, not
another confirmed static key table in the supplied client. No login or client
execution was performed.

The remaining pair's family is unverified. This is the complete *identified* mantis inventory in
the supplied decoded library, not proof that every encrypted or external archive
contains no additional variant. Event provenance and official names are unknown
for several appearances. Do not relabel those as verified event rewards.

Research scripts, full inventory, source records, similarity scores, contact
sheets and an animated preview are under
`build/Other Files/Asset Toolkit/Cross Gate Mantises/`.
The `Client Trace/` subfolder contains the exact key-path evidence, repaired spider
preview, original-timing idle GIF and all 72 exported clips. The Magic Power
recovery command is `python3 tools/recover_ch1_spider.py`; it only regenerates
`data/crossgate/graphic-dimensions.json`, leaving the original archives untouched.

## Rebuild and preservation

```sh
python3 tools/recover_crossgate_mantises.py '/Users/eric/Desktop/Projects_Codex/Magic Power'
python3 -m unittest discover -s tests/asset-toolkit -p test_pet_sprite_bank.py
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py check
```

The extractor reuses the hound index/palette packer. It preserves exact visible
RGBA pixels, all 1,288 source clips across eight facings, 12,728 frame records,
source timing/contact/audio markers, and six original WAV PCM hashes. All source
actions are archived; the common six movement/combat states use the existing army
presentation. `motions.json` records every source clip and marker. No substitutions
were needed for these mantis frames. Original archives and hound assets are untouched.

`../guard_pets/` is a generated combined lookup/palette, referencing existing hound
and mantis atlas pages. It does not duplicate or rewrite their image pages. Its
manifest records source hashes; the preservation test checks the original hound
lookup, palettes and timelines as well as every combined frame rectangle. Do not
hand-edit generated assets. Rebuild from the preserved source instead.

## Runtime contract

Kaz review follow-up (2026-11-12): all 20 mantises now render at 85% of the
prepared size described below, in Explore and the arena. This is an authored
runtime multiplier in `scripts/forest/crowd/pet_dimensions.gd`; do not rebake or
shrink the preserved source pixels. That table also fits every companion's core
hurtbox and supplies proportional mantis melee reach. Native projectile checks
and arrival clearance use the fitted bodies. Hound visual sizes are unchanged.

All 41 appearances reuse native kind 19 and its existing escort, targeting,
contact, summon, corpse and audio pools. The historical `HOUND_SKINS` constant is
the shared skin-bank size, not the active-pet limit. Native validation recognizes
the recovered mantis swing/contact IDs. The UI/settings boundary and placement
queue enforce five selected unique source keys including queued arrivals.

Mantises use the existing 3,000 HP / 30 damage per source contact / 4.5 m/s guard
baseline and pet-card modifiers. Their one/two source contacts remain distinct;
these are Goemon balance values, not claimed original server stats. Footsteps and
landing fallbacks are unchanged. Original aura/snow effects remain in their frames.

The size follow-up uses the hounds' `.0375` pixel scale for ordinary mantises and
`.01875` for the five doubled-resolution XL records. Previously, fitting the whole
image to 78 pixels shrank bodies according to their shadows and effects. Ordinary
mantises are now about 24–41% larger, snow variants 55% and the red aura variant
83%; XL variants grow about 23–40%. Original source origins are retained, with the
shared 10-pixel ground anchor adjusted for XL resolution. Native HP, damage,
reach and fitted hound collision baseline are unchanged. This matches pixel
density and comparable body scale, not identical heights across different species.

The shared bank allocates 49 R8 2048×2048 atlas layers (196 MiB uncompressed):
22 existing hound layers plus 27 mantis layers. This is setup cost, not a claimed
FPS optimization. No assets, meshes or materials are loaded per attack or hit.

Verify with Play Goemon: open Pets / Shift+P, choose any mix up to five, save, close,
and press P. Repeat P, wound one pet, kill one, change filters, swap one selection,
and restart. P must neither duplicate nor heal surviving pets. G/H command either
family. Save failures leave the old selection and live pack intact.
