# Cross Gate skill redesign rules

Status: The agreed first pass is implemented for all skills below. 乾坤 was
reviewed first; the remaining skills use the same run-level and modifier path.
Skills without agreed new numbers retain their existing behavior.

EX audit, 2026-11-16: the four ordinary size tiers below do not exhaust the
original artwork. Fresh source-instruction checks identify a separate EX branch
at internal skill values >=12. The operator's
[2015-07-11 announcement](https://www.bluecg.net/forum.php?mod=viewthread&tid=72802)
documents BlueCG displayed Lv.11 battle skills using official Lv.15 effects.
The [2017-04-15 announcement](https://www.bluecg.net/forum.php?mod=viewthread&tid=190414)
adds Lv.11 Two Birds/Swift effects and moves fixed-target Combo to Lv.12.
These public levels must not be inferred by adding one to the internal field.
Cross Gate uses the original EX art at run level 30. The four ordinary bands
cover levels 1–9, 10–18, 19–27 and 28–29. Exact current live packet encoding
is still unmeasured. See the confirmed resource table in the Shin asset guide
and `build/Other Files/Asset Toolkit/EX Rank Mapping/native-probes.json`.

明鏡止水 is also a shared Equipment → Skills choice (`shin/meditation`) for all
Cross Gate fighters and supported weapons. It keeps the original native owner:
heal once at cast completion for 5% of current missing HP at level 1, adding one
percentage point per level to 34% at level 30, with a ten-second cooldown.
Interruption cancels the heal and retains the cooldown;
duplicate slots share that timer. Reuse the receiving model's cast clip when
available, otherwise its standing pose with the original seven-frame effect.
Use the four original meditation drawings at one world size per source pixel:
110183 (original ranks 1–3) at our levels 1–9; 110182 (4–6) at 10–18;
110181 (7–9) at 19–27; 110180 (10–11, large with gold sparkles) at 28–29;
and EX 111017 at 30.
There is no additional percentage enlargement. Preserve source pixels/frame
order, origins, release markers and original cast/heal sounds. These are the
meditation drawings, separate from physical charge shines. Casts snapshot
their level and item bonuses; the missing-health
amount is read when healing resolves. Existing shared upgrade points, family
levels, modifiers and fresh-run reset apply. No mana cost was added.

## Implemented first pass

### Full original-art re-audit — 2026-11-16

All recovered four-tier effects now share levels 1–9 / 10–18 / 19–27 / 28–30.
The audit found that elemental impacts still skipped original ranks 4–6 and
Recovery arrivals used different boundaries from their casts. Both are corrected.
Casting shines, all Fire/Ice/Wind/Meteor target variants, meditation and Recovery
cast/arrival artwork now select the matching original rank group. Damage, counts,
cooldowns, release contacts and the existing impact-size/area rules are preserved.

The source check covers 132 rank selections across twelve recovered tables and
52 runtime PNG hashes. Original physical middle-tier recovery comes from the
earlier intact client; this remains archival evidence, not fresh live parity.
Ordinary Qi uses 110016; the later EX audit confirms a separate 111055
projectile, correcting the earlier single-sheet conclusion. Native EX selector
conditions and the operator's displayed-level policy are now documented; a live
server packet comparison remains absent. Existing specialized impacts,
fixed-rank Spirit, arrows, shadows and summons retain their current source art
in this research-only pass. Common casting shines still use the
four original tiers wherever those skills have a shine.

Full mappings and retained single-sheet/unverified cases are recorded in
`build/Other Files/Asset Toolkit/All Cross Gate Art Tiers/source-audit.json`.

| Skill | Level 1 | Level 30 |
| --- | --- | --- |
| 乾坤 | 1.1× per native contact | 4.0× per native contact |
| 連擊 | 3 hits × 0.8× | 17 hits × 2.3× |
| Fire / Wind / Ice / Meteor | 100 total per target, 1 target, Small | 3,000 total per target, 7 targets, Large |
| 暗殺 | 25% instant-kill chance | 100% on eligible targets |
| 陽炎 | 25% dodge chance | 99% dodge chance |
| 一石二鳥 | 1.1× impact, 2.1× follow-up | 4.0× impact, 5.0× follow-up |
| 反擊 | 1 hit × 1.5× | 7 hits × 7.3× |
| Maze 分身 | 3 copies, each 85% caster damage | 9 copies, each 230% |
| Archer Shadow | 1 shadow, 100% caster damage | 7 shadows, each 129% |
| 亂射 | 3 arrows, each 85% base damage | 32 arrows, each 85% |
| 諸刃 | 1.6×, −10% defense for 10 seconds | 7.4×, −39% defense for 10 seconds |
| 氣功蛋 | 1 blast × 1.5× | 16 blasts × 7.3×, +30 critical-chance points |
| 追月 | 3 waves × 1.4× | 10 waves × 5.75× |
| 恢復魔法 | 20% current missing HP | 49% current missing HP |
| 明鏡止水 | 5% current missing HP, original Small | 34% current missing HP, original Large + gold sparkles |

These are level bases before existing tuning, stats, critical hits, food and
upgrades. 精神衝擊波 and Fire / Wind / Ice / Meteor scale with the separate
Magic power stat; Attack ranks apply to physical attacks and skills, including
氣功蛋 and 追月. Each Magic power point adds 15% of baseline magic damage,
matching the initial Attack point value. The initial 反擊 count of one is the first-pass assumption. All listed
skills start at level 1, cap their base level at 30, share progress across Cross
Gate fighters/skins/native and equipped versions, and reset on a fresh run.
Changing fighter or traveling with the retained run preserves levels.

Existing cooldowns, source animations, weapon requirements, cover, boss
exclusions and summon lifetime/health/replacement remain unless a section below
explicitly changes them. No new resource cost or unlock system was added.
Normal attacks start at 50 damage per contact for every Cross Gate fighter and
weapon. Skill formulas retain their separate reference damage of 250 for the
melee/bow/throwing roster and 100 for staff contacts; caster bonuses and the
ticket's saved skill/chain multipliers apply once. Existing combo and counter
streak bonuses remain separate.

Settings → Skill Balance supplies a manual run level and extra-count control.
Earn one shared point per team level. Press **I → Skills** to see six numbered
slots matching your current 1–6 skill bar. Use a slot’s **+** button to spend
**one point for +1 skill level**, up to 30. The same points can instead buy
character stats. Hover over a button for current and next-level base values.
Empty slots and skills without defined upgrades remain visible and disabled.
Only currently equipped/native skills accept points; switching weapons or
loadouts preserves learned family levels. The panel rejects zero-point/capped
or stale purchases and pauses play. Existing attacks retain snapshots.
Additional item types and unlisted progression remain deferred; the first
wearer-specific Qi cosmetics page is described below. 諸刃 now
shows its active defense penalty and remaining time beneath the character.

### Original casting shine tiers — confirmed 2026-11-13

The user chose the actual four original drawings, replacing the earlier
50/75/100/125% scaling of the largest sheet:

| Levels | Physical shine | Elemental shine | Recovery cast |
| --- | --- | --- | --- |
| 1–9 | 110103 | 110055 | 110084 |
| 10–18 | 110102 | 110054 | 110083 |
| 19–27 | 110101 | 110053 | 110082 |
| 28–29 | 110100 | 110052 | 110081 |
| 30 | 111016 | 111001 | 111014 |

Each family keeps a consistent world size per source pixel. The different
artwork and original dimensions supply progression; there is no extra level
size multiplier on casting shines. Source origins keep physical rays centered
on the caster, and elemental flames keep their foot baseline. Food, item and
saved size bonuses still multiply the selected artwork. Casts retain their
level and bonus snapshot. Original sheets load during setup and are reused.

This applies to physical charges (including native/shared versions, Qi, Moon,
assassination and pet charges), elemental casts and recovery windup. Impact and
projectile size, hit areas, damage and counts keep their rules. Elemental target
artwork and Recovery arrival circles now use all four original source tiers
at 1–9 / 10–18 / 19–27 / 28–29. At level 30 Fire uses 111008–111010, Ice
uses 111005, Wind uses 111011, Meteor uses 111002–111004 and Recovery uses
111019 on arrival. The ordinary fourth band still supplies the combat contact
volumes and damage clock. EX cast and impact art uses the existing cast and
projectile pools.

Source: `../Magic Power/tools/build_humanoid_spell_assets.py`, the preserved
`humanoid-spells/manifest.json` and physical `chargeByRank` evidence. Source
ranks 1–3 / 4–6 / 7–9 / 10 map to our four bands. Physical ranks 4–6 are explicitly
marked as recovered from an earlier client; this is not a fresh live-client
verification. The recovery script copies source PNGs byte-for-byte and reuses
already identical sheets, including the existing 110100 charge PNG.
Original previews: `build/Other Files/Skill Levels/Shine Tiers/Source/`.
Current in-game previews: `build/Other Files/Skill Levels/Original Shine Tiers/`.

### Modifier contract

Use `SkillBalance.set_level(hero, skill_id, level)` and
`SkillBalance.set_modifier(hero, skill_id, source_id, values)` in existing item
or upgrade handlers. Reapplying the same source replaces it; `{}` removes it.
Count bonuses add to level counts. Damage/size/area/speed bonuses add together as
fractions, then multiply the saved value and applicable level size. Stacked
penalties cannot make a multiplier negative. Chance/healing bonuses are additive
fractions and clamp to 0–1; critical bonuses are percentage points, clamped with
caster chance to 0–100. Count capacity is bounded to 1–128 and prepared on change.
These bounds are implementation limits, not level-30 base caps.

Example: level-30 Fire plus `{"count": 3}` creates ten selected Large effects
per native release, each selected enemy sharing one 3,000-damage cast budget
across releases. Removing that source restores seven. A Qi item can set
`{"qi_color": Color.RED}` without creating a new skill; existing Gold Qi saves
remain compatible. Released casts retain snapshots. Copies snapshot caster
damage and their summon multiplier on summon; Archer Shadows read the caster's
current 亂射 level and tuning at the start of every new volley.


## Confirmed direction

- Presentation correction, 2026-11-14: Fire, Ice, Wind and Meteor use each
  fighter's casting motion and a charge centered at the feet. Keep the current
  native release contacts and damage unchanged. Uru's consecutive ice bursts
  are a possible future upgrade effect; no upgrade rule is defined or added yet.

- Redesign all Cross Gate skills so they have levels and explicit rules.
- Define and discuss the rules before creating or changing skills.
- Keep this file as the working rulebook; record decisions here as we agree on them.
- Skill levels start fresh on a new run for now; they are not permanent learned progress.
- Earn one shared stat/skill point per team level; one point buys one skill level.
  Confirmed by the user after the initial deferral on 2026-11-13.
- Impact/projectile size growth remains +1% of starting size per additional
  skill level: level 1 is 1× and level 30 is 1.29×. Casting shines instead use
  the confirmed four tiers above. Elemental/recovery artwork and fixed initial
  impacts of 一石二鳥/諸刃 retain their specific rules.

## Scope

The current Cross Gate roster is Kaz, Uru, Maze, Shin, Shin Special, Saizo, Bog,
Emilia and Lancelot. Cover their native skills, weapon-dependent skills and
equipped shared skills. Include Mirror Image because Cross Gate fighters use it.
Preserve older characters and their assets; this redesign does not request a
legacy-character rebalance.

Use the following inventory to avoid leaving out less obvious skills. These are
design families, not a decision to merge their current implementations or levels.

| Family | Skills and variants to define |
| --- | --- |
| Empowered attacks | 乾坤, 諸刃, 一石二鳥 |
| Combos and retaliation | 連擊, 反擊 |
| Ranged magic | 追月, 氣功蛋 (including gold/color variants), Fire, Ice, Wind, Meteor, Spirit |
| Recovery | 明鏡止水, Regrowth / 再生術 |
| Ninja techniques | 暗殺, 刀刃亂舞, 陽炎 |
| Archery | 亂射, 亂射影分身 |
| Summons and copies | 召喚穴熊, equipped Mirror Image |

Pet-granted skills have separate levels per pet and skill family (revised user
direction, 2026-11-13). I → Pets spends the existing shared points: one point buys
one level for the chosen pet, up to 30. Levels start at 1, persist through recall
and loadout changes, and reset with a new run. They do not inherit character
levels. Existing pet equipment and native casts remain the owners. Basic attacks,
shared guard and movement actions remain an open scope decision. Skills without
level rules stay unchanged.

## Existing behavior to account for

These are current systems, not decisions about the new level system:

- Team progression already has a run-based level, automatic stats and allocated
  stat points. Optional upgrade cards also exist.
- Skill balance settings already adjust supported damage, size, hit area,
  projectile speed and counts. Supported controls differ by skill.
- 親子丼 adds 5% of starting supported skill dimensions and hit radius per serving
  for the run. It does not directly increase damage or counts.
- Several spell names currently say “Lv. 11”. Those labels alone do not define
  a learned skill-level progression system.
- Native and borrowed versions can have different behavior, and loadouts can
  differ by fighter, skin or weapon. Matching names do not prove identical skills.

The redesign must explicitly decide how these systems interact. Do not silently
replace food growth, spend existing stat points, change saved tuning or erase saves.

## Confirmed item and special upgrade modifiers

User direction, 2026-11-13: build the skills so items and special upgrades can
modify their rules beyond the values supplied by skill level. Keep the level's
base values separate from these modifiers. A level-30 base value is not itself
a cap on the final target/effect count.

For count increases:

`effective target/effect count = count from skill level + item bonuses + special upgrade bonuses`

For example, level-30 Fire has seven Large Fire effects. A +3 target/effect bonus
produces **ten Large Fire effects** at the same skill level. Each selected target
still has the level's **3,000 total base damage budget per cast**, before damage
modifiers. Adding targets does not divide that budget among targets, change the
effect tier or make individual effects smaller. A count-only bonus does not also
increase per-target damage. Removing it restores the count supplied by the
remaining bonuses and skill level.

Keep relevant skill values available to item/upgrade modifiers through the shared
skill rules, rather than embedding the final values in individual attack scripts.
Define actual items, bonuses and equipment lifetimes separately. The first-pass
stacking and chance-cap contract is documented above.

Implementation should extend the existing SkillBalance effective-value and attack
ticket snapshot path. It already adds count bonuses and applies supported stat
modifiers. Reuse that aggregation for items and special upgrades; prepare any
additional projectile capacity when equipment or upgrades change. Released casts
retain their snapshots. This is an implementation constraint, not a new item system.

## Original design checklist

The implementation choices above and the confirmed sections below now resolve
this initial checklist for the first pass. It remains a reference for future tuning.

1. **Give each skill an explicit level.** Distinguish skill level from team level,
   character stats and temporary buffs. Decide whether an unlearned level 0 exists.
2. **Define every level's effect.** Each skill lists exactly what changes:
   damage, healing, duration, targets, projectiles, area, cooldown or cost.
   A level does not automatically increase all of them.
3. **Keep a clear tradeoff.** Each skill has a purpose and stated limits, such as
   range, commitment, cooldown, resource cost or summon capacity. Do not add a new
   resource system unless we choose one.
4. **State damage ownership.** Specify damage per cast, contact, projectile or
   pulse, and the maximum repeat hits on one target. Additional animation contacts
   must not accidentally multiply a stated total-damage budget.
5. **State targeting and failure rules.** Define eligible targets, cover,
   reachability, boss exceptions, cancellation, misses, and when cost/cooldown begins.
6. **Define stacking once.** Document how skill level combines with character
   stats, saved balance, food, cards, critical hits and other buffs. Include a worked
   example before tuning numbers.
7. **Make the result readable.** Show current level and the next level's change.
   Visual effects should communicate the actual gameplay area and confirmed hits.
8. **Define shared ownership.** Decide whether native and borrowed versions,
   weapon variants, skins and different fighters share learned progress. Equipping
   or switching a skill must not accidentally duplicate or reset progress.

## Initial questions and current status

| Decision | Choices to discuss | Status |
| --- | --- | --- |
| How levels are earned | Existing shared point pool; one point buys one skill level | Confirmed and implemented |
| Lifetime | Start fresh each new run for now | Confirmed by user, 2026-11-13 |
| Level range | 1–30 for the agreed skills; no level-0 state | Implemented |
| Progress owner | Shared skill family across Cross Gate fighters, skins and native/equipped versions | First-pass implementation |
| Unlocks and access | Existing access and weapon requirements | Preserved |
| Costs and limits | Existing cooldowns and limits except explicitly redesigned counts | Preserved |
| Existing bonuses | Existing bonuses retained; level bases precede item modifiers | Implemented above |
| Pet-granted skills | Independent per-pet levels, upgraded in I → Pets using shared points | Revised by user, 2026-11-13 |
| Extra scope | Basic attacks, guard and movement | Undecided |

Point spending, fresh-run reset and retained-run travel are implemented;
no permanent skill progress is written to saved preferences. Existing saved
balance adjustments remain independent of run levels.

## 乾坤 first pass

### Before redesign

Source reviewed before implementation on 2026-11-13. These were source defaults, before saved tuning,
character bonuses, food, critical hits and hit-chain bonuses. They are not fresh
gameplay measurements. Older area-blast descriptions in the performance history
are superseded by the native-contact implementation.

| Property | Current behavior |
| --- | --- |
| Damage | Fixed 5,000 base budget per completed attack against a target receiving all contacts; not a multiplier of its ordinary attack damage |
| Contact allocation | Divide 5,000 across native attack contacts: Kaz/Bog 2 × 2,500; regular Shin/Lancelot 1 × 5,000; Uru/Emilia staff 5 × 1,000. Kunai divides its contact budget across thrown daggers |
| Starting shine | 10.8 m maximum visual dimension, centred at the caster's chest |
| Charge | 9 frames × 0.05 s = 0.45 s, then the receiving fighter's normal attack animation |
| Impact picture | 10.8 m maximum visual dimension; 9 frames × 0.1 s = 0.9 s for 乾坤 art |
| Impact placement | Each confirmed enemy hit emits feedback at that victim's body centre, including lethal hits |
| Damage area | Existing weapon/arrow/kunai contact checks; the impact picture adds no damaging explosion circle |
| Range and targets | Receiving weapon/projectile rules; melee can contact multiple enemies, once per enemy per native contact; later contacts can hit again if the target survives |
| Cover and misses | Solid cover blocks hits; misses and walls do not produce enemy impact explosions |
| Cooldown | 5 seconds, starts when the cast begins |
| Cast requirements | Alive, grounded, not dodging, not already attacking, cooldown ready; this cast entry rejects AI-controlled use |
| Resource cost | No mana or other resource charge in the current cast entry |
| Existing modifiers | Character damage bonuses, skill damage tuning, hit-chain bonuses and critical hits can change final damage; critical hits are 2× |
| Size modifiers | Saved visual-size and hit-area controls are independent; 親子丼 multiplies supported size/area by 1 + 0.05 × servings |

Actual release timing and physical reach depend on the selected fighter, weapon,
skin and attack-speed modifiers. “Regular size” here refers to the unmodified
10.8 m visual baseline, not a 10.8 m damaging circle. 諸刃 uses a related owner
but is a separate skill; this level decision does not redesign it.

### Confirmed level decisions

User direction, 2026-11-13:

- First pass covers levels 1 through 30.
- Level 1 starting shine: original smallest sheet 110103 at the shared source-pixel scale.
- Level 1 impact picture: regular size, 1.0× its visual baseline.
- Level 1 damage: normal/base attack damage +10%, or 1.1× normal damage.
- Each subsequent level adds 0.1× normal damage, not 10% of the preceding level.
- Level 30 is **4.0× normal damage**, explicitly confirmed after correcting the
  initial 3.0× arithmetic. It is +300% bonus, or 400% total normal damage.
- Skill levels start fresh each new run; spend the shared stat/skill points to level them.

For level L from 1 to 30:

`damage multiplier = 1 + 0.1 × L`

| Level | Normal damage multiplier | Bonus over normal |
| --- | --- | --- |
| 1 | 1.1× | +10% |
| 2 | 1.2× | +20% |
| 5 | 1.5× | +50% |
| 10 | 2.0× | +100% |
| 20 | 3.0× | +200% |
| 30 | 4.0× | +300% |

### Implemented behavior

Every native contact uses ordinary contact damage × the level multiplier, then
the existing caster/ticket modifiers. Impact and supported hit area grow
by 1% of starting size per level after 1; casting shines use the four tiers above. Native contact counts stay intact;
a missed attack produces no enemy explosion or cosmetic splash damage.

## 連擊 first pass

### Level pattern

User direction, 2026-11-13: maximum level 30. The first four levels are
0.8× / 3 hits, 0.9× / 3 hits, 0.9× / 4 hits and 1.0× / 4 hits.
Attack size grows by 1% per level after 1; casting shines use the four tiers above.

The pattern inferred from those four levels alternates the upgrade:

- Start at level 1 with 0.8× regular damage and 3 hits.
- Every even level adds 0.1× regular damage per hit.
- Every odd level from level 3 adds one hit, retaining the previous damage multiplier.
- Damage increments add to the regular-damage reference; they do not compound.

For level L from 1 to 30:

`per-hit damage multiplier = 0.8 + 0.1 × floor(L / 2)`

`hit count = 3 + floor((L - 1) / 2)`

| Level | Regular damage per hit | Hits |
| --- | --- | --- |
| 1 | 0.8× | 3 |
| 2 | 0.9× | 3 |
| 3 | 0.9× | 4 |
| 4 | 1.0× | 4 |
| 5 | 1.0× | 5 |
| 6 | 1.1× | 5 |
| 10 | 1.3× | 7 |
| 20 | 1.8× | 12 |
| 29 | 2.2× | 17 |
| 30 | 2.3× | 17 |

### Implemented behavior

The hit limit counts native contacts, not whole hops. One living enemy can receive
successive hits; an unavailable target uses the existing retarget/cancel rules.
Damage is per hit, with the existing consecutive-cast streak retained separately.
The source charge, hop/contact timing, protection and cooldown remain;
Impact and hit area grow by 1% per level after 1. Casting shines use four
ordinary tiers and EX at level 30.

## Fire Wind Ice and Meteor first pass

### Confirmed shared direction

User direction, 2026-11-13: Fire, Wind, Ice and Meteor use the same damage,
effect-tier and target-growth rules, through level 30.

- Level 1 total base spell damage is 100 per target per cast.
- Each additional level adds 100: `total base damage per target per cast = 100 × level`.
- Split that total across the cast's hits/pulses and native animation releases;
  additional contacts do not multiply the total budget for a target.
- Target art and casting shines match at levels 1–9 / 10–18 / 19–27 / 28–29,
  with EX art at level 30.
- Start with one target. Add one target at levels 5, 10, 15, 20, 25 and 30,
  reaching seven targets at level 30.
- Keep every original tier, including the original ranks 4–6 artwork; source pixel dimensions supply size differences.
- Spend shared stat/skill points to level skills; levels reset on a new run.

Cooldown, range, cover and critical behavior retain their existing owners.
Effect and physical-area sizes follow the selected original sheet relative to
the existing largest tier; there is no additional level growth within a tier.

### Original effect inventory

Read-only research of the preserved Magic Power original-client recovery found
four mapped visual tiers, shared by normal, strong and super elemental spell
families. Original levels 1–3, 4–6, 7–9 and 10–11 select successively larger target
effects. These source level bands are separate from the new Goemon level bands.
Meteor is the source `h_earth` family. Before this redesign, Goemon used
only the original level-10/11 target sheets and the largest cast shine.

| Original level band | Fire | Ice | Wind | Meteor |
| --- | --- | --- | --- | --- |
| 1–3 | 110149, 110150, 110151 | 110029 | 110047 | 110041, 110042, 110043 |
| 4–6 | 110146, 110147, 110148 | 110026 | 110046 | 110038, 110039, 110040 |
| 7–9 | 110143, 110144, 110145 | 110023 | 110045 | 110035, 110036, 110037 |
| 10–11 | 110140, 110141, 110142 | 110020 | 110044 | 110032, 110033, 110034 |

The corresponding four cast shines are 110055, 110054, 110053 and 110052.
Shared support includes trails 110006/110007 and impacts 110001/110002/110003.
Each Fire tier's three target IDs contain identical PNG bytes. Meteor's three
variants in each tier contain distinct artwork; preserve those variants.

The inventory covers **41 mapped effect records, 33 distinct PNG sheets**, plus
associated sound references. All 41 PNG hashes and associated sound hashes were
checked against the preserved manifest. All 132 normal/strong/super elemental
level mappings agree with the preserved native resource-selection probes.
This verifies the recovered asset inventory, not live original-client/server
playback. Source binaries were not re-decoded during this review.

Evidence is under `build/Other Files/Asset Toolkit/Cross Gate Element Effects/`:

- [Four source tiers at the same pixel scale](../build/Other%20Files/Asset%20Toolkit/Cross%20Gate%20Element%20Effects/original-tiers.png)
- [Animated source sheets](../build/Other%20Files/Asset%20Toolkit/Cross%20Gate%20Element%20Effects/original-tiers.gif)
- [All 33 distinct effect sheets](../build/Other%20Files/Asset%20Toolkit/Cross%20Gate%20Element%20Effects/all-distinct-effects.png)
- [Complete IDs, source paths, hashes, timing and sound inventory](../build/Other%20Files/Asset%20Toolkit/Cross%20Gate%20Element%20Effects/inventory.json)

These previews show original sprite-sheet artwork at a common pixel scale, not
reconstructed game movement, sound, screen glow or complete spell sequences.

Preserved source: `../Magic Power/godot/assets/humanoid-spells/manifest.json`;
resource-selection evidence:
`../Magic Power/research/spell-animations-20261031/native-visual-probes.json`.

The 2026-11-16 audit supersedes the earlier three-band mapping:

| New Goemon level band | Size | Original effect tier | Corresponding cast shine |
| --- | --- | --- | --- |
| 1–9 | Small | Original levels 1–3 | 110055 |
| 10–18 | Medium | Original levels 4–6 | 110054 |
| 19–27 | Large | Original levels 7–9 | 110053 |
| 28–29 | Highest ordinary tier | Original levels 10–11 | 110052 |
| 30 | EX | Original EX branch | 111001 |

Every original tier is selected. Extra sparkle/shine only appears where it exists in the source artwork; do not synthesize it for other sheets.

### Confirmed progression

For levels 1 through 30:

`total base damage per target per cast = 100 × level`

`target limit = 1 + floor(level / 5)`

`effect tier = min(3, floor((level - 1) / 9))`

| Level | Total base damage per target per cast | Effect tier | Target limit |
| --- | --- | --- | --- |
| 1 | 100 | Small | 1 |
| 4 | 400 | Small | 1 |
| 5 | 500 | Small | 2 |
| 10 | 1,000 | Medium | 3 |
| 11 | 1,100 | Medium | 3 |
| 15 | 1,500 | Medium | 4 |
| 19 | 1,900 | Large | 4 |
| 20 | 2,000 | Large | 5 |
| 25 | 2,500 | Large | 6 |
| 30 | 3,000 | Highest original tier | 7 |

Current Fire has one damaging pulse, Ice three, Wind four and Meteor two. For
example, at level 12, each target has a 1,200 base damage budget. With one native
release, Fire deals 1 × 1,200, Ice 3 × 400, Wind 4 × 300 and Meteor 2 × 600.
If the fighter releases the spell multiple times in its normal attack, divide
the same budget across those releases too. This is the base budget before other
damage modifiers; missed or cancelled hits need not deliver the whole budget.

The first release selects nearby eligible targets up to the effective limit.
Later native releases retain that set, dropping unavailable targets. Pulses can
only damage selected targets; overlap cannot exceed any target's total budget.
Missed/cancelled releases may deliver less. Local queries and per-pulse ledgers
remain in the existing projectile owner.

Original tier sheets are now copied losslessly by tools/recover_crossgate_skill_tiers.py
and reused by the existing pooled elemental renderer.

## 追月 first pass

User direction, 2026-11-13: level 1 releases three waves and deals 1.4× base
attack damage. Each additional level adds 0.15× base attack damage, and every
four levels adds one wave. Use the shared first-pass range of levels 1 through 30.

Interpret damage as per wave, consistent with the 氣功蛋 per-projectile rule.
The extra-wave thresholds are levels 4, 8, 12, 16, 20, 24 and 28, following
the established count-threshold convention.

`waves per cast = 3 + floor(level / 4)`

`damage per wave = base attack damage × (1.4 + 0.15 × (level - 1))`

| Level | Waves per cast | Base attack damage per wave |
| --- | --- | --- |
| 1 | 3 | 1.40× |
| 4 | 4 | 1.85× |
| 8 | 5 | 2.45× |
| 10 | 5 | 2.75× |
| 20 | 8 | 4.25× |
| 28 | 10 | 5.45× |
| 30 | 10 | 5.75× |

At level 30, the base skill releases ten waves, each dealing 5.75× base attack
damage. Damage increments are additive, not compounded. Item/special-upgrade
modifiers can change these level-based values separately.

The cast quota is divided across native attack contacts without multiplying it.
Existing projectile targeting, repeat-hit protection, cooldown and range remain.
Size and hit area use the shared 1% growth. 氣功蛋 critical milestones do not
transfer to this skill.

The existing projectile controller applies the per-cast wave count across native contacts.


## 恢復魔法 first pass

User direction, 2026-11-13: cast on yourself and restore a fraction of your
current missing health. Level 1 restores 20%; each additional level adds **one
percentage point**, corrected down from the initially proposed two points.

`healing amount = current missing HP × (0.20 + 0.01 × (level - 1))`

The level-30 heal restores 49% of current missing HP. Calculate missing health
when the heal actually resolves, cap healing at maximum HP and do not revive a
dead caster. The first implementation reuses the existing cast/arrival timing
and ten-second cooldown, then heals once rather than arming the old six heals.

| Level | Current missing HP restored | Original effect band |
| --- | --- | --- |
| 1 | 20% | Small |
| 10 | 29% | Medium |
| 11 | 30% | Medium |
| 19 | 38% | Big |
| 20 | 39% | Big |
| 25 | 44% | Big |
| 26 | 45% | Big |
| 30 | 49% | EX |

The recovery circles use the same tier boundaries as their cast shines.

| New level band | Original target sheet | Original cast sheet |
| --- | --- | --- |
| 1–9 Small | 110179 | 110084 |
| 10–18 Medium | 110178 | 110083 |
| 19–27 Big | 110177 | 110082 |
| 28–29 Big with shine | 110176 | 110081 |
| 30 EX | 111019 | 111014 |

The largest original circle already contains its painted shine/streaks. It
does not require the separate 110184 healing-hoop overlay. All original recovery
and healing assets remain preserved. The runtime retains the existing
`uru/recovery` ID for loadout compatibility and displays 恢復魔法.

Original comparison and the four-band preview:
`build/Other Files/Asset Toolkit/Cross Gate Recovery Effects/`.
The inventory verifies thirteen source PNG hashes and 66 recovered target/overlay
rank mappings, including related healing hoops for reference. Those recovered
support mappings use the earlier research's explicit tier-initializer repair;
the preview is not a new live original-client/server verification.

Items/special upgrades can modify healing separately through the shared rule.
New costs, critical healing, extra recipients and heal-over-time behavior are
not introduced by this rule.


## 氣功蛋 first pass

User direction, 2026-11-13: level 1 fires one Qi blast dealing 1.5× base attack
damage. Each additional level adds 0.2× base damage per blast. Every two levels
adds one blast. Levels 10, 20 and 30 each add 10 percentage points of critical
chance to this skill.

Use the shared first-pass range of levels 1 through 30. Interpret the extra-blast
thresholds as levels 2, 4, 6 and so on through 30, consistent with the other
count-threshold rules.

`blasts per cast = 1 + floor(level / 2)`

`damage per blast = base attack damage × (1.5 + 0.2 × (level - 1))`

`skill-specific critical chance bonus = 10 × floor(level / 10) percentage points`

| Level | Blasts per cast | Base attack damage per blast | Skill critical chance bonus |
| --- | --- | --- | --- |
| 1 | 1 | 1.5× | +0 percentage points |
| 2 | 2 | 1.7× | +0 percentage points |
| 5 | 3 | 2.3× | +0 percentage points |
| 10 | 6 | 3.3× | +10 percentage points |
| 20 | 11 | 5.3× | +20 percentage points |
| 30 | 16 | 7.3× | +30 percentage points |

Damage progression is per blast, rather than a total cast budget divided among
the blasts. Critical milestones are cumulative and skill-specific: +10 points
at level 10, +20 at 20 and +30 at 30. They add to the applicable caster critical
chance for Qi attacks, not the caster's global chance or other skills. For
example, a 5% caster chance plus the level-30 bonus yields 35% before other
modifiers. Final chance is bounded to 0–100% under the modifier contract above.

The blast quota is divided across the receiving fighter's native contacts.
Targeting, contact protection, range and cooldown retain the existing behavior.
Size and hit area grow by 1% per level after 1; normal base damage follows the
shared contact reference above.

### One skill with item controlled colors

Color variants are the same gameplay skill, with one set of levels and rules.
Items can change the Qi color; a different color does not create another skill
or independently learned progression. Regular blue is the default for every
character and pet, including Ruby and saved Gold Qi assignments. The former
Gold Qi ID remains a compatibility alias, without an automatic gold palette.

The pet selector offers Qi once. Normal and saved Gold Qi cannot occupy two
slots on the same pet; saved duplicates keep the first occupied Qi slot and
leave the later slot empty. Existing IDs, native wire order and learned levels
remain valid.

A color-only item changes presentation. It does not itself change blast count,
damage or critical chance; an item can have additional explicit gameplay bonuses
under the shared modifier rules. Preserve existing source art and palettes, and
retain compatibility with saved loadouts using the current Qi IDs when unifying
their progression. Reuse the existing shared projectile, instance palette controls
and pooled effects; do not add a controller or material per color.

The pre-map Equipment hub has Character Gear, Skill Items and Cosmetics pages,
the character gallery's full-body portrait and category-filtered selection.
Character Gear and Skill Items each have their own ten generic slots in two
rows of five and a forty-cell selection area. Their catalogs are currently
empty; no stat items or bonuses are invented by this UI change. The original
eight-position board remains preserved as reference.

Qi color lives only on Cosmetics, with regular blue, Red, Gold, Jade and Violet
choices. These appearance settings consume neither gear nor skill-item slots.
The colors are local Goemon choices, not recovered server item definitions.
Old color items in `crystal` or numbered gear slots migrate to cosmetics; an
existing cosmetic choice, including explicit regular blue, takes precedence.

Each Cross Gate fighter saves all three pages by character ID, shared across
its skins. Each selectable pet saves them by stable source key, independently
of the character and other pets. Back discards drafts; Enter Map saves all
three records together and starts play. The companion picker retains its
separate save behavior. Run-level resets, travel, recall and death preserve
these settings.

`equipment.gd` validates wearer, category, slot and cosmetic IDs. The wearer's
explicit cosmetic choice takes precedence over the existing run-wide color
modifier; absent a cosmetic record, that manual modifier remains compatible.
Normal default is original blue. The existing Qi controller snapshots color on
the attack ticket and uses instance shader parameters. This adds no controller,
material allocation or army query to combat. Damage, counts, cooldowns and
shared skill levels are unchanged. Source art and preservation records are in
`assets/ui/crossgate/equipment/`.


## 暗殺 and 陽炎 first pass

### Confirmed endpoints and activation direction

User direction, 2026-11-13:

- 暗殺 starts at a **25% instant-kill chance** at level 1 and reaches **100% at
  level 30**. The percentage is a chance to kill, not a fraction of target HP.
- 暗殺 activates directly on key 1 with katana; it no longer requires a toggle.
- 陽炎 starts at **25% dodge chance** at level 1 and reaches **99% at level 30**.
- These skills use shared point spending and the new-run reset rule.

### Linear progression between endpoints

Use an even linear increase as the working interpretation of gradual growth.
The endpoints above are user-confirmed; the interpolation is the draft formula.
For level L from 1 through 30:

`暗殺 instant-kill chance (%) = 25 + 75 × (L - 1) / 29`

`陽炎 dodge chance (%) = 25 + 74 × (L - 1) / 29`

That adds approximately 2.5862 percentage points per level for 暗殺 and 2.5517
percentage points for 陽炎. Retain the unrounded formula for probability checks;
the table rounds only the displayed percentages.

| Level | 暗殺 instant-kill chance | 陽炎 dodge chance |
| --- | --- | --- |
| 1 | 25.00% | 25.00% |
| 5 | 35.34% | 35.21% |
| 10 | 48.28% | 47.97% |
| 15 | 61.21% | 60.72% |
| 20 | 74.14% | 73.48% |
| 25 | 87.07% | 86.24% |
| 30 | 100.00% | 99.00% |

### Implemented behavior

暗殺 rolls once on the first confirmed hit of an attempt. Subsequent native
contacts reuse that result. It retains boss/special-enemy exclusions, failed-roll
ordinary damage, protection and kill-speed streak. 陽炎 retains its existing
toggle and rolls the new chance for each eligible incoming hit. Item chance
bonuses use the shared 0–1 clamp.

## 諸刃 first pass

User direction, 2026-11-13: level 1 deals 1.6× base attack damage. Every
additional level adds 0.2× base attack damage. Using the skill reduces defense
by 10% for 10 seconds at level 1; each additional level adds one percentage
point to the defense reduction.

The working interpretation is a penalty on the caster's own defense, consistent
with the requested HUD debuff indicator. Use the shared first-pass range of
levels 1 through 30.

`damage = base attack damage × (1.6 + 0.2 × (level - 1))`

`caster defense reduction (%) = 10 + (level - 1)`

`debuff duration = 10 seconds`

| Level | Base attack damage multiplier | Caster defense penalty | Duration |
| --- | --- | --- | --- |
| 1 | 1.6× | −10% | 10 seconds |
| 5 | 2.4× | −14% | 10 seconds |
| 10 | 3.4× | −19% | 10 seconds |
| 20 | 5.4× | −29% | 10 seconds |
| 30 | 7.4× | −39% | 10 seconds |

The defense percentage increases additively, not multiplicatively. At level 30,
the skill deals 7.4× base damage and applies a 39% defense reduction for ten
seconds. The duration does not increase with level under the current definition.
The penalty modifies the defense stat rather than directly adding the same
percentage to incoming damage.

Apply the defense penalty when the skill is used; a successful enemy hit is not
a prerequisite. Existing cooldown and contact timing remain. The shine uses
the four level tiers above; the impact size stays fixed against level growth. Items
and special upgrades remain separate modifiers under the shared rule.

The active debuff appears beneath the controlled character's feet, using the
existing 諸刃 icon, red `DEF −N%` and a countdown in tenths of a second. It follows
movement and camera projection, respects HUD scale and hides on expiry, death
or when the character is offscreen. Pausing preserves the remaining time.

The defense penalty refreshes to ten seconds on reuse, does not stack, and reduces
current defense. It stays through fighter switches, expires during active play,
and clears on a fresh run. Recasting refreshes the same badge to ten seconds.


## 一石二鳥 first pass

User direction, 2026-11-13: level 1 has an initial impact dealing 1.1× base
attack damage, followed by an explosion dealing 2.1× base attack damage. Each
level adds 0.1× base damage to each stage. Use the same level-1–30 working range
as the other first-pass skill definitions.

For level L from 1 through 30:

`initial impact damage = base attack damage × (1.1 + 0.1 × (L - 1))`

`follow-up explosion damage = base attack damage × (2.1 + 0.1 × (L - 1))`

| Level | Initial impact damage | Follow-up explosion damage |
| --- | --- | --- |
| 1 | 1.1× | 2.1× |
| 5 | 1.5× | 2.5× |
| 10 | 2.0× | 3.0× |
| 20 | 3.0× | 4.0× |
| 30 | 4.0× | 5.0× |

The two multipliers belong to separate damage stages; do not split a single
stage's damage budget between the impact and explosion.

- The initial impact's size does not increase with skill level.
- The starting shine grows with skill level.
- The follow-up explosion grows with skill level.
- Keep level-driven primary impact size separate from shine and explosion growth;
  a shared size multiplier must not accidentally enlarge all three.
- The shared item/special-upgrade modifier rules still apply. A fixed level-based
  impact size does not itself prohibit an explicitly designed item modifier.

The existing forward/rear fan and delay remain. The initial victim is excluded
from the follow-up; follow-up size and area grow by 1%
per level after 1, while the initial shine uses the four tiers above. The first impact and its physical reach retain starting size
against level growth. Actual primary and secondary damage are checked separately.
Rendered evidence is recorded in the performance guide.

## 反擊 first pass

User direction, 2026-11-15: requires the actively held Spear (`polearm`).
While the skill is equipped it is always active with that weapon; no toggle or
arming cast. Switching away disables it; switching back restores it automatically.
Removing the skill disables it and clears pending counters.

User direction, 2026-11-13: start at 1.5× regular damage, add 0.2× regular damage
each level, and add one hit every five levels. Interpret the damage as per
counter-hit, consistent with the 連擊 per-hit description.

Use levels 1–30 for this first pass. The working starting count is **one hit**;
the user has not explicitly specified the initial count. Reuse the established
increase boundaries of levels 5, 10, 15, 20, 25 and 30.

`damage per counter-hit = regular damage × (1.5 + 0.2 × (level - 1))`

`counter-hit count = starting hits + floor(level / 5)`

| Level | Damage per counter-hit | Hits if starting at 1 |
| --- | --- | --- |
| 1 | 1.5× | 1 |
| 5 | 2.3× | 2 |
| 10 | 3.3× | 3 |
| 20 | 5.3× | 5 |
| 30 | 7.3× | 7 |

The added hits are counter-hits, not additional selected targets by default.
The existing source swing repeats the agreed number of times against the
attacker; it stops if that target dies. Existing triggering, newest-attacker
queueing and counter-speed streak remain. Area uses shared size growth; shine uses the four tiers above.
Item/upgrades can modify the base values separately.

## Maze 分身 first pass

User direction, 2026-11-13: start with three copies. Each copy deals 85% of the
caster's damage. Each additional level increases each copy's damage by five
percentage points, and every five levels adds one copy. Use levels 1–30 and the
established count thresholds of 5, 10, 15, 20, 25 and 30 for this first pass.

`damage per copy = caster damage × (0.85 + 0.05 × (level - 1))`

`copy count = 3 + floor(level / 5)`

| Level | Caster damage dealt by each copy | Copies |
| --- | --- | --- |
| 1 | 85% | 3 |
| 2 | 90% | 3 |
| 5 | 105% | 4 |
| 10 | 130% | 5 |
| 20 | 180% | 7 |
| 30 | 230% | 9 |

The progression is additive: 85%, 90%, 95% and so on. The percentage is for
each copy, not a shared budget divided among the copies. At level 30, the base
skill therefore creates nine copies, each dealing 230% of the caster's damage.
Item and special-upgrade bonuses can modify these level-based values.

Copies snapshot the caster damage multiplier and this skill's multiplier when
summoned; copied attacks apply their own skill rules. Existing skill eligibility,
critical/stat inheritance, thirty-second lifetime, cooldown, health and
replacement remain. The existing native lifecycle and pooled presentation own
the copies. Maze counts are separate from Lancelot shadows and legacy constants.
This adds no pet skill equipment or separate summon targeting owner.

Implemented formulas use the existing combat/summon owners; legacy source artwork is preserved.


## Archer Shadow first pass

User direction, 2026-11-13: Lancelot's 亂射影分身 starts with one shadow.
Each shadow uses the caster's current 亂射 level and deals 100% of the caster's
corresponding damage at shadow-skill level 1. Each additional shadow-skill level
adds one percentage point of damage. Every five levels adds one shadow.

Use the shared first-pass range of levels 1–30 and the established count
thresholds: 5, 10, 15, 20, 25 and 30.

`damage per shadow = corresponding caster 亂射 damage × (1 + 0.01 × (shadow level - 1))`

`shadow count = 1 + floor(shadow level / 5)`

`shadow's 亂射 level = caster's current 亂射 level`

| Archer Shadow level | Caster damage dealt by each shadow | Shadows |
| --- | --- | --- |
| 1 | 100% | 1 |
| 5 | 104% | 2 |
| 10 | 109% | 3 |
| 15 | 114% | 4 |
| 20 | 119% | 5 |
| 25 | 124% | 6 |
| 30 | 129% | 7 |

Damage increases add to the starting percentage: 100%, 101%, 102% and so on,
rather than compounding. At level 30, the base skill creates seven shadows,
each dealing 129% of the caster's corresponding 亂射 damage. This percentage
belongs to each shadow, not a total budget divided among all shadows.

Archer Shadow level controls shadow count and its damage multiplier. The
caster's separate 亂射 level controls the 亂射 used by those shadows; do not
substitute the summon skill's level or give each shadow an independent learned
亂射 level. The caster's 亂射 progression is defined in the following section.

Item/special-upgrade modifiers remain separate from these base values. Apply the
shadow damage factor once to the caster-derived damage, avoiding duplicate
bonuses when reusing current inheritance. The summon damage multiplier is
snapshotted at summoning; each new volley reads the caster's current 亂射 level
and tuning. An already-started volley retains its own snapshot. Existing
thirty-second lifetime, cooldown, stationary placement and health remain.

Reuse the current native barrage-shadow owner and pooled presentation. Keep this
skill's count and damage growth separate from Maze's 分身 progression. The existing
native barrage owner implements the count and damage rules.


## 亂射 first pass

User direction, 2026-11-13: level 1 shoots three arrows, each dealing 85% of
base attack damage. Every additional level adds one arrow. No level-based
increase to per-arrow damage was specified; keep it at 85% throughout levels
1–30.

`arrows per cast = 3 + (level - 1) = level + 2`

`damage per arrow = base attack damage × 0.85`

| 亂射 level | Arrows per cast | Base attack damage per arrow |
| --- | --- | --- |
| 1 | 3 | 85% |
| 2 | 4 | 85% |
| 5 | 7 | 85% |
| 10 | 12 | 85% |
| 20 | 22 | 85% |
| 30 | 32 | 85% |

These are arrow counts, not a specified number of distinct enemy targets.
Existing randomized nearby targeting, repeat hits on a living enemy, native bow
timing, cooldown and range remain. Each volley snapshots the count and skill
tuning; character damage and ordinary modifiers apply once.

The level-30 base is 32 arrows. Items and special upgrades can modify the
level-based count separately; 32 is not an item-upgraded maximum by itself.

Archer Shadows use the caster's current 亂射 level and therefore inherit this
arrow count and per-arrow damage rule. Apply their separate shadow damage
percentage once to the corresponding caster 亂射 damage. For example, a level-1
Archer Shadow using the caster's level-1 亂射 shoots three arrows, each at 85%
of the caster's base attack damage, because its shadow damage factor is 100%.
The shadow skill and 亂射 still have independent levels.

The existing arrow controller supplies the level count and per-arrow damage.


## Existing project constraints

Reuse native attack contacts and the existing combat, projectile, effect and army
owners. Cosmetic impact effects must not create extra damage. Summoned companions
keep the shared native scattered-target preference and existing command ownership.
Prepare resources outside combat loops and reuse pooled presentation.

Verification covers affected Cross Gate fighters, weapons,
skins, borrowed versions, progression/save boundaries and repeated simultaneous
use. Verify appearance and frame-time behavior through Play Goemon; technical
checks alone do not establish correct animation or smoothness. Export an app only
on an explicit build request.

## Related project sources

- [Existing progression rules](team-leveling-spec.md)
- [Performance and native contact guidance](goemon-performance-guide.md)
- [Cross Gate roster](../scripts/rogue_roster.gd)
- [Shared skill catalog and native slots](../scripts/spells/spell_catalog.gd)
- [Existing skill balance controls](../scripts/spells/skill_balance.gd)


## 護衛 first pass — 2026-11-22

`shin/bodyguard` is available in character and pet skill equipment, with any
weapon. It is automatic while equipped; pressing its numbered slot is not an
arming cast. User direction, 2026-11-23: each level after level 1 adds one
percentage point of activation chance and one percentage point of defense for
**only the intercepted hit**. Defense here reduces that hit's damage; it does
not change ordinary physical/magic defense or reduce other incoming hits.

`chance = min(100%, 50% + 1% × (level − 1))`

`intercepted damage = ordinary intercepted damage × (1 − 0.01 × (level − 1))`

| Level | Activation chance | Intercepted damage reduction |
| --- | --- | --- |
| 1 | 50% | 0% |
| 2 | 51% | 1% |
| 5 | 54% | 4% |
| 10 | 59% | 9% |
| 11 | 60% | 10% |
| 30 | 79% | 29% |

Each wearer uses a shuffle bag for its current intended distribution. The bag
preserves the one-success/one-failure pair at level 1 and draws without
replacement from 100 outcomes at higher levels (51 successes/49 failures at
level 2). Remaining success/total counts store the bag without allocating an
array. A changed level starts the new distribution. Level 30 reaches 79% chance. The hit
snapshots the wearer's bonus at activation, before ordinary damage scaling and
armor. Character and individual pet skill levels keep their existing run lifetime,
point costs and independence; recalling a pet or resting preserves its level.
This skill costs no mana and has no added cooldown; a wearer already rescuing
cannot start another rescue during its 0.18-second movement.

A reachable ally within 12 m can be rescued. Successful protection interrupts the
wearer's unfinished action, moves them in front of the ally toward the incoming
hit, pushes that ally away, and transfers that one hit to the protector. The
protected character or pet continues its current action: attacks, casts, combo
steps, charge clocks, targets and movement intent are retained. Only the
protector cancels its action. Displacement still obeys collision and ordinary
attack reach; continuing an attack does not guarantee an out-of-range hit. Native
terrain validates the straight path, landing and push before a chance is drawn.
Dodge/invulnerability cannot erase the transferred hit; ordinary incoming damage
scaling and defense still apply. Buildings, workers, poison ticks and fatal or
guard-breaking attacks retain their existing rules.

Pets use the same native rescue path with a short jump, then pursue the closest
reachable enemy within 24 m through the existing pet combat owner. New F/Z/right
click commands keep priority. The original recovered exclamation (record 19060)
and `cgefc01.wav` accompany activation. No new character drawings or audio are
invented. Mirror copies omit this passive from their cast choices.

Choose plain **護衛** for this progression. Its native wire ID stays 22. The
separate November 23 Tina NPC removal retired the older teaching techniques;
codes 12–21 remain unused so this skill and the original eleven pet attack codes
do not move.
