# Explore food and chest rewards

Thirty-five unchanged RGBA sprites from the preserved Blue CG original pack. Source
rows, dimensions and pixel/PNG hashes are in `provenance.json`. Rebuild with:

```
python3 tools/recover_crossgate_explore_loot.py '../Magic Power'
```

Regular/black/white closed chests use original rows 15614/15616/15618 (graphic
serials 27893/27895/27897). Food uses bread 14982, roast chicken 15054, bento
15012, hot pot 15076, stew 15011, noodles 15014, fruit salad 14986 and
dumplings 15022. 哈密瓜麵包 uses row15043 (graphic26665), corroborated by
the pinned itemset name 魅惑的哈密瓜面包. Red/blue/green jelly use rows14988/14989/14987. 親子丼 reuses rice-bowl row 15013. Imported alpha edges and
source pixels are preserved. No recoloring or new artwork.

These are local Goemon rules, not recovered Blue CG drop/healing rules:

| Food | Effect |
| --- | --- |
| Bread | Restore 25% maximum HP |
| Roast chicken | Restore 50% maximum HP |
| Bento | Restore 100% maximum HP |
| Hot pot | +30% damage for 10 gameplay minutes |
| Hearty stew | +30% maximum HP for 10 gameplay minutes |
| Noodles | +20% attack speed for 10 gameplay minutes |
| Fruit salad | +20% movement speed for 10 gameplay minutes |
| Dumplings | +20 defense points for 10 gameplay minutes |
| 親子丼 | +5% of starting skill size and hit radius per serving, for the rest of the run |
| 哈密瓜麵包 | Invite all enemies on the current map through the existing native swarm owner |
| Red jelly | +50% general damage for 5 gameplay minutes |
| Blue jelly | +50% to the existing magic-damage stat for 5 gameplay minutes |
| Green jelly | +50% attack speed for 5 gameplay minutes |

