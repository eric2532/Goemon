# Character and pet leveling

## 護衛 growth — 2026-11-23

Plain 護衛 starts at 50% activation and no extra intercepted-hit defense at skill
level 1. Each additional skill level adds one activation percentage point,
reaching 79% at level 30, and reduces only the intercepted hit's damage by
one percentage point, up to 29% at level 30. The player's or individual pet's
own 護衛 level applies. This does not add permanent armor or reduce ordinary
hits. The separate Tina NPC/teaching removal retains its own scope.

Reuse the existing skill-point and individual-pet-level flows. Rest, recall and
retained-run travel keep those levels; a fresh run retains the existing reset
rules. A pending rescue keeps the damage bonus it had when activated. Upgrading
changes that wearer's future shuffle-bag distribution. See
`docs/crossgate-skill-rules.md` for formulas and examples.


## 水龍 and 螳螂 family passives — 2026-11-22

Each selected Dragon lizards (水龍) family pet grants the player +5 HP per
second at passive level 1. Each selected Mantises (螳螂) family pet grants
+15 percentage points of player critical chance. All twenty variants in each
family qualify, including XL and effect variants. Party bonuses stack while
selected, following Bee Mirage's existing party rule, even before summoning.
Total critical chance remains capped at 100%.

In **Q → Equipment**, select the pet and press **+** beside its passive.
One of that pet's level-up stat points buys one passive level: another +5
HP/sec or +15 critical points. This shares its existing pet stat point budget;
character points and active skill levels are unchanged. The mantis passive
stops at level 7 (100% after clamping); further points cannot be spent on it.
Dragon regeneration is bounded by the pet's earned points and level 99 cap.
Bee Mirage remains a fixed +10 dodge points and cannot be upgraded here.

Ranks belong to the stable pet appearance for the current run. Removing or
replacing a party member removes its bonus immediately, while retaining its
rank for reselection. Recall and retained-run travel preserve ranks; a new
run clears them with other pet stats. These bonuses affect the controlled
Cross Gate fighter; ordinary allied fighters and native pet stats stay separate.
The player Stats display includes both effective bonuses. Existing attack
tickets keep their committed critical-chance snapshot.

## Pet participation and stat points — 2026-11-22

Every selectable pet keeps its own level, XP and allocated stats by stable
appearance key for the current run. Each level earns one **pet stat point**;
character points and learned skill levels stay separate. In **Q → Equipment**,
select a pet and use the + beside HP, MP, attack damage, attack speed, move
speed, dodge or counter. Each point adds 30 maximum HP, 10 maximum MP, 10% of
base normal/skill damage, 10% attack speed, 5% move speed, or one percentage
point of dodge/counter respectively. Source contact counts and animation
durations remain read-only; attack speed advances the existing native clock.

A pet participates by dealing positive damage to an enemy or receiving
positive damage from it. When that enemy dies, each participating appearance
receives its full authored XP reward once, even if the character or another
ally lands the final hit. Idle pets receive none. The character's XP reward
is unchanged. Unfinished participation clears when an enemy despawns or the
area/run is cleared. Native skill/projectile hits use the same damage events.

The existing 16 × current level XP curve, level 99 cap and tapered natural
HP/damage growth continue. A level-up completely heals a living summoned pet
to its new maximum. It does not revive a defeated pet. Allocating HP increases
current and maximum HP by the same amount; ordinary stat/profile refreshes
keep existing wounds. Recall, replacement and retained-run travel keep pet
XP and allocations; a fresh run clears them. Saved loadouts and user data are
unchanged. These rules supersede the killing-blow-only and wound-preserving
level-up behavior described below.

## Character and pet XP — 2026-11-20

The main character and each pet appearance use 16 × current level XP for the
next level. The first three requirements are 16, 32 and 48 XP. The character
receives the existing enemy defeat credit. A pet earns its own XP when its
attack or skill lands the killing blow, keyed by its appearance's stable source
ID. World enemies and slimes give one XP per level. Leveled cave bosses give
five XP per level. Fresh arena slimes start at level 1 and gain a level each
time they return after defeat.

