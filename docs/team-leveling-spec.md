# Team leveling

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
- The first level needs 20 XP. Each subsequent level needs 10 more:
  20, 30, 40, 50…; cap level 99. Fractional rewards accumulate exactly in
  integer tenths; overflow carries forward. The label and gold bar include them.
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
cards over a dimmed world. Reuse `preparation_skin.gd`'s maroon panel art, silver
trim, silver category ribbons, and interface font. Cards show category, icon,
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

Show **TEAM LV N · current / required XP**, with a separate gold XP meter, directly below
the castle/statue health bar. The team level and XP count sit beneath the gold bar. At level 99 show **MAX LEVEL**.

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
existing controller/native animation clocks. It does not reduce skill cooldowns,
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
