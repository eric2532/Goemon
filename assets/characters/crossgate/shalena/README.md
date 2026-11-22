# Tina and Shalena original enemies

The authoritative editable recipe is `tools/recover_habaru_encounter.py --shalena`.
It reuses the existing BlueCG indexed-sprite preparation and native hound/slime
batch contracts. `assets/maps/falan/tina/encounters.json` records the sixteen
original archive keys, names and standing-height ratios; its recipe is
`tools/recover_shalena_encounters.py`. No original client files are modified.

Reproduce from the complete Sonic source:

```sh
python3 tools/recover_shalena_encounters.py
python3 tools/recover_habaru_encounter.py '../Magic Power' --shalena
python3 tools/recover_shalena_encounters.py --check
```

The encounter recipe verifies the pinned `crossgate_tina/events/references.json`
records, follows encounter → group → enemy → enemybase, and preserves the most
local region, species membership, group/member weights and native level ranges.
It retains the rare level-one spirit entry as well as normal night enemies.
These are corroborating server records, not recovered BlueCG server state.
Visible patrol counts/posts and HP/damage use the existing real-time adaptation.

`crowd/shalena_sprites.gd` binds those records to the existing cached atlas,
geometry and sound contracts. `forest_waves.gd` owns bounded patrol population;
the native army owns movement, combat, targeting, counters, death and pooled
presentation. The sixteen source contact tables are padded to the existing
29-skin wire format. Setup chooses species with weighted shuffle bags and
levels with range bags, drawing without replacement before refill. Saved-map,
character and companion IDs and native variation remain unchanged.

Original map 4201 alone gets night-village patrols: blood skeletons, spirits and
pirates. Day village 4200 stays peaceful. Source maps 400/402 get the recorded
Shalena wildlife during both day and night, through their existing aliases and
crops. Cleared wild patrols replenish through the existing outdoor owner when
the player leaves their spawn; map transitions do not retain obsolete actors.
The shared clock still takes 24 minutes, and dawn restores the peaceful source
village. No additional enemy simulation or per-species targeting loop exists.

Review through Play Goemon with
`--script res://tests/forest-shrine/tina_night_encounters_test.gd`.
Headless checks cover memberships/levels, shuffle bags, dusk/dawn, spawn
clearance, player exclusion, bounded replenishment, native handles and repeated
exact contacts for all sixteen species. Desktop review adds live village/road
captures and idle/attack lineups. Evidence and limitations are under
`build/Other Files/Asset Toolkit/Tina Recovery/Night Encounters/`.