Hover over the character portrait's level for current XP, or select a pet in
**Q → Equipment** to see its own level and XP. A pet's own level supplies its
automatic HP and attack growth using the tapered formula below. Level-ups
keep existing wounds and leave pet skill levels independent. Pet XP survives
recall, death, equipment changes and retained-run travel. A fresh run resets
it alongside the character's XP.

## Skill cards — 2026-11-19

Each character level awards a stat point and queues one skill card choice. Choose
with a click or keys 1–3. Silver raises a skill by one level, Gold by three
and Diamond by five, capped at level 30. A run draws the rarity of each
displayed card from a shuffled bag of seven Silver, nine Gold and four
Diamond, then refills the bag when empty. The bag carries across drafts.

Offers use distinct equipped skill families. With eligible skills on both
the character and a selected pet, the offer includes each. Pet levels stay
with the selected companion. When equipped skills yield no candidates,
the draft offers compatible character skills that can be equipped later.
The panel opens only if there is a skill that can advance. Learned levels,
unspent stat points and the bag survive retained-run travel and reset on a
fresh run. Settings → Level-up Cards controls the new draft and defaults on.

## Historical shared stat and skill points — 2026-11-13

Each gained team level awards one point to the existing run-only point balance.
Press **Q** for the combined **Equipment** page: stat cards are on the right,
and equipped character/pet skills have upgrade buttons beneath them. A stat upgrade keeps its existing
cost; one skill upgrade costs one point and raises the chosen skill by one level,
up to 30. Spending either kind reduces the same balance. There is no separate
skill-point currency. Automatic team stats and the optional card system remain.

The Skills tab has six numbered slots matching the controlled player’s current
1–6 skill bar, including weapon skills and equipped spells. Each slot shows its
icon, name, level and upgrade button; hover over the button for current/next base
values before modifiers. Empty slots stay visible and disabled. Skills without
agreed numbers display “No upgrades.” Unequipped or stale skill requests cannot
consume points. Qi colors and native/equipped aliases share their family level.
The panel pauses play; empty-point and maximum-level requests cannot spend.
Levels and points survive fighter switches and retained-run travel, and reset
on a fresh run. Settings → Skill Balance remains a manual testing/tuning tool.
See [the skill rulebook](crossgate-skill-rules.md) for formulas and modifier rules.

## 親子丼 skill growth — 2026-11-13

Each serving adds 5% of the starting visual dimensions and hit radius for the
rest of the run: 1/4/20 servings give 1.05×/1.20×/2×. Growth is additive and
uncapped. It applies to supported size/area controls on the controlled fighter's
new skill tickets, including starting shines; damage and counts are separate.
Allied/native enemy profiles and saved balance values remain unchanged. In-flight
attacks retain their snapshots. Stacks belong to team run progression and survive
fighter switches, respawn and walking between areas. Title/new run clears them;
temporary-food expiry does not. The existing food HUD shows stacks and “Rest of run”.

The corrected base for 乾坤, 諸刃 and each 連擊 impact is 10.8 m maximum
visual dimension. Their starting shines use the same unit at the caster's chest,
independent of body size. 氣功蛋/gold Qi use half that visual size (5.4 m)
across Cross Gate casters, retaining their preceding hit radius; blue/red/gold
palettes remain separate. 追月 keeps its narrower crest
shape with a 10.8 m base length. Food scales supported visual and physical skill
areas together; it changes neither the total damage nor the native contact count.

Attack skills use the receiving Cross Gate fighter's normal attack animation
and contact markers. Kaz and Bog have two contacts; regular Shin and Lancelot
have one; Uru and Emilia's staff clip has five. Kunai uses its throw release.
乾坤 and 諸刃 apply their new damage multiplier to each native contact. 連擊
uses a total contact quota. 氣功蛋 releases its entire projectile quota on the
first native contact, with at most 50 ms between the first and last orb. 追月
divides one projectile quota across native releases. Elements divide one per-target damage budget across
all releases and pulses, restricted to the cast's selected targets. Existing
cooldowns, targeting, cover and projectile motion remain. 暗殺 keeps its
blink/pass/return and kill-speed sequence, but now activates directly and rolls
its level-based instant-kill chance once per attempt on confirmed contact.

