# South Gate to 其利村

This is a historical corridor package. Its exclusions below do not limit the
expanded [索奇亞 + 維諾亞村 goal](../sokia/README.md#required-索奇亞--維諾亞村-goal-scope--2026-11-26):
all surrounding outdoor ground, source-confirmed entrances and complete
map/zone/floor encounter rosters remain required. Corridor checks and existing
boss adaptations alone cannot establish that expanded goal's completion.

The 2026-11-26 continuation also restores Venoa Undersea15592–15594 to the
existing source-group encounter owner (zones5044–5046, group5040). Their old
fixed patrol arrays remain references and no longer duplicate the ambient
groups. Both original species, levels26–27 and equal membership weights are
retained. Final seven-map headless and rendered fixtures each pass234 checks
without script/error lines, including direct fights and native cleanup.
Source frequency/count semantics and the obstructed15004 guard-room camera
remain separate open issues; this is not whole-region or scenery completion.

The locked Explore corridor is city 1000 South Gate → Freyja 100 (south_gate) →
維諾亞洞窟 11000 → 11001 → 11002 → Freyja 100 (south_lakes, the existing
193-cell bear_to_sea road) → 索奇亞海底洞窟 15005 → 15003 → 15004 →
Sokia 300 (the existing 57-cell KILI_ROAD) → 其利村 3200 west gate and reachable
streets. Source city axes are rotated in this renderer; the gate is native
(153,241), not the east gate. Runtime Kili has area kili and falan_floor 0;
3200 is its original map ID. Optional mine, Venoa town, 15592–15594 sea cave,
black-prayer branches and unrelated towns are excluded.

`tools/prepare_south_kili_population.py` prepares source actors and pools from
the preserved native map/graphics archive and SHA-pinned server tables under
`assets/references/crossgate_tina/events/`. Their `references.json` records the
exact upstream commit and hashes. `population.json` retains raw source rows,
source cells, facing records, identities, weights, level bounds and conditions.
Do not hand-edit the generated atlas/data. Regenerate with `--pack` only when
the native encounter bank needs rebuilding; ordinary population changes do not
need to recover the bank again. Original source files are never overwritten.

The 19 source interactions retain 11 existing placement anchors and add eight
missing placements. Existing generic city talk and all dedicated quest/shop/
boss owners stay in charge. Ordinary townspeople use recovered messages; event
actors have one explicit placeholder line. Source direction artwork and native
sprite anchors are preserved. The invisible door at 15004 (7,41) and later-event
哥布林士官 at Freyja (435,266) are recorded as skipped pending corroboration.
No new quest behavior or speculative actor placement is supplied.

`forest_south_kili_population.gd` supplies data to the existing waves and
Explorer NPC owners. The waves owner uses movement-triggered shuffle bags,
source zone priority (higher zorder first), weights, levels and maximum group
size. It replaces ambient posts only inside the recorded outdoor corridor.
Other branch post indices and persistence keys remain intact. Source encounters
have no patrol leash. Placement checks at most 40 local cells per retry, checks
navigation/native reachability and inserts the entire group together. A bounded
native nearby query suppresses overlapping combat; distant branch patrols do
not suppress this corridor. Kili and the city remain safe.

The Venoa bank reuses the five original Habaru actors and adds recovered
惡魔螃蟹 101630. `assets/characters/crossgate/habaru/` remains untouched.
All six use existing native animation timelines, combat, death cleanup and
pooled presentation. Undersea and outdoor creatures reuse their existing banks.
The working Great Bear remains unchanged. Undersea map15003 now retains every
source group, including9033(weight2, forbidden item18403) and9034(weight1,
required item18403). They use the shared source-quest item ledger and separate
shuffle-bag keys when eligibility changes. The old fixed-position boss dispatch
is suppressed on this source-owned map, preventing duplicate boss fights.

Both conditional groups require exactly one level40 Oznik and at least one of
each original level18–20 escort, within the encounter maximum8. The remaining
party size uses the existing uniform bag adaptation, respecting the boss's
one-member cap and each escort's source limits. Source enemy9067/9068 identities
are retained separately even though their appearance is identical. Native boss
combat, body fit and lifecycle are reused. The source9067 escape behavior,
original18404 reward and natural18403 acquisition remain unverified. Original
probability-ramp and count weights also remain qualified; documented relative
group weights are preserved after item eligibility, not claimed to reproduce
the original server's timing. Focused checks and normal-camera evidence belong
under `Sokia Venoa Coverage/Oznik encounters/`. Selection passes12 checks; the
latest headless and rendered runs each pass62 checks across six direct fights
(37actors,375contacts), including maximum8 parties. Headless has zero
script/engine errors; rendered has zero script errors and five Metal fence
diagnostics. Both variants use the same fixed63° gameplay camera. The boss
reads clearly; escort cropping/live-cast overlap and stretched cave-wall paint
limit the visual review. This is not whole-map scenery signoff. Initial invalid
fixtures and the shared camera typed-array failure are retained separately.
Pinned AI records further confirm9067’s escape slot (raw rate20) and Qi BlastLV6,
versus9068’s LV5 without that escape slot. Original condition/rate execution
remains unverified.

`forest_south_kili_art.gd` prepares owned material copies at map setup. Scoped
masks restrict outdoor finishes to the corridor. Warm Venoa rock, cool undersea
rock, quieter ground/cliff variation and restrained Kili facade contrast retain
original chamber geometry, source tiles, roofs, water, stairs, source signs,
landmarks, collisions, doors and native layout. Shared shaders default the finish
off. The existing material update registries still own camera/grid/fog updates.
Entrance and talk labels use smaller scoped presentation to keep the view clear.
Original art and editable masters remain authoritative.

Three stale shortcut overrides in `forest_freyja_dungeons.gd` formerly skipped
both side floors of the Sokia sea cave. Removing them restores the already
present original door rows: 15005 ↔ 15003 ↔ 15004. The original warrior self-gate
on 15004 remains. No route geometry or unrelated connection is redesigned.

Reproduce from the complete project, one Godot script at a time:

```sh
python3 -m unittest tests/forest-shrine/test_south_kili_source.py
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/south_kili_route_review.gd -- --after
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/south_kili_population_test.gd -- --visual
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/kili_street_survey_test.gd -- --visual
/Users/eric/Desktop/Play\ Goemon.command --fixed-fps 60 --script res://tests/forest-shrine/south_kili_continuous_test.gd
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py check
```

Evidence lives in `build/Other Files/Asset Toolkit/South Gate Kili Route/`.
Preserve its Before inventory/camera/source snapshots. Direct loads verify
local art/populations; only the continuous fixture proves the full crossing
sequence. It sets the initial city position once, then uses real movement and
attack input, without debug teleports or invincibility. These focused checks
are not a full-army frame-time measurement or long-session soak. No app export
is part of this pass.

Original route references: [維諾亞](https://cg.skyey.tw/map/ma05.htm),
[其利](https://cg.skyey.tw/map/ma07.htm),
[索奇亞](https://cg.skyey.tw/map/ma002.htm),
[undersea quest](https://cg.skyey.tw/errand/maae03.htm), and
[server encounter field documentation](https://bbs.cgmsv.com/thread-1031-1-1.html).
