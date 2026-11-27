# University native encounter sprites

Prepared by `python3 tools/prepare_university_region_encounters.py --pack`, through the existing `recover_habaru_encounter.recover` pipeline. Read-only input: adjacent `Magic Power` archive. Actor keys and proportions are in `assets/maps/falan/university_region/species.json`; source encounter/group/enemy/base rows and hashes are in `encounters.json`.

One regional bank contains sixteen recovered appearances. Other creatures reuse the existing native companion bank. The shared native army owns movement, target selection, exact contacts, damage, pooling and presentation. This is not another army implementation. No native skin-capacity change.

Preserve original frames, origins, cues and editable/archive inputs. Rebuild derived atlases, palette, frame buffer and timelines through the preparer. Authored relative heights do not prove visual approval or original turn-based combat behavior. Boss spells/AI require a separate behavior audit.

The three-phase Sylph chain requires final form `v3:162`, which is excluded from this bank: its source has no attack-contact cues or death clip. It is a seated rider-only sheet, while classic quest references show a mounted final phase. The original mount binding, offsets and attack-contact timeline are unavailable. The whole fight stays withheld; do not substitute an unmounted actor or award victory after an earlier phase.