乾坤/諸刃 are empowered normal attacks: the caster's existing sword, axe or arrow
contact decides damage. Their explosions are cosmetic confirmed-hit feedback,
centred on each struck body's bounds, including lethal hits. There is no extra
damaging explosion circle, no burst on a miss or wall, and no fixed one/two-burst
quota. 親子丼 enlarges the actual empowered attack's area and its feedback.
連擊 body bursts also come from native confirmed damage events. Other ranged
skills retain their own physical areas, so different projectiles may still hit
the same enemy. The caster's normal attack determines when and how often each
skill releases; an impact sprite alone never adds another hit.

Billboards share 連擊's body-centre anchor and view-ray depth correction. Shin's
small sword-contact flash is separate from the body explosion and follows his
recovered low blade midpoint. Self effects and summons remain attached to their
caster rather than an enemy.

Extra coverage/explosion upgrades remain deferred. The future coverage rule is
shared ownership across overlapping extra areas so one contact cannot double-hit
an enemy accidentally. This is separate from genuine later native strikes.
Pets can equip three distinct shared attack skills in Q Equipment. Each native attack
randomly chooses a ready equipped skill; independent five-second cooldowns leave
ordinary attacks between casts. Ten attacks are available, with no heals, buffs
or summons in the pet picker. Source animation contacts release each skill and
share its cast damage, using existing allied tickets/projectiles and pet damage
growth. 乾坤 feedback follows every confirmed native contact at the enemy's body.
Death/recall cancels active leases; saved choices return when resummoned. Movement,
orders, targeting and rendering remain owned by the native army.

Pet skills have independent run-owned levels per stable pet key and skill family.
They start at 1 rather than inheriting character levels. **I → Pets** shows the five
selected pets and the chosen pet's three equipped skills; one shared point buys
one level for that pet only, up to 30. Empty/unsupported skills and capped or
unequipped requests cannot spend points. Selected pets can be trained before
summoning. Death, recall, removing a pet, re-equipping a skill and retained-run
travel preserve its levels; a fresh run clears them. The pet picker displays each
pet's own levels. Ordinary/Gold Qi and native aliases share a family within that
pet; they do not share levels with another pet or with the character.
Existing shared level formulas drive damage, projectile/target counts and effects.
乾坤 divides its level-rule damage across native contacts; 連擊 applies its
level-rule damage and existing streak multiplier per hop, with a level-based hop
limit. Level plus tuning counts use the existing 1–128 shared count bound. Native
cooldowns and committed casts remain intact; new levels apply to subsequent casts.
Run reset rebinds pets to the new run's progress. Spirit has no level rules yet.

## Historical shared companion growth — 2026-11-12

Hounds and mantises share the run's team level; there is no separate pet XP or
persistent pet level. Their base is 3,000 HP and 60 damage per recovered contact.
For `n = team level - 1`, automatic growth uses `n / (1 + n / 20)` effective levels:
+10% base damage and +8% base HP per effective level. Bonuses add to the existing
pet-card bonuses, and work with cards disabled. Existing pets retain their wounds
when maximum HP rises; replacements inherit the current level. Resetting the run
resets this growth. The five-pet cap and source attack cadence are unchanged.
The Pets picker shows the shared level, maximum HP and per-contact damage.

Card limits and bonuses are unchanged at the user's request; testing this change
establishes the no-card balance only. See `goemon-performance-guide.md` for the
rejected linear curve, current combat evidence and remaining limitations.

## Magic power — 2026-11-15

Press Q → Equipment to spend the same shared points on **Magic power**. As an
initial balance rule matching Attack, each rank adds 15% of baseline magic
damage; each gained team level adds 3% to both damage channels.

`physical stat multiplier = 1 + 0.03 × (level - 1) + 0.15 × Attack ranks`

`magic stat multiplier = 1 + 0.03 × (level - 1) + 0.15 × Magic power ranks`

Base magic damage starts at 50. Magic power and automatic level growth scale
this stat. 精神衝擊波 and Fire, Ice, Wind and Meteor add it to each target's
spell damage before splitting the total across contacts and pulses. For example,
level-one Fire starts at 100 + 50 = 150 per target before other bonuses. Normal
weapon attacks, physical skills, 氣功蛋 and 追月 use the physical multiplier.
Common damage tuning, skill modifiers, critical hits and chain bonuses still
apply through their existing owners. Pet spell damage keeps its own rules.

