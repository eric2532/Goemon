# Pete, Grace, Rei and Cedi

Stable character IDs are 44 Pete, 45 Grace, 46 Rei and 47 Cedi. Their existing
skin selection, equipment, shared skills, balance and sound settings remain
independent. Original archive skin IDs remain the selection keys.

The recovered inventory is Pete 17, Grace 11 (including the user-confirmed
106234), Rei 14 and Cedi 11. Older Rei appearances and all reviewed color/costume
families are retained. Grace 106234 uses nonconsecutive weapon rows; 106238 is
another character and must not be inferred as her staff. Cedi 111619 keeps its
bare-handed purple-effect attack and has no invented sibling weapon set.

Rebuild with `python3 tools/recover_crossgate_selected_cast.py '../Magic Power'`,
then `python3 tools/prepare_crossgate_weapons.py '../Magic Power'`. The shared
atlas packer and source decoder preserve every original frame and origin.
Eight gameplay actions in eight facings use the original source clocks and
contact/sound markers. No runtime retargeting, new combat owner, new army
simulation or per-character renderer is used. Native weapon equipment reuses
its existing source atlas preparer. The source archives are read only.

`crossgate_cast_skins.gd` is generated metadata. Per-skin portrait origins and
standing heights keep costume changes local. Atlas materials and sound streams
are prepared when an appearance/weapon is selected; combat only advances the
existing prepared state. Footsteps and landing reuse Goemon's prepared shared
samples. Current new-character HUD heads retain their recovered sprite pixels
and palette; existing painted heads and dialogue artwork remain unchanged.

Emilia keeps all eighteen verified Emilia/Puck and Ayame appearances. Her CH1
blue/silver records must remain pinned because Joy EX reuses those IDs for
other characters. The new archive scan rejected the Pippin false matches; see
`emilia-inventory.json` in the report folder. Existing fitted staff adaptations
and Uru's combat timing remain intact.

Focused checks use `tests/forest-shrine/selected_crossgate_cast_test.gd` and
`crossgate_emilia_test.gd` through Play Goemon. Source/frame checks, the archive
scan, captures and logs live under `build/Other Files/Asset Toolkit/Pete Grace
Rei Cedi/`. These are source additions; no app export is required.

Additional pet/effect artwork is exposed as Special skins through the shared
catalog: Rei now has 15 choices and Cedi 14. The original base recovery above
still prepares 53 appearances; see `../special-skins-README.md` for the extra
source records, fixed-weapon rules and preparation order.
