# Fire Siege Astra Implementation Handoff

Design revision 0.2 | 8 October 2026 | Decision gated implementation specification

## 01 Start here

Implement confirmed requirements using the reusable assets. This documentation does not change the game. Proceed in independent slices; resolve open decisions before completing their dependent gameplay.

### Pasteable starting prompt for Astra

Implement this Fire Siege handoff in eric2532/Goemon. Source branch label: codex/fire-siege-universal-controls. Authoritative baseline: 81b9f0b69ea6b0fef3c3b832d24641ca64eb8640. Verify checkout differences; preserve existing work and unrelated modes without resetting to the baseline.

Read this specification and both JSON companions. Inspect named runtime files/tests and verify supplied asset packages. Listed asset paths are planned destinations, not proof of availability. Reuse BLEND/GLB assets; do not remodel from pictures.

Confirmed requirements are authoritative; inherited behavior is scoped; open decision IDs are unresolved. Null is not zero. Never promote legacy values, art timings, simulations, or test fixtures into approved balance. Ask only decisions blocking the next slice, with concise options, and continue independent work.

Follow the sequence and acceptance contracts. First return the plan, blocking IDs, and asset availability. Finish with changed files, decisions, exact test results, runtime checks, and limitations. No GitHub publication, merge, or baseline-branch change is authorized by this handoff.

### Authority and evidence

**Confirmed** means chosen by the user. **Inherited** means retained from the pinned baseline in an unchanged area. **Open** requires a decision. **Proposed engineering contract** describes a suggested implementation arrangement, not approved balance. Derived arithmetic is labeled and depends on its stated assumptions.