The Stats tab shows Attack damage and Magic damage as whole numbers. Allocation
follows the controlled fighter across character changes and retained-run travel,
resets on a new run and does not write preferences. Native summoned fighter
copies snapshot the damage factors used by both channels and apply their summon
factor once. Permanent allied recruits retain their own baseline stats.

## Magic defense — 2026-11-20

The first Stats rows are Maximum health, Attack damage, Magic damage,
Defense and Magic defense. Both defense stats start at zero and gain +2 per
level. Each uses its own +10 upgrade for one shared point. The incoming damage
multiplier is `100 / (100 + effective defense)`, using Magic defense for
magical hits and Defense for physical hits. Defense food and the Double Edge
penalty still apply to the defense used for the hit.

## Stats presentation — 2026-11-18

Q Equipment now includes dark/gold stat cards with colored icons instead of
stat-name rows. The right panel shows the selected character or pet. Pet stats
are read-only native health, normal damage, source attack contacts/duration,
base movement speed and that pet's equipped skill levels. Character allocation
controls hide while inspecting a pet. Pet selection uses an explicit target
slot and Remove action; equipped catalog cards cannot toggle pets off.
Pet selection and character/pet skill upgrades share this window;
the separate I and Shift+P shortcuts are retired.
Hover each icon or its plus button for the name and point effect. The
allocations, effective values, caps, shared Stats/Skills/Pets points and saved
loadouts keep their existing contracts. Editable symbols live under
`assets/ui/crossgate/stats/`; original frame and skill artwork are preserved.

A thin blue mana bar appears below HP. The controlled player starts at 100/100,
keeps mana across character switches and refills on a new run or ordinary
respawn where that mode permits it. Skill costs, mana regeneration and mana
upgrades are not introduced by this presentation pass.

## Current stat-point tuning — 2026-11-14

Normal play awards +20 maximum HP, +3% baseline physical and magic damage, +2 defense and one
spendable point per level. Attack speed and critical chance do not grow
automatically with levels; attack-speed food and allocated points retain their bonuses. Automatic bonuses apply
immediately, even with every point unspent. Cards are optional and disabled by
default. Press I to allocate points. Each point
now gives Vitality +100 HP and +1 HP/sec, Attack +15% baseline physical damage,
Magic power +15% baseline magic damage, Attack Speed +10% baseline attack rate, Defense +10 defense, or Critical Chance
+5 percentage points (capped at 100% total chance). The critical plus button
disables at 100%, preserving unspent points. It uses each fighter's baseline
chance, applies to new attack tickets and retains in-flight snapshots. Ordinary
allied copies keep their own baseline chance; Lancelot's stationary barrage
shadows retain their existing rule of copying his current critical chance.
Bonuses add per rank; incoming damage remains `100 / (100 + defense)` (automatic and allocated
defense add together). Regeneration cannot heal beyond maximum HP or revive
the player.
The XP curve is now 15, 23, 31, 39… (roughly 20–25% less XP per level);
the level cap stays 99.

These stronger points replace the initial +50 HP / .1 HP/sec, +5% damage,
+3% attack rate and +2 defense values. They affect the controlled fighter,
follow character switches and retained-run travel, and reset on a new run.
Automatic growth is additive with allocated bonuses: at level 5 with no spent
points, the player has +80 HP, +12% damage and +8 defense, with no automatic attack-speed or critical-chance bonus.
Spending one Attack point then gives +27% physical damage in total; magic damage
stays at +12% until a Magic power point is spent. Regeneration still
comes from Vitality points.
Saved character baselines and allied stats remain separate. This is a first
balance pass responding to weak-feeling level rewards; late-run balance still
needs play feedback. The older card-system description below is historical
where it conflicts with this section (including its no-automatic-HP statement).

Implemented for Goemon / Wind Meadow Valley on 2026-10-27; current catalog updated 2026-11-05.

