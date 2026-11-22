# Special character skins from pet/effect artwork

## Transparent edge imports — 2026-11-16

Keep `process/fix_alpha_border=true` on recovered green-key atlases. Transparent
RGB still affects filtered sprite edges even when the source alpha is zero.
The full attack review corrected 27 pages belonging to Uru
108921/109897/109903/109909/111691, Pete 100731 (including five weapon pages),
Rei 109912 and Cedi 111617/111618/111619. Original PNG bytes, visible source
artwork, shadows, aura effects and attack timing are preserved. The selected-cast
and weapon preparation templates now retain the safe import setting. The
read-only `tools/audit_crossgate_attack_art.py '../Magic Power'` catches unsafe
green-key imports; rendered before/after evidence is under
`build/Other Files/Asset Toolkit/Cross Gate Attack Silhouettes/`.

## Bei, Moe and Ami — 2026-11-16

Their three new stable identities share this exporter through the separate
`CAST_CATALOG`: 72 reviewed appearances and 407 exact supplied weapon sets.
Use `--cast-only` to rebuild/check these characters while preserving the earlier
Special and Uru catalogs. The inventory includes fixed pet/effect records and
pack-qualified keys for reused numeric IDs. See
[the character inventory](bei-moe-ami-README.md) for counts, source collisions,
rebuilds and the focused gameplay fixture. Pet artwork is a character skin;
this does not add a separate companion or targeting owner.

The same catalog also adds 14 Shin 2.0 appearances / 58 supplied weapon sets to
existing Shin Special, including requested 120352 and the reviewed pet/aura
artwork. See `shin/README.md` and `tools/crossgate_shin_2_skins.json`.

## Current ownership and original heads — 2026-11-16

The shared Special catalog now has fifteen appearances: the earlier twelve plus
Rei's black/gold armor 100700 and ornate outfits 100798 / 120428. Those three
outfits and the red-rune 109912 were incorrectly assigned to Uru in the prior
expansion; all four now appear only under Rei. Original red-rune Rei remains
unchanged. Classic black Ruby 100650 belongs to Uru and is removed from Rei's
earlier family list. The two incorrect duplicate preparation folders are
preserved under `Model HUD Heads/Previous Misassignments/` with review evidence,
so the weapon preparer's folder inventory cannot recreate the wrong routes.

Uru now has 32 choices / 182 weapon combinations, including eight Special
choices. Rei has 17 choices. Nine Special catalog choices still use a single
fixed source weapon; the complete fifteen choices have 44 supplied combinations.
Rei's ornate red outfit retains five weapons without fists. All manifest
`source_weapons` keys remain binding. Current new Uru inventory lives in
`tools/crossgate_uru_skins.json`; the original exporter and cached roster merge
remain shared. No new character, companion or native simulation is added.

All HUD heads now use original model pixels, standing front pose and common
alignment. Historical painted masters and `skins.json` routes are preserved;
`model-heads.json` is the live HUD table. See
`assets/ui/portraits/crossgate/README.md` for the final head preparation commands
required after character recovery. Source/ownership regression evidence lives in
`build/Other Files/Asset Toolkit/Model HUD Heads/`.

## Earlier twelve-skin recovery (historical)

The earlier character galleries included twelve additional reviewed appearances:
Cedi 111617/111618/111683, Emilia 106706/120389, Rei 109912, Shin
100462/108151, and Uru 108921/109897/109903/109909. They are labelled
`Special · …` under those same stable character IDs. No companion entries or
character IDs are added. Cedi's already-present 111619 effect appearance is also
labelled Special, keeping its existing unarmed-only weapon. 紫夜 is Cedi 111618;
the other labels describe artwork, without inventing original pet names or claiming original tameability.

Nine choices have a single fixed source weapon. Uru's black/yellow, gold and
gold-circle choices each have all six supplied weapons; her flame appearance
has only its original staff. Each manifest's `source_weapons` is authoritative.
The equipment preparer must not infer siblings from neighboring IDs or the
normal player-character family. The source list and exporter live in
`tools/recover_crossgate_special_skins.py`.

The additional Kaz source 116567 (`puk3:713`) is already represented by skin
109891 (`puk3:834`): all 672 frames, visible pixels, placements, durations and
event flags match. It does not create a duplicate gallery entry. Existing skins,
painted portraits, character IDs and saved loadouts remain valid. Uru's original
skin uses setting `ruby_skin = 0`, her original asset root and original `35`
loadout/painted-head key; her special skins receive their own existing-style
`35:skin` keys. Shin additions stay under Shin, not a new character.

Preparation retains original RGBA pixels, anchors and source clocks. 10000 is
a silent impact; 20000-series markers are audio-only. Uru's staff uses its
existing five-contact staff behavior and original cue clocks. Other source
weapons use the shared timed-melee or bow path. Selection prepares textures,
materials and samples; attacks only advance the prepared data. Native copies,
targeting, hit checks and pooled effects remain under their existing owners.

Rebuild after any base skin/weapon recovery (base tools may rewrite catalogs):

```sh
python3 tools/recover_crossgate_special_skins.py '../Magic Power'
python3 tools/recover_crossgate_special_skins.py '../Magic Power' --check
python3 tools/prepare_crossgate_weapons.py '../Magic Power' --check
python3 tools/goemon_assets.py check
'/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/crossgate_special_skins_test.gd
```

The discovery scan examined 12,936 catalog records; another 1,911 omitted
NewClient EX aliases have unchanged animation tables. Head masks were only a
shortlist, followed by neutral/attack artwork review. Unrelated characters,
sitting-only records and uncertain identities are not assigned to a hero.
In particular `puk2:892`, `puk2:1165`, `puk2:886` and `puk2:1104` did not
establish an identity in the current roster. Damaged/undecodable archive records
are not reconstructed or silently substituted. This is an inventory of verified
available artwork, not a guarantee about every future client or server.

Reports, discovery scripts, source reviews, the duplicate proof, complete
preservation receipt and desktop captures are in
`build/Other Files/Asset Toolkit/Character Pet Variants/`. Use the Play launcher
to select a character, open Q → Equipment, click its portrait and choose a
Special skin. Fixed-weapon choices show only that weapon. No app export is needed.


## Earlier Uru inventory expansion — 2026-11-16 (ownership corrected above)

A further 31 reviewed Uru appearances are prepared by the same exporter from
`tools/crossgate_uru_skins.json`. Its flat `URU_CATALOG` merges only into Uru's
existing gallery, alongside the four earlier Special choices. Uru now has 36
choices, 12 labelled Special, and 200 exact source weapon combinations. The
original setting 0 stays unchanged. See `ruby/README.md` for source families,
fixed weapons, duplicates and verification. New Uru heads use `uru-ID.png`;
existing `special-ID.png` routes, including Rei 109912, remain preserved.
The expansion's discovery and gameplay evidence lives under
`build/Other Files/Asset Toolkit/Uru Complete Inventory/`.