The original 21 page baseline is immutable. Local source files used for the migration map were verified against the cached Git object manifest for the [pinned commit](https://github.com/eric2532/Goemon/commit/81b9f0b69ea6b0fef3c3b832d24641ca64eb8640). The project declares Godot 4.6 and Forward Plus. Source inspection establishes existing behavior; it does not prove the redesign works. Asset import tests, offline simulations, and target game testing are separate forms of evidence.

**Publication status.** GitHub publication is pending. Materialize the supplied packages and inspect their manifests before integrating. A planned path or an approved gameplay number is not publication permission.

### Explicit preservation boundary

Preserve the hero roster, abilities beyond LMB/RMB, movement, camera, hero switching, personal progression, and direct kill healing unless a specific change here overrides them. Zero enemy rewards does not remove XP, credited kills, healing, or attack chain credit. Allied systems are not removed by the enemy targeting change; their role in the new economy is D19.

Base defeat at zero integrity, normal breach damage 1, boss breach damage 15, and Beta/Hard starting integrity 100/50 are inherited references, not newly selected balance. Profile exposure, bosses, and breach accounting still need the decisions below. Hero death must no longer cause defeat or prevent victory by itself.

## 02 Canonical first build requirements

These values supersede older redesign notes and incompatible baseline defaults. The JSON companion carries the same values; any disagreement is a defect to resolve before implementation.

| Area | Confirmed requirement |
|---|---|
| Map | One enemy route, two walls, base behind both walls |
| Starting defenses | No prebuilt towers; four empty front wall sites |
| Added sites | Eight empty approach sites, one straight row of four on each side of the enemy entrance path; same build rules |
| Rear wall sites | Open, D16; twelve sites are explicitly approved |
| Starting gold | 10 |
| First tower | Level 1 arrow tower only; purchase costs 5 gold |
| Arrow attack | One visible arrow every 0.5 seconds, or 2 shots/sec; 50 damage per arrow |
| Normal enemy | Initial HP 100; role mitigation and later scaling remain open, D12 |
| Mine | Requires purchase near base left; cost 10 gold; level 1 earns 2 gold/sec during combat only |
| Tower operating cost | Each completed tower drains gold over time during combat, even when idle; rate and zero wallet behavior are open |
| Setup economy | No mine income or tower drain during unlimited setup |
| Enemy rewards | Zero kill gold and no items or pickups |
| Wave rewards | Completed wave N pays 10 × N gold once, including 100 before wave 10 victory and result UI |
| Construction | Stand in front of a site and hold B; progress, hammer, visible assembly; release decays, rehold resumes; debit only on completion |
| Wave start | Unlimited setup before every wave, including the first; hold Y for 3 seconds with visible progress and release decay |
| Waves | Ten waves; 5 enemies/sec for 60 seconds, then clear remaining enemies before reward and next setup |
| Hero death | Run continues; enemies become faster; auto revival after 5 seconds; Beta has Revive Now to skip the delay |
| Hero HUD | Bottom center portrait, health, LMB primary and RMB secondary; refresh on hero switch; 2D icons preferred, placeholders acceptable |

Nominal spawning is 300 enemies per wave and 3,000 across ten waves, before the unresolved cap/backlog policy. Use 5/sec for every first pass wave; no escalation is approved. All wave rewards total 550 gold. A completed mine earns 120 gross gold per full 60 combat seconds and repays its purchase in 5 gross earning seconds. These calculations exclude construction time, pauses, setup, and tower drain.

No cannon upgrade levels or values, mine upgrade levels or values, ammunition purchases, starter ammunition, replacement cards, or 0.1 gold/sec tower drain are approved. Future arrow to cannon progression is an intent, not a first build feature.

## 03 Run and wave state contracts

The state names below are a proposed implementation vocabulary. Their required transitions come from the confirmed rules; they do not create extra timers or balance values.

| State | Required behavior and exit |
|---|---|
| Setup | Unlimited preparation. No mine income or tower drain. Await one manual Y confirmation; no automatic first wave or interwave timer |
| Start confirmation | Advance visible progress while Y is held; 3 seconds of valid holding reaches confirmation. Release decays it and rehold resumes. Decay and interruption details are D07 |
| Spawning combat | Start the 60 second spawning clock only after confirmation. Schedule 5 enemies/sec. Mine earns 2/sec when completed; all completed towers incur the still unpriced time based drain |
| Clearance | At 60 seconds stop scheduling and emitting new enemies; resolve cap/deferred demand under D08. Keep the wave active until remaining enemies are cleared. Cleanup economy clocks and breaches are D03/D10 |
| Settlement | Pay 10 × wave number once. After waves 1–9 enter Setup. After wave 10, pay 100 before victory and its UI |
| Terminal state | End the run through its resolved victory or base failure policy. Simultaneous terminal events are D20; stale callbacks must not affect a new or ended run |

Hero death is an orthogonal temporary state, not a run terminal state. Spawning, enemy travel, towers, and clearance cannot stop merely because hero HP is zero. Revival cannot create a second wave, duplicate settlement, or undo an already terminal run.

### Spawn and actor accounting

Implement a time based 5/sec scheduler rather than retaining the old 600 actor roster. Initial spawn placement within the 0–60 second window, exact first/last spawn boundaries, live cap, backlog handling, and composition are D08/D09. Nominal demand is 300 per wave; do not silently discard demand or extend spawning after 60 seconds to hide a cap conflict.

Track each actor and each scheduled demand exactly once. Proposed accounting should distinguish scheduled, spawned, killed, breached, alive, and deferred/unspawned counts. The final conservation equation depends on the approved backlog policy. A corpse or breach must not settle twice; a removed actor must not leave an impossible clearance requirement.

The user requires remaining enemies to be cleared, described as killing all. The baseline removes a breached actor at the base. D10 must reconcile those rules explicitly. Do not silently reinterpret the requirement as a timer-only wave, ignore breaches, or change base damage.

### Transition edge cases

Test release/rehold of Y, duplicate confirmation callbacks, and a key held across combat. Every new wave still needs its own manual confirmation; do not carry completed confirmation progress into the next setup. Decide rearming and input interruptions under D07.

Test hero death during spawning, clearance, and the final kill; base failure and final clearance on one tick; pending projectiles after a phase change; and retry while callbacks remain queued. Use run/wave identity guards or an equivalent technical safeguard so old spawns, income, drain, purchases, or revival cannot affect the replacement run.

## 04 Construction and economy contracts

### Hold B and authoritative completion

The hero stands in front of an eligible tower or mine site and holds B. Show progress above the site, a small hammer while work advances, and corresponding assembly. Releasing before completion causes progress to decay; reholding resumes the remaining amount. A successful completion debits the price once, activates the structure, and emits one clear completion light. Incomplete or cancelled work costs zero.

Mine purchase and future mine upgrades share this interaction. First build tower purchases are level 1 arrows only. Do not expose undefined upgrade purchases. Construction duration, decay rate, eligibility geometry, target priority, line of sight, phase availability, and all non-release interruptions require D04/D06. Do not inherit the old F instant purchase or its range.

**Proposed engineering contract.** Give each site an identity and authoritative normalized progress p in [0,1]. Let the model, bar, and hammer read that state rather than owning it. One clearly indicated active build target is proposed, not a newly approved targeting rule. Seek the build animation to p, decrease the same p on decay, and trigger effects from the paid completion event.

Make debit and activation a single guarded transaction. Completion events must not duplicate the debit, grant a free extra structure, or charge cancelled work. Affordability checks at start and completion, progress behavior when money is insufficient, and ordering against income/drain are D05. No debt or wallet-floor policy is implied by the price or by a technical race-condition guard.

### Gold sources and drains

The approved sources are mine income and wave rewards. Enemy kills, items, pickups, and scrapped card effects contribute nothing. Construction debits occur at completion; operating drain is a distinct time based system per completed tower, including idle towers. No ammo stock or per-arrow billing is approved.

For spawning combat, a useful symbolic ledger is mine income 2 × completed-mine earning seconds, minus r × completed-tower active seconds, plus settled wave rewards, minus completed purchases. Here r is unresolved D01; the expression is analysis, not a configuration default. Setup income and drain are both zero. Mine pause income is zero; tower pause drain is still explicitly D03.

Keep fractional accrual and display separate. D17 must choose ledger precision, rounding, and tick granularity. Whatever is chosen must not create or lose gold because rendering runs at a different frame rate. Mid-combat completion starts the eligible structure's clock only when the completion transaction succeeds.

Two opening towers consume all 10 gold. Whether they can operate at zero gold depends on D02; a gross wave 1 reward of 10 does not guarantee net mine affordability. Mine-first consumes all 10 and earns only during combat. Gross mine payback is 5 earning seconds before drain, not a claim that either opening survives.

### Cleanup and depletion risk

Cleanup mine income and cleanup tower drain must both be decided under D03; do not infer one silently from the word combat. If the last enemy can be stalled safely and net income stays positive after drain, cleanup can permit unlimited farming. Ask whether that is intentional; do not add a cap or a 60 second income cutoff without approval.

At low or zero gold, decide firing availability, debt or payment policy, partial payment allocation across towers, disable/re-enable behavior, and recovery after mine income or rewards. D02 owns these outcomes. No 0.1 gold/sec rate or automatic shutdown policy is approved.

## 05 Combat hero HUD and removed cards

### Combat and revival

The level 1 tower fires a single visible arrow every 0.5 seconds when firing, with 50 damage per arrow. Initial normal HP is 100. Two hits is a nominal result against an unmodified target, not a promise across unresolved mitigation or wave scaling. Range, target selection, projectile travel/collision, first-shot timing, and retarget behavior are D11. Role defenses, HP interpretation, growth, and bosses are D12.

Enemies rush the base and may attack only the controlled hero. Towers, mines, and allies are excluded from attack targeting and must not remain unintended melee, ranged, area, boss, or retaliation victims. Reaching the base is a route/breach event, distinct from selecting an attack victim.

Hero death leaves the siege running, makes enemies faster, and revives the hero after 5 seconds. Beta Revive Now skips the wait and must not allow a second revive from the old timer. Speed multiplier/reset, respawn position and HP, immunity, clock, dead-state controls, switching, ability cleanup, and construction interruption remain D13/D14. Death does not by itself block victory.

At bottom center show the current hero's portrait, health, LMB primary, and RMB secondary. Refresh all four on a hero switch. 2D weapon/spell icons are preferred; first build placeholders are accepted. Other abilities and bindings remain. Gold/wave placement, remaining HUD coexistence, and final art are D18.

### Remove all fifteen old cards

| Card | Baseline ID |
|---|---|
| Frost Battery | ice_shells |
| Deep Winter | deep_freeze |
| Shatter | shatter |
| Rapid Reload | rapid_reload |
| Heavy Ordnance | cannon_power |
| Dragon's Breath | hot_flames |
| Eagle Watch | long_sights |
| Siege Shells | siege_payload |
| Armor Piercer | piercing_rounds |
| Wildfire Fan | wide_flames |
| Burning Ground | burning_ground |
| War Chest | supply_cache |
| Second Wind | shrine_repair |
| Stone Sanctuary | fortified_shrine |
| Bounty Charter | bounty_hunters |

Remove offers, effects, bonuses, stacks, path locks, draft prerequisites, and mandatory draft pauses in the redesigned mode. No replacements are approved. War Chest cannot grant 1,000 gold; Bounty Charter cannot restore kill income. Clear stale setup, tutorial, HUD, retry, and result copy and ensure old saved tuning/card state cannot leak into a fresh redesigned run. Preserve unrelated modes.

## 06 Asset integration contract

The following are planned repository destinations. They are not currently verified as live on the source branch. Obtain the supplied packages, inspect their manifests, and materialize them before use. Native Blender sources are packaged as .blend.gz; extract before editing. GLBs are runtime visuals. Current design values override older gameplay annotations inside visual packages.

### Arrow tower

Root folder: assets/economy_v1/arrow_tower/. Editable source: firesiege_arrow_tower_v1.blend.gz. Runtime files under exports/: tower_stage_empty.glb, tower_stage_frame.glb, tower_stage_assembling.glb, tower_stage_complete.glb, tower_wall_mount.glb, tower_build_recoil_reverse.glb, and arrow_projectile.glb.

The animated tower uses Tower_Build_Recoil_Reverse. Import at 24 FPS. The clip starts at 0 and lasts 179/24 seconds: Blender frames 1–72 build, 79–91 fire, 109–180 reverse. Seek build at p × 71/24 seconds and lower p for decay. Reverse preview seek is 108/24 + (1 − p) × 71/24. These are art times; gameplay still controls construction timing and the approved 0.5 second shot interval.

Stable names: TOWER_ROOT, LAUNCHER_YAW, LAUNCHER_RECOIL, ARROW_PROJECTILE, SOCKET_ARROW_MUZZLE, SOCKET_BUILD_FX. Use retained names; arbitrary stable_id extras are not Godot metadata by default. The standalone arrow has ARROW_PROJECTILE_ROOT and SOCKET_ARROW_TIP at its tip origin. Instantiate in a world projectile container, copy the muzzle global transform, and use its +Z axis for flight; hide the embedded preview arrow until reload. Muzzle is Godot (0, 1.86, 1.73). Footprint foundation is 2.8 × 2.75 m; nominal site is 2.8 m square; complete height is 3.785 m.

### Gold mine

Root folder: assets/economy_v1/gold_mine/. Files: goldmine_v1.blend.gz and goldmine_v1.glb. Root GoldMine_Root; clips build and reverse_build, 2 seconds each; work_loop, 4 seconds; upgrade_preview, 2 seconds, visual proposal only. Initialize an unbuilt mine at build p = 0; the source opens in its completed editing pose. Seek build at normalized p for reversible partial work.

Required editor settings: animation/remove_immutable_tracks=false and nodes/use_name_suffixes=false. Runtime alternative: GLTFDocument.generate_scene(state, 30.0, false, false). Otherwise the cart can jump to origin and work_loop can become work. Set the work loop mode explicitly. Hidden scale endpoints use 0.00001. Sockets are socket_build_fx, socket_income_fx, socket_entrance. Footprint is 4.55 × 4.73 m; visible height 2.89 m.

### Shared construction feedback

Root folder: assets/economy_v1/construction_fx/. Source: FireSiege_ConstructionFX_v1.blend.gz. GLBs under exports/: FS_FX_Hammer_BuildLoop, FS_FX_ProgressFrame, FS_FX_BPrompt, FS_FX_CompletionPulse, each with .glb extension. Roots: FX_HammerRoot, FX_ProgressRoot, FX_BPromptRoot, FX_CompletionRoot. Clips: Build_HammerLoop, looping 1 second; Complete_GoldPulse, one-shot 1 second.

Drive ProgressFill scale.x from p; left anchor is −0.975 m, full fill width 1.95 m. Hide at zero or use an invisible epsilon. Billboard the whole frame; use a separate Y label for wave confirmation. Hammer advances only during valid work; completion pulse fires only after paid success. Preserve both ring morph tracks and all ten spark transforms.

Blender uses meters, +Z up, −Y front; GLB uses +Y up, +Z front. Rotate the visual root 180 degrees around Godot Y only if its gameplay parent expects −Z; never convert twice. Asset-level Blender/Godot 4.6.3 import and playback passed. Target gameplay, visual integration, and performance remain untested. The optional combined demo is presentation-only. Full dimensions, nodes, sockets, and validation detail are in the asset JSON.

## 07 Implementation sequence and source map

This proposed sequence authorizes no missing balance. Keep each slice reviewable and unrelated modes working.

1. **Preflight and decisions.** Verify baseline, checkout differences, engine, tests, and actual assets. Report blocking decision IDs; planned paths do not prove availability.
2. **Contracts and mode boundary.** Centralize confirmed and unresolved settings. Add state/ledger tests with labeled fixtures. Remove redesigned-mode card dependencies; preserve other modes. Null cannot become zero or a legacy default.
3. **World and visual adapters.** Integrate GLBs, roots, sockets/clips, and seeking. Add the twelve sites and left-base mine subject to D16. No remodeling or runtime demo substitution.
4. **Construction and economy.** Implement hold/release/resume and guarded completion after D01–D06/D17 are answered for the slice. Integrate mine accrual, timed tower drain, and wave settlement with separate ledger events.
5. **Waves combat and revival.** Implement manual starts, bounded spawning, clearance, targeting exclusions, and temporary death after their blocking decisions. Remove every hero-life guard that wrongly freezes the siege or prevents final victory.
6. **HUD and regression.** Refresh UI/copy, verify retry/terminal cleanup, and run automated plus actual game checks. Separate evidence from assumptions.

### Verified migration starting points

**scripts/tower_defense.gd.** reset/begin initialize old wallets and prebuilt towers. queue_wave/tick carry finite rosters, card gates, and old rewards. record_defeat pays kill gold. Replace purchase flow and audit all modifiers. Crucial: tick currently returns when player.hp <= 0 at line 194, freezing the siege during the required temporary death unless changed.

**scripts/game.gd.** Replace Fire Siege's F purchase with held B and add held Y start without changing other modes. Remove draft gates and stale setup/result copy. defense_victory rejects zero hero HP at line 1109. Audit life guards around roster, summon, input, and pause/resume paths at lines 660, 700, 724, 924, and 951. Changing the damage handler alone is insufficient.

**scripts/player.gd.** take_hit calls game.defeat at zero HP. Route redesigned Fire Siege deaths to revival and cover both original and native hero damage paths. Keep other controllers and abilities intact.

**scripts/tower_defense_world.gd.** Preserve the route, walls, and base; replace cannon/fire site typing with the approved empty sites and add the mine. Review rear sites and coordinates under D16.

**scripts/defense_cannon.gd and scripts/defense_flame_tower.gd.** Reuse compatible infrastructure only. Old tiers, reload values, damage, and card logic are not the new arrow tower. The new adapter uses 50 damage and a 0.5 second single-arrow interval.

**scripts/enemy.gd, scripts/enemy_pursuit.gd, scripts/defense_enemy_traits.gd.** Audit route/objective logic, victims, HP/mitigation, boss paths, actor resolution, and temporary-death speed.

**scripts/hud.gd, scripts/defense_cards.gd, scripts/defense_card_picker.gd.** Implement the hero panel, remove old card/economy/build messaging, and disconnect catalog effects and picker prerequisites.

Existing tests include tower_defense_tests.gd, tower_defense_beta_tests.gd, defense_tactics_tests.gd, defense_fire_tests.gd, and fire_siege_controls_tests.gd. Replace obsolete redesigned-mode expectations while preserving unrelated coverage.

## 08 Decision register for economy construction and waves

All entries are unresolved. Ask the named question before its dependent slice ships; continue independent confirmed work. Options are questions, not defaults. The companion JSON contains these IDs and affected tests.

**D01 Tower drain rate.** What gold/sec does each completed tower consume? Combat-only, including idle towers, is confirmed. No numeric rate is approved; 0.1 gold/sec remains a proposal. Blocks economy balance and A05/A06.

**D02 Low and zero wallet.** At insufficient gold, do towers stop, accrue debt, or follow another rule? Decide all-at-once versus priority allocation, partial payments, firing effects, debt limits if any, and re-enable behavior after income/rewards. Blocks A06/A09.

**D03 Economy clocks.** Does mine income continue during Clearance? Does tower drain continue then? Decide separately, including intentional net farming. Mine setup/pause income and tower setup drain are zero; tower pause drain is still open. Blocks A05/A06/A13.

**D04 Construction duration and decay.** Choose tower and mine build seconds, decay rate or duration, any decay delay, and upgrade timing when upgrades are defined. Animation lengths choose none of these. Blocks A07/A08.

**D05 Purchase affordability and ordering.** May unaffordable work start? At completion without enough gold, does progress hold, decay, fail, or follow another rule? Order same-tick income, drain, construction, and reward transactions. Blocks A09/A15.

**D06 Build eligibility and interruptions.** Choose range, facing, line of sight, target selection, one versus multiple active/partial sites, and whether B construction is allowed in Setup, Spawning, and Clearance. Define movement away, target/hero switch, death, menus, pause, and exit effects. Only B release decay/resume is fixed. Blocks A07/A08.

**D07 Y confirmation behavior.** Choose decay, interruptions, UI placement, dead-hero eligibility, and how input rearms between waves. Required outcome: a distinct manual 3 second confirmation for every wave, no automatic restart from carried progress or a stale callback. Blocks A10.

**D08 Spawn boundaries and population cap.** Choose first/last spawn timing, live cap, and exact deferred demand handling. Five/sec for 60 seconds gives nominal 300. Explain cap behavior without silently skipping actors, changing rate, or extending the spawning window. Blocks A11/A12.

**D09 Enemy composition.** Choose the first pass role mix and any boss inclusion. Five/sec remains unchanged on all ten waves. This does not settle HP scaling or boss scheduling under D12. Blocks A11/A16.

**D10 Breaches and clearance.** How does an actor removed by a base breach satisfy the kill-all/clearance requirement? Keep base loss separate. Define killed/breached/alive/deferred count conservation and wave completion exactly. Blocks A12/A13/A15.

**D17 Fractional ledger and display.** Choose accrual/debit granularity, precision, rounding, and shown gold precision. Preserve rate totals across frame rates. Decide simultaneous transaction ordering with D05, not by incidental callback order. Blocks A05/A06/A09.

Questions D01–D03 and D05 are especially important before judging mine-first versus tower-first balance. The current opening economy cannot be validated by treating the drain as zero, omitting it, or importing a simulator's test rate.

## 09 Decision register for combat world and presentation

**D11 Tower targeting and projectile rules.** Choose range, target priority, first-shot timing, reacquisition/retarget cooldown behavior, projectile speed and trajectory, collision/obstruction, and damage timing. One visible arrow every 0.5 seconds and 50 damage are fixed. Blocks A16/A17.

**D12 HP interpretation and bosses.** Does 100 HP cover every initial normal role, and how do later waves change it? Decide retained armor/shields/mitigation, raw versus net 50 damage, wave growth, boss presence/stats/schedule, and their interaction with breach rules. Do not promise universal two-hit kills. Blocks A16.

**D13 Dead-state enemy speed.** Choose the speed multiplier and whether/when it resets on revival. Decide repeat-death stacking or replacement. Enemies must be faster while the hero is dead; no value is approved. Blocks A18.

**D14 Revival and dead controls.** Choose respawn location, HP, immunity, clock/pause handling, camera/control behavior, hero switching while dead, and treatment of active abilities/buffs/projectiles and construction. Keep the 5 second auto revive and Beta skip. Decide dead-hero wave confirmation with D07. Blocks A18/A19.

**D15 Upgrade content.** Mine upgrading uses hold B, but levels, costs, outputs, and visuals are undefined. Arrow-to-cannon progression is future intent only. Decide these separately before exposing an upgrade purchase; do not carry old tiers forward. Blocks upgrade-specific extensions of A07/A09.

**D16 Sites and geometry.** Decide rear wall buildability and exact coordinates, spacing, collision and interaction pads for added sites/mine. Preserve one route, both walls, and its clearance. Four front plus eight approach sites are approved; rear sites are additional only if approved. Blocks A01/A02.

**D18 HUD completion.** Choose gold/wave display positions, final portraits/icons, affordability/depletion feedback, and coexistence with other ability indicators. Bottom-center hero portrait/health/LMB/RMB and switch refresh are fixed. Attack-icon placeholders are already acceptable. Blocks final visual A20.

**D19 Profiles and allies.** Confirm Beta/Hard exposure and inherited integrity differences under the new opening economy. Decide any ally availability/cost changes separately; enemy exclusion from attacking allies does not remove allied systems. Existing hero abilities/progression remain. Blocks profile and economy regression A21.

**D20 Terminal precedence.** Decide base failure versus final enemy clearance/reward on the same tick; pending projectiles; hero death/revive concurrent with victory; and what happens to active transactions on terminal transition. A hero's zero HP cannot itself defeat the run or prevent victory. Blocks A15/A19/A22.

### Change control

Keep the baseline immutable. For each new answer, record its decision ID, approved value/behavior, date, and affected tests. Update readable spec, decision JSON, prompt, and asset contract together when relevant. Remove resolved questions from the current open register; history must not override current canonical values.

A proposal, temporary test fixture, art timing, old source default, or offline simulation result is not user approval. Do not silently choose unresolved parameters to make tests pass. If implementation requires a temporary diagnostic value, isolate and label it so it cannot ship as the design.

After code changes, report baseline and final commit identities, the implementation diff, resolved/open decisions, exact tests and results, actual runtime/visual checks, and limitations. Do not call a source review, imported GLB, or simulated economy a tested playable game. Publication and merging still require separate authorization.

## 10 Acceptance and verification checklist

These are pending test contracts, not completed gameplay tests. Resolve dependent decisions first. Use deterministic fixtures and clocks; no hidden balance defaults.

**A01 Opening state.** Verify 10 gold, no towers, unpurchased/uncompleted mine, one route, two walls, four empty front sites, eight empty approach sites, and the approved rear policy.

**A02 Asset integration.** Materialize supplied packages; verify all named nodes, clips, import settings, axes, sockets, partial seeking, visible arrow flight, and readability in the actual target game. Record visual/performance checks separately.

**A03 Enemy rewards.** Hero, tower, and ally final blows grant zero gold and no pickups. Separately verify retained kill credit, XP, healing, and attack-chain behavior.

**A04 Wave settlement.** Pay 10 × N once per completed wave, totaling 550. Final 100 precedes victory/UI. Retry or duplicate actor callbacks cannot pay again.

**A05 Mine clock.** Completed mine earns 2/sec in approved combat phases; zero before completion, in setup, and paused. Verify 120 gross/60 eligible seconds and partial intervals at several frame rates.

**A06 Tower drain.** With 0, 1, and all 12 approved towers, verify the approved rate including idle towers and mid-combat completion. Test cleanup/pause clocks, insufficient gold, allocation, and recovery using D01–D03.

**A07 Build progress.** B advances, release decays, rehold resumes. Bar, assembly, and hammer stay synchronized. Only successful completion charges 5/10 once and emits one light. Old F cannot bypass it.

**A08 Interruptions.** Exercise every D06 case, multiple partial sites if allowed, pause, death, switching, and phase changes. No cancelled work is charged.

**A09 Money races.** Exercise simultaneous completion, mine tick, drain, and reward; affordability failure; repeated input; and duplicate callbacks. Ledger changes match approved events exactly, including fractional precision.

**A10 Manual starts.** Every wave needs its own 3 second Y confirmation. Release decays progress. No stale completion, retained progress, or continuously held key silently starts another wave.

**A11 Spawn schedule.** Verify first/last boundaries, 5/sec, nominal 300 per wave, unchanged rate through wave 10, and zero unauthorized scheduling after 60 seconds across variable frame rates.

**A12 Population accounting.** Under cap pressure, verify the approved backlog policy and conservation of scheduled/spawned/killed/breached/alive/deferred counts. Each actor resolves once.

**A13 Clearance.** Timer expiry stops spawning, not the wave. Remaining-enemy clearance and D10 breach handling precede reward/setup. Test deliberate last-enemy stalling against the approved economy clocks.

**A14 Victims.** Melee, ranged, area, boss, and retaliation attacks exclude tower/mine/ally victims while enemies still rush the base and can attack the controlled hero.

**A15 Same-tick terminal events.** Apply D20 precedence for base failure, final kill, settlement, construction, and pending projectiles. No duplicate or contradictory result occurs.

**A16 Damage and A17 cadence.** Verify initial normal HP 100, approved mitigation/scaling, 50 arrow damage, one visible projectile per shot, and 0.5 second eligible firing interval. Cover first-shot/retarget rules.

**A18 Death and A19 revival.** During spawning, cleanup, and final clearance, hero death never freezes the siege. Verify faster enemies, chosen reset, 5 second revive, Beta skip, no double revive, and terminal cancellation.

**A20 HUD and A21 regression.** Hero portrait/HP/LMB/RMB refresh correctly; placeholders remain distinct. All fifteen card effects/gates and stale copy are absent. Other abilities and unrelated modes retain coverage.

**A22 Retry and exit.** Reset wallet, purchases, build progress, wave state, income/drain clocks, death timers, and modifiers. No late event from the old run may spawn, spend, earn, revive, or alter the replacement run.