The settlement levels as one team. A level earns one shared upgrade, chosen from
three distinct cards drawn from the full eligible pool. **Tower**, **Worker**,
and **Character** are labels, not fixed slots: all three can share a category.
Only the selected card takes effect. Team benefits apply to every eligible
friendly unit or tower, including future arrivals. Far-reaching Strikes applies
only to the controlled character, including after switching fighters. Enemies
receive no bonus. Team levels do not automatically raise personal health, movement, jump
height, or coin count.

## XP and lifetime

- Start each new game at team level 1 with 0 XP and no upgrades.
- Opening-group enemy defeats give 1 XP, regardless of whether the player, a
  friendly fighter, a summon, or a tower earns the kill. Progress continues while
  the player is waiting to respawn. Later reinforcement groups give another
  0.2 XP per group: 1.0, 1.2, 1.4… A death can count only once, and changing
  enemy form is not a defeat. Rewards belong to the enemy's spawn group.
- Training dummies, damage without a kill, and character switching give no XP.
- The first level needs 15 XP. Each subsequent level needs 8 more:
  15, 23, 31, 39…; cap level 99. Fractional rewards accumulate exactly in
  integer tenths; overflow carries forward. The purple bar includes them; numeric XP is hidden.
- Every earned level queues one choice. If several levels arrive together,
  present them in order without resuming combat between choices.
- Changing characters, player death/respawn, pausing, and moving between waves
  retain progress. Restart, a new game, and applying a map as a fresh run clear
  XP, level, all ranks, revival unlock, and pending cards.
- This state is never saved in preferences, character balance, or map files.
  Existing saved maps, balances, and user recordings are preserved.

## Reinforcement strength — 2026-10-27

Wind Meadow uses continuous groups from each surviving enemy entrance. Each
entrance advances independently when its current full group starts attacking or
is wiped out. Existing opening delay, count growth, blocked-entrance retries,
active cap, routes and combat timing are retained.

As of 2026-10-28, configured wave counts are shared across all castles. After
spawning a wave's exact count, entrances use the next configured mix, skipping
empty waves and repeating the final mix. Mix changes can occur inside a group;
they preserve each entrance's group size, strength, XP tier and release gate.
Destroying all keeps remains the victory condition. Counts apply from a new run.

| Group at that entrance | Default count | Health | Damage | XP per defeat |
| --- | --- | --- | --- | --- |
| 1 | 10 | ×1.0 | ×1.0 | 1.0 |
| 2 | 11 | ×1.2 | ×1.1 | 1.2 |
| 3 | 12 | ×1.4 | ×1.2 | 1.4 |

Growth is linear relative to configured base stats: +20% health, +10% damage
and +0.2 XP for each group after the first. It applies to ordinary enemies and
bosses. Count settings remain independent: zero count growth still advances
strength and rewards. Partially spawned groups retain their original tier across
capacity/blocked-spawn retries. Existing enemies retain their spawn multipliers
when another group arrives; a new run starts at group one.

Native units retain two scalar multipliers. Health is prepared at spawn and
preserved through Vambee's crawling form. Existing melee, boss area/beam and
projectile paths apply damage once; launched projectiles retain that damage
after the owner dies. Team XP reads the stored spawn reward on the authoritative
death event. Group changes do not reload assets or rebuild shared kit profiles.
This curve is an initial balance choice and needs normal-play feedback.

## Choice presentation and controls

Pause simulation when a choice opens. Release the mouse and place three large
cards over a dimmed world. Reuse `preparation_skin.gd`'s recovered Cross Gate ivory/slate panel art, ivory
trim, ivory category ribbons, and interface font. Cards show category, icon,
upgrade name, rarity and bonus multiplier, precise benefit, and the next rank. Silver,
gold and diamond cards add a cool, warm or icy animated sheen and edge sparkles
over the existing panel. Text and keyboard focus stay readable; the effect
continues while combat is paused. Show the level earned and the
number of queued choices when relevant.

Click a card, press **1 / 2 / 3**, or use keyboard focus and confirm. Briefly guard
newly presented cards against accidental double clicks. Escape and the ordinary
pause/resume flow cannot dismiss an unspent choice. After the last choice,
restore the current gameplay/preparation pause state and cursor. If the run ends
before a choice can open, the victory/defeat screen takes priority.