Explore-mode native enemy deaths and arena slime deaths have a 20% food chance,
drawing from a shuffle bag of thirteen food tickets and fifty-two misses. Each
65-death bag gives a 20% food rate, with one of each food before refill/reshuffle. They never drop chests. Arena slime return queues
and wave counts retain their existing owner. Within 7.5 world metres (roughly a
normal arena slime's reach), food slides toward the player at 24 m/s and starts a 0.65-second rising curl around the player on reaching the existing
2.4 m pickup distance. Food follows its moving eater and shrinks into them;
the bonus, receipt and eating sound occur at completion. A wall freezes the
airborne serving too; pause/death/menu gates freeze its flight. Area cleanup
cancels unfinished servings. Chest food uses the same flight after pressing F,
with a chest-opening sound at reveal and an eating sound at consumption. The pull checks
3D distance and clear cover each update, stopping outside range or behind walls.
All food is consumed at full HP too; healing never raises HP above its maximum.
A healing pickup at full HP shows the food name and “HP full”. Healing is capped and
cannot revive. Different temporary bonuses coexist, and repeated servings stack additively:
two hot pots give +60% damage, three give +90%; two noodles give +40% attack
speed. Each serving refreshes that food's shared timer to 600 seconds. There
is no stack cap. Every new stew stack adds 30% of unbuffed maximum HP and grants
that added health. Expiry clears all stacks of that food and safely clamps HP
to the restored maximum. Healing-only food restores HP at the end of its pickup flight.
Movement food scales walking, sprinting and the existing prepared flight speed;
it does not change attack-driven lunges, dodges, jump height or controls.
Defense food adds to the existing level/allocated armor points before applying
`100 / (100 + total defense)`, so stacks reduce real incoming damage without
reaching immunity. The Stats panel includes food defense and its live reduction.

Active bonuses appear as the original food icons in the current food HUD dock.
A single serving has a plain icon; repeats show ×2, ×3 and higher counts.
Nine effect icons wrap using the shared HUD's current six-column food dock. Tooltips identify the food,
total bonus and remaining time. The shared HUD owns dock placement; food adds no private HUD layout.
親子丼 has no timer: twenty servings give 2× starting visual dimensions and hit
radius, with unchanged damage, projectile count and explosion count. Run progression
owns its stacks, preserving them across fighter changes, death/respawn and real
walking transitions. Title/new run resets them. Existing Skill Balance size/area
edits remain the starting values; new casts snapshot food growth, including charge
shine and in-flight projectiles. There is no stack cap. Its tooltip says “Rest of
run”. Chest nutrition uses the separate catalog below.

Timers freeze during pause, travel and death, and run through ordinary attacks,
spells and ladders. Bonuses survive area travel and fighter changes, but reset
on title/new run. Player stats keep the existing combat, animation and projectile
owners; food does not change native enemy/ally profiles or saved balance values.

Chests mix run-only nutrition with the existing nine swords/axes documented
in `swords/README.md` and `axes/README.md`. Their reward bag contains four weapon
marbles and one of each of the sixteen foods below. Draw without replacement,
then refill and reshuffle. Capped rewards and pet meals without a selected party
are skipped. Weapon draws still use the separate nine-weapon shuffle bag.
Acquired weapons persist in Equipment; duplicates retain their upgrade rule.

At area entry, up to twelve chests outside or three inside are placed on
reachable, clear navigation cells, at least twelve world metres apart. A fixed
area/run seed gives the same positions across entry points. Regular chests are
90%; black and white are 5% each. Walk within 4 metres and press F to open an
optional chest. All three colors share the same weapon/food reward distribution. Rewards
from weapons are saved before consuming the chest; failed saves keep the same reward ready
for retry. Opened location keys
persist for the run so revisiting an area cannot refill them. 熊弟 dialogue takes
F priority; pet orders elsewhere retain their owner. All three chest sprites render
at 0.06375 world units per source pixel, anchored
to the ground. Chest interaction key hints are hidden.

Dropped food expires after 120 unpaused seconds; scattered chests remain until
opened or leaving the area. Sixty-four shared slots bound active ground loot;
a full pool skips new food drops. Area changes clear ground drops. Twenty-nine prepared
MultiMesh batches share immutable art/materials. Proximity uses only the bounded
loot slots, never an army scan, and bulk pickups coalesce HUD/audio feedback.
No per-kill loading or runtime material creation. No consumable inventory or keys. Chest food applies after its flight; pet mana food raises maximum MP through the existing native growth owner.

Rules/presentation: `scripts/forest/exploration_loot.gd`. Temporary player stat
multipliers/timers: `scripts/player.gd`. Regression and rendered evidence:
`tests/forest-shrine/exploration_loot_test.gd`, run through Play Goemon with
`--script res://tests/forest-shrine/exploration_loot_test.gd` (optionally
`--headless`). Reports/captures: `build/Other Files/Explore Loot/`.

`tests/forest-shrine/food_magnet_test.gd` checks attraction, actual walking,
frame-rate consistency, cover, pause, expiry and all 64 pooled slots. Its
desktop captures and logs are under `build/Other Files/Food Magnet/`.

## Run-only chest food — updated 2026-11-25

These are local Cross Gate gameplay effects using unchanged recovered artwork,
not claims about original-client food rules. Open a chest with F to reveal its food and consume it after the short flight. The dark, ivory-edged receipt names the food, actual bonus
and “Rest of run”. Character bonuses follow the controlled Cross Gate
fighter across character changes. Pet food feeds each selected party member,
including recalled pets, and stays with that pet's stable identity.

| Food | Effect per serving for this run |
| --- | --- |
| Vitality bread | +100 max HP and +1 HP/sec |
| Power steak | +15% of base physical damage |
| Sage soup | +15% of base magic damage |
| Swift sushi | +10% of base attack speed |
| Iron meatballs | +10 defense |
| Ward soup | +10 magic defense |
| Lucky cake | +1 percentage point critical chance |
| Feather parfait | +1 percentage point dodge |
| Duelist fish | +1 percentage point counter chance |
| Focus riceball | +1 Accuracy |
| Growth rice | +1 character level |
| Royal feast | +3 character levels, capped at 99 |
| Pet hearty stew | Selected pets: +30 max HP each |
| Pet power skewers | Selected pets: +5 base attack each, including skills |
| Pet mana broth | Selected pets: +10 max MP each |
| Pet celebration feast | Selected pets: +1 level each, capped at 99 |

Bonuses stack additively with existing allocated ranks. Chance stats retain the
existing 100% cap, pet MP retains its existing +980 limit, and ordinary nutrition
ranks validate to at most 10,000 per stat. Character level meals grant the normal
stat points/card opportunities and preserve partial XP; pet levels retain family
growth and do not create pet points. For now, restarting or starting a new run
resets character/pet levels to one and clears food bonuses, ordinary kill XP,
spent run points, cards and learned run skills.
Regular ground food keeps its existing healing/timed/run-only rules above.

Food rewards update only the current team progression and do not write settings.
Legacy `settings.chest_nutrition` data remains preserved but is ignored for
gameplay. Retained-run travel keeps the same progression object; settings reload
does not replace current food bonuses. Existing balance edits, weapon saves,
pet identities and original artwork remain intact.

Chest audio is `assets/audio/crossgate/cgsys02.wav`; ground-food pickup audio is
`cgsys03.wav`. Both use the existing SFX voice pool and pickup gain/mute/recording
controls. Their PCM is identical to the preserved Blue Cross Gate client; source
paths and hashes are in `assets/audio/crossgate/loot-provenance.json`.

Catalog/save validation: `scripts/forest/chest_food.gd`. Existing team progression
owns stat calculations, while the native pet growth setter updates live bodies.
All sixteen icons preload once and reuse the existing loot-slot update and
MultiMesh presentation during consumption, then appear in the shared receipt.
No per-serving nodes, tweens, materials, targeting owners or runtime loads are created. Source rows and pixel hashes are in `provenance.json`.

Focused verification: `tests/forest-shrine/chest_nutrition_test.gd`. Evidence and
the food catalog preview are under
`build/Other Files/Asset Toolkit/Chest Nutrition/`.

## Melon invitation, jelly buffs and food flight — 2026-11-27

Four kills no longer start map-wide pursuit. Consuming 哈密瓜麵包 activates the
existing per-map swarm flag once; map/new-run resets, native reachability,
taunts/retaliation and slower swarm respawn intervals retain their owners.
The effect includes later arrivals on that map. Existing local kill-based
awareness remains unchanged.

Blue jelly boosts the live magic-damage stat, which is added to spell damage;
it leaves the spell's authored base and physical damage unchanged. Red and green
add their percentages to existing damage/attack-speed food percentages. Repeated
servings add another50% and refresh that color to300seconds. The three timers
expire independently; ordinary ten-minute meals retain600seconds. Shared attack
speed caps, combat clocks and saved balance values remain unchanged.

The old chest sage/ward meals now display original cream-soup15008 and
soup15007, with their existing+15%magic damage/+10magic defense. Pet mana broth
uses15066, preserving+10party-petMP and making15043unique to the invitation
among active foods. Historical sage-jelly/ward-jelly/pet-melon IDs and assets are
preserved for saved-data compatibility. The three colored jelly icons now have
the explicit temporary drop effects above; no old chest meal uses jelly art.

Chest eligibility is checked again at the end of flight. If a pet party or cap
changes, the same unopened chest returns to its original position for retry;
F cannot duplicate a flying reward. Weapon rewards retain their saved route.

Focused checks: food_magnet_test.gd, chest_nutrition_test.gd,
map_swarm_test.gd and exploration_loot_test.gd through Play Goemon, using
-- --crossgate-pet-test for their arena/native fixtures just as normal play does.
Current logs and source-art contact sheet are in
build/Other Files/Asset Toolkit/Melon Bread/. Visual acceptance and technical
results are recorded separately in that folder's report.


Jello glow (approved 2026-11-27): each active color lights a thin border along
the character's actual body/weapon silhouette and the existing floating fairy
lights. Multiple active colors cycle every1.5seconds; individual expiry removes
only its color. Jello has no cylinder, ground shape or colored point-light pool.
Original ground-shadow/effect pixels stay uncolored. Golden Surge retains its
original appearance. Character changes/respawn retain active food colors;
pause/travel freeze animation and food cleanup clears the border/lights.

Approved references: assets/references/jello_glow/. Future glow work follows this
style and the image-led iteration workflow recorded in AGENTS.md. Current tests,
source hashes and captures: build/Other Files/Asset Toolkit/Jello Glow/Shape Border/.