Show **LV N** and a slim purple XP meter directly beneath
the top-left character portrait and health display. At level 99 show **MAX LEVEL**
with a full purple meter. Health uses green at normal health, retaining amber/red low-health warnings. The bottom XP/Stats/Pets panel is removed; Q Equipment contains stats,
pet selection and character/pet skill upgrades. Statue health remains separate when a statue exists.

Each earned team level plays Musashi's recovered `0xB2C` level-up cue, shared
across all characters. Playback continues while the upgrade cards pause combat.
Ordinary kills and selecting an upgrade do not replay it. The existing sound
pool handles playback; the prepared sequence needs no runtime decoding.
See `assets/audio/recovered_musashi/level_up_provenance.json` for source notes.

## Current card catalog

Each offer randomly selects three distinct eligible cards across all categories,
using its own run-seeded random generator so offers do not disturb enemy-wave
randomness. Each slot rolls rarity, then uniformly draws a matching eligible card
not already in the offer. There are nine ordinary and thirteen legendary cards.
Each of the three cards also rolls its own independent rarity. Multiple rare
cards, including matching rarities, can appear together. The rolled rarity stays
fixed until selection; UI refreshes do not reroll it.

| Rarity | Default chance per card | Bonus strength |
| --- | --- | --- |
| Normal | 84.75% | ×1 |
| Silver | 10% | ×2 |
| Gold | 4% | ×3 |
| Diamond | 1% | ×4 |
| Legendary | 0.25% | Special reward below |

These default odds follow the user's October 27 preference. In **Core Game
Balance → Level-up Card Chances**, Silver, Gold, Diamond and Legendary can each
be adjusted in 0.01 percentage-point steps, including zero. Normal automatically
fills the remainder. Each control stops at the percentage remaining after the
other rare chances, so changing one never takes probability from another.
Settings save automatically and apply to the next run; the current run and its
already offered cards retain their odds. Reset Core Balance restores the defaults.
Old saves without these fields also retain the defaults. Malformed saved values
fall back or clamp; overfull files are capped to 100% in displayed rarity order.

Ordinary rarity strength multiplies the **added bonus**, not the unit's total
stat: United Strength now gives +30%, +60%, +90%, or +120% damage. A selection
adds 1/2/3/4 effective ranks through the same team multipliers. The description,
rank and before/after team-total preview show the actual award, including existing
legendary tower stacks.

### Legendary rewards

Thirteen named special cards share one pool whenever a slot rolls legendary.
The card states exactly which hero or company will arrive; selection performs
no additional random character roll. Categories do not constrain a slot.
They use animated rainbow borders, a larger
outer glow, broad moving highlights and oversized sparkles, with a LEGENDARY
badge and the exact reward instead of a generic stat multiplier.

| Category | Card | Reward |
| --- | --- | --- |
| Tower | Heavenly artillery | All current and future towers deal 5× total damage for this run, including ordinary tower-damage upgrades. Each later selection multiplies by five again. |
| Worker | Royal workforce | Immediately grants 10 free workers at the castle. |
| Character | Dragoon / Ranger / Ninja / Knight / Explorer company (five separate cards) | Immediately grants 5 of the named mercenary at safe castle positions. |
| Character | Goemon / Musashi / Kojiro / Blademaster / Illidan / Mountain King joins (six separate cards) | Summons the named hero. They use their own configured stats and existing attacks/skills, inherit team bonuses, and stay until defeated or the run ends. |

Recruit rewards work during battle and bypass gold and food admission checks.
The new units still count toward food usage; normal paid recruitment retains its
existing preparation/currency/capacity requirements. They use the existing
workforce and native pooled mercenary lifecycle, with normal health and inherited
team bonuses. Repeated cards grant another complete batch. They are run-only.

Mercenary rewards retain exploration, terrain, building, portal, body-spacing,
physics and native-capacity checks. If all five cannot arrive, retire only that
attempt's recruits, restore its recruitment accounting and leave the choice
unspent. The player can select another offered card. Invalid or stale choices
cannot grant units. Fresh runs clear both recruits and tower stacks.

The hero reward reuses `warcraft_mirrors.gd` and `mirror_body.gd` with one
indefinite lease, separate from the normal five-copy, fifteen-second skill.
Native navigation, health and action choices remain authoritative. Only the
named hero's model and skills are prepared, during the paused choice; retired
bodies can be reused. Larger hero models get more arrival space. Heroes do not
take a paid mercenary food slot. Player changes do not change their identity.
Run reset disconnects action/step callbacks and cancels leased projectiles.
Goemon's shared coin methods now accept their actual caster for aim, stats and
pool ownership; summoned Goemon no longer reads the selected player's model.

### Ordinary cards

| Category | Card | Normal-card effect per selection |
| --- | --- | --- |
| Tower | Reinforced stone | +30% effective durability for every tower |
| Tower | Rapid volleys | +25% firing rate for every tower |
| Tower | Heavy ammunition | +30% damage for every tower |
| Worker | Expert repairs | +50% repair rate for all workers |
| Worker | Swift response | +25% movement speed for all workers |
| Worker | Back on our feet | Wounded workers revive at the castle after 12 seconds during battle |
| Character | United strength | +30% attack and spell damage for the player, friendly fighters, and summoned copies |
| Character | Battle rhythm | +20% attack cadence for the player, friendly fighters, and summoned copies |
| Character | Far-reaching strikes | +25% melee attack reach for the controlled character only |

Numerical ranks add to the base multiplier, rather than compounding: two normal
United Strength cards mean ×1.60 damage; two normal Rapid Volleys mean ×1.50 fire rate.
Existing balance settings and temporary buffs multiply with these run bonuses.
Reinforced Stone divides incoming tower damage by `1 + 0.30 × rank`; it does not
heal a tower or change its configured maximum health. At rank one this means
23.08% less incoming damage and 30% more effective durability.

Revival is a single unlock and disappears from later offers. Its rarity increases
revival speed: normal/silver/gold/diamond workers return after 12/6/4/3 seconds.
The wound notification uses the selected duration. It applies to
workers already wounded when selected and to later wounds. Revived workers
return at full health to the existing castle recovery location, with stale jobs,
paths, shelter references, cargo, and timers cleared. Without the card, the
existing between-wave recovery remains.

Workers choose the nearest safe, reachable available repair job; explicit rally
and movement orders still win, and automatic dispatch retains one guard per
occupied tower. Existing repairs cover the castle/statue, gates, and barracks.
Permanent walls and the existing tower garrison job retain their current rules.
Repair upgrades retain the price of **1 ryo per 10 HP** and stop when funds run
out. Movement upgrades also affect following, retreats, deliveries, and leaving
tower decks. Repair-target selection runs at the existing assignment cadence.

Far-reaching Strikes adds +25% / +50% / +75% / +100% reach at
Normal / Silver / Gold / Diamond rarity. Ranks add to the player multiplier and
reset each run. The existing melee reach setting carries it through each
compatible controller, contact shape, painted wave and cached ground outline.
It does not grant allied mercenaries, heroes or mirror copies more reach, or
extend projectile travel. Mirror approach distance uses the body's own reach.

Character damage includes spells through the shared outgoing damage multiplier;
there is no separate spell-only card in this first version. Attack speed uses
existing controller/native animation clocks. Total attack speed caps at 3× after
all bonuses, including allocated stats, food, pickups, cards,
run upgrades, hit chains and spell buffs. Stats displays this effective rate.
It does not reduce skill cooldowns,
add attack contacts, increase reach, or change spell duration/travel rules.
Attacks/projectiles that already captured damage keep their existing snapshot
semantics; the next attack receives the new value.

## Implementation and preservation

- `scripts/forest/team_progression.gd`: run XP, offer eligibility, queued choices,
  validation, and additive ranks; reuses the existing progression accumulator.
- `forest_model.gd`: owns/reset run state and applies tower armor.
- `forest_game.gd`: awards team XP and coordinates the modal pause and choices.
- `team_upgrade_picker.gd` / `forest_ui.gd`: three cards and the team HUD meter.
- `player.gd` / `crowd/mirror_body.gd`: shared outgoing damage and attack cadence;
  live summoned copies reference the same team state.
- `crowd/army_kit_data.gd` / `army_runtime.gd`: configure existing native ally
  multipliers and count authoritative enemy deaths. No second army simulation.
- `forest_workforce.gd` / `forest_repairs.gd`: existing movement, arrows, repair,
  recovery, and safe job assignment.

The audio follow-up adds the recovered Musashi level-up cue and Warcraft
construction cue. Existing models, animations, pose bakes, map layouts, wave
counts and native C++ ABI stay intact. No new per-unit renderer, effect pool, frame-time resource load,
permanent progression, rerolls, or shop is introduced. Rarity uses the same
run-only offer and additive rank state, plus one shared shader with three owned
card materials that are released with the popup. No combat effect is added.

## Acceptance and tuning

Run `tests/forest-shrine/team_progression_test.gd` for level boundaries, queue
consumption, rank stacking, resets, actual tower damage/cadence, worker recovery,
repair costs, nearest jobs, and native ally damage/contact timing. Rarity checks
cover exact odds, 10,000 seeded offers, independent slots, every card at every
rarity, mixed-rarity stacking, revival durations and diamond native contacts.
Legendary checks cover exact odds, named rewards, partial-batch rollback, fivefold
arrow damage, free battle recruitment and reset. `legendary_reward_failure_fixture.gd`
injects a failure after two recruits to exercise rollback without changing gameplay.

Run `tests/forest-shrine/reinforcement_combat_test.gd` for all ten enemy types'
native damage against allies and the hero, surviving projectiles, form changes,
invalid scaling and recycled handles. `wave_groups_test.gd` checks independent
group growth, blocked/capped arrivals and reset; run it through Play Goemon with
`-- --visual` for actual native group imports, defeat rewards and fractional HUD.

Run `tests/forest-shrine/team_leveling_gameplay_test.gd` through
`/Users/eric/Desktop/Play Goemon.command --script res://tests/forest-shrine/team_leveling_gameplay_test.gd`
for the real HUD and popup, all kill sources, pause behavior, character changes,
five summoned copies, rare-card descriptions, animated shine during pause,
repeated card cleanup, and a fresh-map reset. Evidence
belongs in `build/Other Files/Team Leveling/`.
The same fixture presents all three rainbow cards at both window sizes, grants
multiple worker/mercenary batches at zero gold and full food, checks blocked-base
retry and stale clicks, and runs the granted native mercenaries in combat.
Run `legendary_hero_test.gd` through the desktop launcher for all six named hero cards,
sixteen seconds of native combat, player switching, charged-coin ownership,
death/reuse and reset. `mirror_image_test.gd` protects the ordinary shared summon
across all 32 fighters, including its fifteen-second lifetime and stale handles.

The audio follow-up uses `shared_kill_audio_test.gd` and
`building_placement_audio_test.gd` through the same launcher. Desktop checks
verify level-up playback during the paused card choice, construction during
paused preparation, unchanged worker hammer samples, rejected-placement
silence, original pitch, lossless imports and fixed voice-pool reuse. Captured
mixer WAVs and logs belong in
`build/Other Files/Asset Toolkit/Construction and Level Audio/`.
Rebuild the Musashi sequence with `python3 tools/recover_musashi_level_audio.py`.
It preserves source notes, timing and fading repetitions; the dry recovery does
not emulate PS1 reverb or the full hardware envelope.

Manually play through the desktop launcher: defeat 20 enemies using any mix of
player, allies, and towers; choose a card; check that every eligible friendly
unit benefits. Change fighters, proceed to another wave, then restart and verify
TEAM LV 1 and baseline behavior. The XP curve and card percentages are initial
balance values and need normal-play feedback; focused tests do not establish
long-session balance or full-army performance.

## Free card pool and named rewards — 2026-11-05

`team_card_catalog_test.gd` exercises player-only reach, real native contact beyond
the former reach, character switching, mirror exclusion, all six hero cards,
all five homogeneous companies, blocked rewards, repeated pooled reuse and
portrait/text layout at both window sizes through the real picker. Run it with
Play Goemon. Current evidence is under
`build/Other Files/Team Leveling/Free Draft/`; this is separate from the historical
acceptance results above. No saved-map or character-balance schema changes are
needed because card ranks and offers are run-only.
