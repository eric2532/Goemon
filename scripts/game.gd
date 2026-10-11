extends Node3D
signal impact_confirmed(victim, strength, duration)

const SURVIVAL_MODE=true
var descent_mode=not "--legacy-survival" in OS.get_cmdline_user_args()
var tower_defense_mode=false
var _siege_interact_held=false
var rogue_battle_mode=false
var rogue_roster_mode=false
var roster_start_mode="defense"
var selected_rogue_id=1
var rogue_original_character=1
var rogue_roster_open=false
var rogue_pick_start=false
var rogue_defense_settings: Dictionary={}
var rogue_view
var rogue_feedback
var defense_beta=not ("--standard-defense" in OS.get_cmdline_user_args() or "--tower-defense-test" in OS.get_cmdline_user_args() or "--tower-defense-visual" in OS.get_cmdline_user_args())
var defense_hard="--hard-defense" in OS.get_cmdline_user_args()
var defense_tactics=not Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--defense-fire-") or arg.begins_with("--tower-defense-beta-"))
const AREA_NAMES=["TIDEFALL SANCTUARY", "JADE GROTTO", "SAKURA HIGHLANDS", "SUNFORGE CITADEL"]
const BOSS_NAMES=["Lord Arashi", "Lady Hisui", "Master Hanami", "Daimyo Akagane"]
var area_index=0
var run_seed=90824
var area_cleared: Dictionary={}
var area_states: Dictionary={}
var gates: Array[AreaGate]=[]
var portal_hint=""
var transitioning=false
var world: Sanctuary
var player: Hero
var camera_rig: ActionCamera
var enemies: Array[Ninja]=[]
# Snapshot per run: changing the Lab limit never deletes living combatants.
var active_enemy_limit=200
var crowd: EnemyCrowd
var pursuit: EnemyPursuit
var adventure: IslandAdventure
var encounters: EndlessEncounters
var kennel
var barracks
var boss_enemy: Ninja
var ui: CanvasLayer
var hud: GameHUD
var menu: Control
var playing=false
var paused=false
var boss_active=false
var won=false
var checkpoint=Vector3(0,2.5,41)
var kills=0
var sparks=0
var chain=0
var chain_timer=0.0
var hit_stop=0.0
var music: AudioStreamPlayer
var sounds: Dictionary={}
var sound_library: SoundLibrary
var orb_system
var voices: Array[AudioStreamPlayer]=[]
var voice_idx=0
var last_sound_voice: AudioStreamPlayer
# Attack voices are reserved: crowd impacts can never replace a swing or cast.
const ATTACK_SOUNDS=["orb_ice","orb_fire","swing","heavy_swing","throw","fire_cast","spin_swing","giant_toss","sky_leap","sky_stomp","chain_throw","chain_sweep","chain_fire_sweep","edo_volley","edo_giant","edo_shield","edo_beam_start","edo_beam_loop","edo_meteor_cast","edo_meteor_strike","edo_dodge","goemon_dash"]
const IMPACT_SOUNDS=["hit","heavy_hit","enemy_reaction","environment_hit","coin_hit","coin_heavy_hit","fire_impact","chain_hit","chain_explosion","edo_meteor_impact","edo_dodge_impact","goemon_dash_hit"]
const DEFAULT_SETTINGS={"volume":0.65,"music_enabled":false,"sensitivity":1.0,"fullscreen":false,"quality":1,"goemon_skin":HeroSkins.DEFAULT_ID}
var settings=DEFAULT_SETTINGS.duplicate()
var settings_path="user://settings.cfg"
var damage_number_frame=-1
var damage_numbers_this_frame=0
var damage_numbers_live=0
var impact_feedback_frame=-1
var impacts_this_frame=0
var impacts_live=0
var burst_feedback_frame=-1
var burst_sparks_this_frame=0
var burst_sparks_live=0
var zone_seen: Dictionary={}
var map_editor
var map_editor_draft
var custom_map_data: Dictionary={}
var launching_custom_map=false
var smoke_test=false
var tuning=PrototypeTuning.DEFAULTS.duplicate()
var lab_spawn_id=0

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	setup_inputs()
	load_settings()
	setup_audio()
	ComboEnergy.warmup()
	SkySmoke.warmup()
	EdoFireExplosion.warmup()
	sound_library=SoundLibrary.new();sound_library.game=self;add_child(sound_library)
	world=Sanctuary.new()
	world.descent_mode=descent_mode
	world.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	player=Hero.new()
	player.game=self
	player.position=checkpoint
	player.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	camera_rig=ActionCamera.new()
	camera_rig.game=self
	camera_rig.player=player
	camera_rig.sens=settings.sensitivity
	add_child(camera_rig)
	rogue_view=preload("res://scripts/rogue_battle_view.gd").new();rogue_view.game=self;add_child(rogue_view)
	rogue_feedback=preload("res://scripts/rogue_battle_feedback.gd").new();rogue_feedback.game=self;add_child(rogue_feedback)
	ui=CanvasLayer.new()
	add_child(ui)
	hud=GameHUD.new()
	hud.game=self
	ui.add_child(hud)
	crowd=EnemyCrowd.new();crowd.game=self;add_child(crowd)
	pursuit=EnemyPursuit.new();pursuit.game=self;add_child(pursuit)
	encounters=preload("res://scripts/sky_descent.gd").new() if descent_mode else SwarmSurvival.new();encounters.game=self;add_child(encounters)
	adventure=IslandAdventure.new();adventure.game=self;add_child(adventure)
	orb_system=preload("res://scripts/orb_mechanics.gd").new();orb_system.game=self;add_child(orb_system)
	kennel=load("res://scripts/defense_kennel.gd").new();kennel.game=self;kennel.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(kennel)
	barracks=load("res://scripts/defense_barracks.gd").new();barracks.game=self;barracks.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(barracks)
	spawn_enemies()
	spawn_gates()
	pursuit.configure()
	show_main_menu()
	if "--auto-build-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/auto_build_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--auto-build-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/auto_build_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--auto-attack-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/auto_attack_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--auto-attack-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/auto_attack_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--map-builder-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/map_builder_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--map-builder-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/map_builder_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--ranger-air-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/ranger_air_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--ranger-air-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/ranger_air_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--ranger-precision-tour" in OS.get_cmdline_user_args() or "--ranger-storm-tour" in OS.get_cmdline_user_args() or "--ranger-flight-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/ranger_storm_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--ranger-precision-test" in OS.get_cmdline_user_args() or "--ranger-storm-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/ranger_storm_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--ranger-flight-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/ranger_flight_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--ranger-redesign-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/ranger_redesign_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--rogue-mask-refinement-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/rogue_mask_refinement_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--rogue-equipment-combat-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/rogue_equipment_combat_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--rogue-equipment-upgrade-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/rogue_equipment_upgrade_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--native-primary-range-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/native_primary_range_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--rogue-roster-v235-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/rogue_roster_v235_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--rogue-roster-upgrade-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/rogue_roster_upgrade_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--rogue-design-gameplay-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/rogue_design_gameplay_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--rogue-upgrade-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/rogue_upgrade_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--rogue-combat-upgrade-test" in OS.get_cmdline_user_args() or "--rogue-combat-upgrade-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/rogue_combat_upgrade_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--movement-camera-test" in OS.get_cmdline_user_args() or "--movement-camera-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/movement_camera_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-mvp-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_mvp_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-campaign-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_campaign_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-mvp-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_mvp_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-weight-test" in OS.get_cmdline_user_args() or "--fire-siege-weight-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_weight_tour.gd" if "--fire-siege-weight-tour" in OS.get_cmdline_user_args() else "res://scripts/fire_siege_weight_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-lean-audio-tour" in OS.get_cmdline_user_args() or "--fire-siege-sound-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_lean_audio_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-lean-audio-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_lean_audio_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-motion-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_motion_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-motion-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_motion_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-art-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_art_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-turn-test" in OS.get_cmdline_user_args() or "--fire-siege-turn-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_turn_tour.gd" if "--fire-siege-turn-tour" in OS.get_cmdline_user_args() else "res://scripts/fire_siege_turn_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-compact-test" in OS.get_cmdline_user_args() or "--fire-siege-compact-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_compact_tour.gd" if "--fire-siege-compact-tour" in OS.get_cmdline_user_args() else "res://scripts/fire_siege_compact_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-controls-tour" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_controls_tour.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--fire-siege-controls-test" in OS.get_cmdline_user_args() or "--fire-siege-controls-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/fire_siege_controls_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--rogue-siege-tests" in OS.get_cmdline_user_args() or "--rogue-siege-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/rogue_siege_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--rogue-siege" in OS.get_cmdline_user_args():
		start_mode.call_deferred("defense")
	elif "--rogue-battle-test" in OS.get_cmdline_user_args() or "--rogue-battle-tests" in OS.get_cmdline_user_args() or "--rogue-battle-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/rogue_battle_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--rogue-battle" in OS.get_cmdline_user_args():
		start_mode.call_deferred("defense")
	if Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--defense-hero-")):
		smoke_test=true
		var suite=load("res://scripts/defense_hero_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--defense-dog-")):
		smoke_test=true
		var suite=load("res://scripts/defense_dog_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--defense-tactics-")):
		smoke_test=true
		var suite=load("res://scripts/defense_tactics_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--defense-fire-test" in OS.get_cmdline_user_args() or "--defense-fire-visual" in OS.get_cmdline_user_args() or "--defense-fire-benchmark" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/defense_fire_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--tower-defense-beta-test" in OS.get_cmdline_user_args() or "--tower-defense-beta-visual" in OS.get_cmdline_user_args() or "--tower-defense-beta-benchmark" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/defense_fire_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--tower-defense-test" in OS.get_cmdline_user_args() or "--tower-defense-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/tower_defense_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	elif "--tower-defense" in OS.get_cmdline_user_args():
		start_mode.call_deferred("defense")
	if "--elemental-orbs-test" in OS.get_cmdline_user_args() or "--elemental-orbs-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/elemental_orb_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--skins-test" in OS.get_cmdline_user_args() or "--skins-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/skin_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--music-settings-test" in OS.get_cmdline_user_args() or "--music-settings-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/music_settings_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--test-ren-skin" in OS.get_cmdline_user_args():player.character_models[1].apply_skin("ren")
	if "--direct-attacks-test" in OS.get_cmdline_user_args() or "--direct-attacks-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/direct_attack_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--robe-coins-test" in OS.get_cmdline_user_args() or "--robe-coins-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/robe_coin_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--attack-chain-test" in OS.get_cmdline_user_args() or "--attack-chain-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/attack_chain_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--coin-scaling-test" in OS.get_cmdline_user_args() or "--coin-scaling-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/coin_scaling_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--sky-combat-test" in OS.get_cmdline_user_args() or "--sky-combat-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/sky_combat_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--adventure-test" in OS.get_cmdline_user_args() or "--adventure-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/adventure_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--building-contact-test" in OS.get_cmdline_user_args() or "--building-contact-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/building_contact_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--destruction-test" in OS.get_cmdline_user_args() or "--destruction-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/destruction_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--map-shuffle-test" in OS.get_cmdline_user_args() or "--map-shuffle-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/map_shuffle_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--world-performance-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/world_performance_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--flight-test" in OS.get_cmdline_user_args() or "--flight-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/flight_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--district-test" in OS.get_cmdline_user_args() or "--district-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/district_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--descent-test" in OS.get_cmdline_user_args() or "--descent-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/sky_descent_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--leveling-test" in OS.get_cmdline_user_args() or "--leveling-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/leveling_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--wall-jump-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/wall_jump_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--ronin-jumps-test" in OS.get_cmdline_user_args() or "--ronin-jumps-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/ronin_jump_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--cloak-motion" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/cloak_motion_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--scarf-test" in OS.get_cmdline_user_args() or "--scarf-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/scarf_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--priority-dash-test" in OS.get_cmdline_user_args() or "--priority-dash-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/priority_dash_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--expansion-v2-test" in OS.get_cmdline_user_args() or "--expansion-v2-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/combat_expansion_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--chain-test" in OS.get_cmdline_user_args() or "--chain-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/chain_pipe_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--meteor-test" in OS.get_cmdline_user_args() or "--meteor-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/meteor_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--firecaster-test" in OS.get_cmdline_user_args() or "--firecaster-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/firecaster_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--power-combat-test" in OS.get_cmdline_user_args() or "--power-combat-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/power_combat_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--survival-test" in OS.get_cmdline_user_args() or "--survival-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/survival_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--performance-audit" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/performance_audit.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--aoe-edo-test" in OS.get_cmdline_user_args() or "--aoe-edo-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/aoe_pursuit_edo_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--sky-world-test" in OS.get_cmdline_user_args() or "--sky-world-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/sky_world_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--sound-studio-test" in OS.get_cmdline_user_args():
		var suite=load("res://scripts/sound_studio_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--smoke-test" in OS.get_cmdline_user_args():
		smoke_test=true
		run_smoke_test.call_deferred()
	if "--visual-test" in OS.get_cmdline_user_args(): visual_test.call_deferred()
	if "--expansion-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/expansion_tests.gd").new()
		suite.game=self
		add_child(suite)
		suite.call_deferred("run")
	if "--edo-test" in OS.get_cmdline_user_args() or "--edo-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/edo_features_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--controls-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/controls_density_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--musashi-test" in OS.get_cmdline_user_args() or "--musashi-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/musashi_tests.gd").new();suite.game=self;add_child(suite);suite.call_deferred("run")
	if "--combat-test" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/combat_tests.gd").new()
		suite.game=self
		add_child(suite)
		suite.call_deferred("run")
	if "--locomotion-test" in OS.get_cmdline_user_args() or "--locomotion-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/locomotion_tests.gd").new()
		suite.game=self
		add_child(suite)
		suite.call_deferred("run")
	if "--feel-test" in OS.get_cmdline_user_args() or "--feel-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/game_feel_tests.gd").new()
		suite.game=self
		add_child(suite)
		suite.call_deferred("run")
	if "--combo-test" in OS.get_cmdline_user_args() or "--combo-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/pipe_combo_tests.gd").new()
		suite.game=self
		add_child(suite)
		suite.call_deferred("run")
	if "--charge-test" in OS.get_cmdline_user_args() or "--charge-visual" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/charge_pose_tests.gd").new()
		suite.game=self
		add_child(suite)
		suite.call_deferred("run")
	if "--attack-soak" in OS.get_cmdline_user_args():
		smoke_test=true
		var suite=load("res://scripts/attack_soak_tests.gd").new()
		suite.game=self
		add_child(suite)
		suite.call_deferred("run")
	if "--asset-visual" in OS.get_cmdline_user_args():
		var suite=load("res://scripts/asset_validation.gd").new()
		suite.game=self
		add_child(suite)
		suite.call_deferred("run")
	if "--combat-visual" in OS.get_cmdline_user_args(): combat_visual.call_deferred()
	if "--area-visual-test" in OS.get_cmdline_user_args(): area_visual_test.call_deferred()

	if OS.has_feature("fire_siege") and not smoke_test:show_defense_setup.call_deferred()

func setup_inputs():
	var keys={"walk_modifier":KEY_CTRL,"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"jump":KEY_SPACE,"sprint":KEY_SHIFT,"dodge":KEY_C,"equip":KEY_E,"assist":KEY_TAB,"pause":KEY_ESCAPE,"character_toggle":KEY_Q,"weapon_pipe":KEY_1,"weapon_coin":KEY_2,"weapon_chain":KEY_3,"scarf_toggle":KEY_4,"gold_cloak":KEY_5,"interact":KEY_F,"surge":KEY_R,"sky_strike":KEY_T,"prototype_lab":KEY_F1,"shuffle_map":KEY_Y,"summon_dogs":KEY_G,"summon_heroes":KEY_H,"siege_build":KEY_B,"siege_start":KEY_Y,"siege_revive":KEY_V,"auto_attack_toggle":KEY_J}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event=InputEventKey.new()
		event.physical_keycode=keys[action]
		InputMap.action_add_event(action,event)
	for pair in [["light_attack",MOUSE_BUTTON_LEFT],["heavy_attack",MOUSE_BUTTON_RIGHT]]:
		InputMap.add_action(pair[0])
		var event=InputEventMouseButton.new()
		event.button_index=pair[1]
		InputMap.action_add_event(pair[0],event)

func setup_audio():
	for kind in ["fire_cast","fire_impact"]:sounds[kind]=load("res://assets/characters/musashi/audio/"+kind+".wav")
	for name in ["swing","heavy_swing","hit","heavy_hit","jump","land","dash","hurt","step","spark","sky_leap","sky_stomp"]:
		sounds[name]=load("res://audio/"+name+".wav")
	sounds["enemy_reaction"]=sounds["hurt"]
	sounds["environment_hit"]=sounds["hit"]
	sounds["throw"]=sounds["spark"]
	sounds["coin_hit"]=sounds["hit"]
	sounds["coin_heavy_hit"]=sounds["heavy_hit"]
	sounds["fire_loop"]=load("res://assets/characters/musashi/audio/fire_loop.wav")
	sounds["spin_swing"]=sounds["heavy_swing"]
	sounds["giant_toss"]=sounds["throw"]
	sounds["chain_throw"]=sounds["throw"]
	sounds["chain_sweep"]=sounds["heavy_swing"]
	sounds["chain_hit"]=sounds["heavy_hit"]
	sounds["chain_explosion"]=sounds["fire_impact"]
	sounds["chain_fire_sweep"]=sounds["fire_cast"]
	sounds["edo_volley"]=sounds["fire_cast"]
	sounds["edo_giant"]=sounds["fire_cast"]
	sounds["edo_shield"]=sounds["fire_cast"]
	sounds["edo_beam_start"]=sounds["fire_cast"]
	sounds["edo_beam_loop"]=sounds["fire_loop"]
	sounds["edo_meteor_cast"]=sounds["fire_cast"]
	sounds["edo_meteor_strike"]=sounds["sky_stomp"]
	sounds["edo_meteor_impact"]=sounds["fire_impact"]
	sounds["edo_dodge"]=sounds["dash"]
	sounds["edo_dodge_impact"]=sounds["fire_impact"]
	sounds["goemon_dash"]=sounds["dash"]
	sounds["goemon_dash_hit"]=sounds["hit"]
	sounds["orb_ice"]=sounds["spark"]
	sounds["orb_fire"]=sounds["fire_impact"]
	sounds["orb_magnet"]=sounds["spark"]
	for i in range(28):
		var a=AudioStreamPlayer.new()
		add_child(a)
		voices.append(a)
	music=AudioStreamPlayer.new()
	music.stream=load("res://audio/talesweaver_reminiscence.mp3")
	music.stream.loop=true
	music.volume_db=-9
	add_child(music)
	apply_music_setting()

func apply_music_setting():
	if not is_instance_valid(music):return
	if settings.music_enabled:
		if not music.playing:music.play()
		music.stream_paused=is_instance_valid(sound_library) and sound_library.recording
	else:music.stop()

func sound(kind: String,volume: float=1.0,enemy_source: bool=false):
	if not sounds.has(kind) or sound_library.recording: return
	var attack=kind in ATTACK_SOUNDS and not enemy_source
	var impact=kind in IMPACT_SOUNDS or enemy_source
	var first=0 if attack else (16 if impact else 24)
	var limit=16 if attack else (24 if impact else 28)
	var a: AudioStreamPlayer
	var oldest: AudioStreamPlayer
	var matching: Array[AudioStreamPlayer]=[]
	for i in range(first,limit):
		var candidate=voices[i]
		if not candidate.playing and a==null:a=candidate
		if oldest==null or candidate.get_meta("order",-1)<oldest.get_meta("order",-1):oldest=candidate
		if impact and candidate.playing and candidate.get_meta("kind","")==kind:matching.append(candidate)
	# Limit each impact to two overlapping voices even when a whole swarm is hit.
	if matching.size()>=2:
		a=matching[0]
		for candidate in matching:
			if candidate.get_meta("order",-1)<a.get_meta("order",-1):a=candidate
	if a==null:a=oldest
	voice_idx+=1
	last_sound_voice=a
	a.set_meta("order",voice_idx);a.set_meta("kind",kind)
	a.stream=sound_library.custom.get(kind,sounds[kind])
	a.volume_db=linear_to_db(volume*0.55*float(sound_library.gains.get(kind,1))*(0.45 if impact else 1.0))
	a.pitch_scale=1.0 if sound_library.custom.has(kind) else randf_range(0.92,1.08)
	a.play()

func active_enemy_count()->int:
	var count=0
	for i in range(enemies.size()-1,-1,-1):
		var enemy=enemies[i]
		if not is_instance_valid(enemy):enemies.remove_at(i)
		elif not enemy.dead and not enemy.is_queued_for_deletion():count+=1
	return count

func enemy_spawn_capacity()->int:
	return maxi(0,active_enemy_limit-active_enemy_count())

func spawn_enemies():
	active_enemy_limit=int(PrototypeTuning.sanitized(tuning).max_active_enemies)
	for e in enemies:
		if is_instance_valid(e):
			remove_child(e)
			e.queue_free()
	enemies.clear()
	boss_enemy=null
	if SURVIVAL_MODE:
		encounters.reset()
		return
	var spots=[Vector2(-1,21),Vector2(4,17),Vector2(-7,0),Vector2(-2,-5),Vector2(-15,-17),Vector2(-25,-10),Vector2(-44,-9),Vector2(-18,-29),Vector2(1,-31),Vector2(35,-14),Vector2(42,-22),Vector2(51,-24),Vector2(-76,-49),Vector2(-71,-54),Vector2(76,-49),Vector2(71,-54),Vector2(-37,-80),Vector2(36,-80)]
	if world is ExpeditionArea: spots=world.enemy_spawns
	spots=expanded_enemy_spots(spots)
	spots.append_array(WorldExpansion.enemy_spots(world,spots.size()))
	var saved=area_states.get(area_index,{}).get("enemies",{})
	for i in range(spots.size()+1):
		var is_boss=i==spots.size()
		var id="boss" if is_boss else str(i)
		if saved.get(id,{}).get("dead",false): continue
		if is_boss and area_cleared.get(area_index,false): continue
		# Reserve the last slot for the guardian in the dormant expedition path.
		if enemy_spawn_capacity()<=(0 if is_boss else 1):continue
		var e=Ninja.new()
		e.game=self
		e.encounter_id=id
		e.variant=0 if is_boss else i%4
		e.boss=is_boss
		e.boss_style=area_index if is_boss else 0
		var p=Vector2(45,-42) if is_boss else spots[i]
		if is_boss and world is ExpeditionArea: p=Vector2(world.boss_position.x,world.boss_position.z)
		e.position=Vector3(p.x,world.height_at(p.x,p.y)+0.15,p.y)
		if saved.has(id): e.position=saved[id].position
		e.process_mode=Node.PROCESS_MODE_PAUSABLE
		add_child(e)
		if saved.has(id):
			e.hp=saved[id].hp
			e.alerted=e.hp<e.max_hp
			e.bar.scale.x=maxf(0.01,e.hp/e.max_hp)
		enemies.append(e)
		if is_boss: boss_enemy=e
	if is_instance_valid(encounters):encounters.configure(spots)

# Preserve each original encounter, adding two spaced companions per regular enemy.
# Boss counts and stable original encounter IDs remain unchanged.
const ENCOUNTER_COPIES=3
func expanded_enemy_spots(base: Array)->Array:
	var result=base.duplicate()
	var probe=PhysicsShapeQueryParameters3D.new()
	var capsule=CapsuleShape3D.new();capsule.radius=.7;capsule.height=1.85
	probe.shape=capsule;probe.collision_mask=1
	for i in range(base.size()):
		var origin: Vector2=base[i]
		var height=world.height_at(origin.x,origin.y)
		for companion in range(1,ENCOUNTER_COPIES):
			var placed=false
			for attempt in range(256):
				var angle=attempt*2.399963+float(i+companion)*.73
				var p=origin+Vector2(cos(angle),sin(angle))*(2.1+floorf(attempt/24.0)*1.2)
				if not world.playable_bounds.grow(-3).has_point(p):continue
				var y=world.height_at(p.x,p.y)
				if y<0 or absf(y-height)>1.2:continue
				var separated=true
				for other in result:
					if p.distance_to(other)<1.55:separated=false;break
				if not separated:continue
				probe.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,y+1.2,p.y))
				if not get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty():continue
				result.append(p);placed=true;break
			if not placed:push_error("No safe companion spawn for encounter "+str(i))
	return result

func clear_menu():
	if is_instance_valid(kennel):kennel.menu_open=false
	if is_instance_valid(barracks):barracks.menu_open=false
	if is_instance_valid(sound_library): sound_library.cancel()
	if is_instance_valid(menu):
		menu.queue_free()
		menu=null

func label_at(parent: Control,words: String,p: Vector2,font_size: int,color: Color=Color("f5efdb"))->Label:
	var l=Label.new()
	l.text=words
	l.position=p
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	parent.add_child(l)
	return l

func button_at(parent: Control,words: String,p: Vector2,action: Callable,width: float=300)->Button:
	var b=Button.new()
	b.text=words
	b.position=p
	b.size=Vector2(width,52)
	b.add_theme_font_size_override("font_size",19)
	var normal=StyleBoxFlat.new()
	normal.bg_color=Color(0.04,0.14,0.18,0.90)
	normal.border_color=Color("8d9e8d")
	normal.border_width_left=2
	normal.content_margin_left=20
	var hover=normal.duplicate()
	hover.bg_color=Color("c5974e")
	hover.border_color=Color("ffe0a2")
	b.add_theme_stylebox_override("normal",normal)
	b.add_theme_stylebox_override("hover",hover)
	b.add_theme_stylebox_override("pressed",hover)
	b.add_theme_stylebox_override("focus",hover)
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func menu_base()->Control:
	if is_fire_siege():encounters.interrupt_inputs()
	clear_menu()
	menu=Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var bg=ColorRect.new()
	bg.color=Color(0.015,0.06,0.10,0.65 if playing else 0.38)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu.add_child(bg)
	return menu

func show_main_menu():
	player.reset_auto_attack()
	custom_map_data.clear()
	rogue_roster_open=false;rogue_pick_start=false
	var restore_hero=rogue_roster_mode or player.is_rogue_character()
	rogue_roster_mode=false
	if restore_hero:player.select_character(rogue_original_character)
	restore_defense_settings()
	rogue_battle_mode=false
	if is_instance_valid(rogue_view):rogue_view.set_enabled(false)
	if is_instance_valid(rogue_feedback):rogue_feedback.set_enabled(false)
	if is_instance_valid(kennel):kennel.reset()
	if is_instance_valid(barracks):barracks.reset()
	if is_instance_valid(adventure):adventure.reset()
	player.cancel_charge()
	player.end_surge()
	player.clear_powerups()
	if is_instance_valid(orb_system):orb_system.reset()
	if transitioning: return
	if area_index!=0: rebuild_area(0)
	get_tree().paused=false
	paused=false
	playing=false
	won=false
	encounters.reset()
	crowd.clear()
	for enemy in enemies:
		if is_instance_valid(enemy):enemy.hide()
	Engine.time_scale=1
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	player.visible=true
	player.model.visible=true
	player.position=Vector3(1,world.height_at(1,38),38)
	player.buildings_broken=0
	player.scale=Vector3.ONE*1.65
	player.model.rotation.y=PI+0.4
	camera_rig.camera.position=Vector3(8,5.8,47)
	camera_rig.camera.look_at(Vector3(-2,2.6,35))
	camera_rig.camera.fov=56
	if descent_mode:
		var top=world.sky_islands.islands[0]
		player.position=top+Vector3(0,.12,3.8)
		camera_rig.camera.global_position=top+Vector3(24,17,28)
		camera_rig.camera.look_at(top+Vector3(0,-5,0))
		world.sky_islands.highlight(0)
	elif tower_defense_mode:
		player.position=world.spawn_point
		camera_rig.camera.global_position=Vector3(95,145,120) if defense_beta else Vector3(225,170,120)
		camera_rig.camera.look_at(Vector3(0,0,-80))
	var root=menu_base()
	label_at(root,"S K Y   A B O V E .   S T A N D   Y O U R   G R O U N D .",Vector2(74,108),15,Color("f4d38b"))
	label_at(root,"GOEMON",Vector2(68,150),76)
	label_at(root,"C H O O S E   Y O U R   A D V E N T U R E",Vector2(76,345),20,Color("f4d38b"))
	label_at(root,"Your heroes. Your world. Choose how you battle.",Vector2(76,393),20)
	var primary_mode="survival" if "--legacy-survival" in OS.get_cmdline_user_args() else "descent"
	button_at(root,"PLAY  /  Sky Descent" if primary_mode=="descent" else "PLAY  /  Swarm Survival",Vector2(76,456),start_mode.bind(primary_mode),460).grab_focus()
	label_at(root,"784 islands · Explore, fly, and descend to Tidefall" if primary_mode=="descent" else "Ten minutes · Growing enemy swarms",Vector2(88,519),16,Color("d8e6df"))
	var defense_button=button_at(root,"TOWER DEFENSE  /  Fire Siege" if defense_beta else "TOWER DEFENSE  /  Three Gates",Vector2(76,572),show_defense_setup if defense_beta else start_mode.bind("defense"),460)
	defense_button.name="TowerDefenseButton"
	label_at(root,"10 waves · Upgrade cards · Dogs and character summons" if defense_beta else "Three lanes · Earn gold · Build cannons · Hold the shrine",Vector2(88,635),16,Color("d8e6df"))
	label_at(root,"FIRE SIEGE · 12 PLAYABLE HEROES",Vector2(650,480),24,Color("f1d390"))
	label_at(root,"Original camera · Shared controls · Native hero skills",Vector2(650,529),17)
	var builder_button=button_at(root,"BUILD YOUR OWN MAP",Vector2(650,583),open_map_editor,390)
	builder_button.name="MapBuilderButton"
	label_at(root,"Place pieces · Draw routes · Save & play",Vector2(662,646),17,Color("d8e6df"))
	button_at(root,"Settings",Vector2(76,706),func(): show_settings(false),220)
	button_at(root,"Quit",Vector2(312,706),quit_clean,224)
	label_at(root,"PROCEDURAL WORLD  /  ORIGINAL CHARACTER  /  GODOT 4",Vector2(76,822),12,Color("c4d6d2"))
	label_at(root,"SKY DESCENT   /   FIRE SIEGE" if defense_beta else "SKY DESCENT   /   THREE GATES",Vector2(1030,825),14,Color("efd297"))

func show_defense_setup(rogue: bool=false):
	var root=menu_base()
	label_at(root,"ROGUE SIEGE" if rogue else "FIRE SIEGE",Vector2(92,150),58)
	label_at(root,"Choose your defense challenge",Vector2(96,230),25,Color("f1d390"))
	label_at(root,"Pick one of three cards before every wave. Your build lasts the run." if rogue else "Build your defense. Fight beside it. Survive ten waves.",Vector2(96,282),21)
	label_at(root,"Ice shells · Fire paths · Armored enemies · Bosses on waves 5 and 10" if rogue else "Stand nearby to build · Hold Y for 3 seconds to start each wave",Vector2(96,321),18,Color("b9d7da"))
	button_at(root,"BETA  /  Full battery" if rogue else "BETA  /  Build & defend",Vector2(96,398),start_rogue_defense.bind(false) if rogue else choose_defense_hero.bind(false),500).grab_focus()
	label_at(root,"2 walls · 8 defenses · 12,000 gold · 100 shrine integrity" if rogue else "12 empty sites · 10 gold · 100 integrity · Revive Now available",Vector2(108,461),18,Color("cddad6"))
	button_at(root,"HARD  /  Build your defense",Vector2(96,524),start_rogue_defense.bind(true) if rogue else choose_defense_hero.bind(true),500)
	label_at(root,"4 defenses · 650 gold · 50 shrine integrity" if rogue else "12 empty sites · 10 gold · 50 integrity · 5-second revival",Vector2(108,587),18,Color("cddad6"))
	label_at(root,"G · Summon dogs   /   H · Summon characters from the castle" if rogue else "Arrow tower 5 gold · Mine 10 gold · Unlimited preparation",Vector2(108,640),18,Color("a1e2d7"))
	if rogue:
		label_at(root,"ROGUE COMBAT",Vector2(720,405),26,Color("f1d390"))
		label_at(root,"Play Goemon or any of the ten Rogue fighters.",Vector2(720,456),19)
		label_at(root,"Mouse aim · LMB / RMB attacks",Vector2(720,499),18)
		label_at(root,"C / E utility · R skill · Q change fighter",Vector2(720,533),18)
		label_at(root,"Same siege, defenses, cards, and allied squads.",Vector2(720,585),18,Color("a1e2d7"))
	button_at(root,"Back",Vector2(96,710),show_main_menu,240)

func start_defense(hard: bool=false):
	defense_hard=hard
	start_mode("defense")

func choose_defense_hero(hard: bool=false):
	defense_hard=hard
	roster_start_mode="defense"
	show_rogue_roster(true)

func start_rogue_defense(hard: bool=false):
	roster_start_mode="rogue_defense"
	defense_hard=hard
	show_rogue_roster(true)

func show_rogue_roster(starting: bool=false):
	if not starting and (not rogue_roster_mode or not playing or won or player.hp<=0 or transitioning):return
	if not starting:
		player.cancel_charge(true);Engine.time_scale=1
		paused=true;get_tree().paused=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var root=menu_base()
	rogue_roster_open=true;rogue_pick_start=starting
	var picker=load("res://scripts/rogue_roster_picker.gd").new()
	picker.game=self;root.add_child(picker)

func choose_rogue_character(id: int):
	if not rogue_roster_open or (id not in [1,2] and not player.RogueRoster.is_rogue(id)):return
	selected_rogue_id=id
	var starting=rogue_pick_start
	rogue_roster_open=false;rogue_pick_start=false
	if starting:start_mode(roster_start_mode)
	else:
		player.select_character(id)
		resume()

func close_rogue_roster():
	var starting=rogue_pick_start
	rogue_roster_open=false;rogue_pick_start=false
	if starting:show_defense_setup(roster_start_mode=="rogue_defense")
	else:resume()

func defense_drafting()->bool:
	return tower_defense_mode and playing and is_instance_valid(encounters) and encounters.get("phase")=="draft"

func show_defense_cards():
	if not defense_drafting():return
	player.cancel_charge(true);Engine.time_scale=1
	paused=true;get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var root=menu_base()
	var picker=load("res://scripts/defense_card_picker.gd").new()
	picker.game=self;picker.director=encounters;root.add_child(picker)

func show_dog_roster():
	if not tower_defense_mode or not defense_beta or not playing or won or transitioning:return
	if paused and not (kennel.menu_open or barracks.menu_open):return
	if player.hp<=0 or encounters.base_hp<=0 or defense_drafting():return
	player.cancel_charge(true);Engine.time_scale=1
	paused=true;get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var root=menu_base()
	kennel.menu_open=true
	var picker=load("res://scripts/defense_dog_picker.gd").new()
	picker.game=self;root.add_child(picker)

func close_dog_roster():
	if not is_instance_valid(kennel) or not kennel.menu_open:return
	kennel.menu_open=false
	resume()

func summon_defense_dog(id: String):
	if not is_instance_valid(kennel) or not kennel.menu_open:return
	if not kennel.summon(id):return
	var dog=DefenseDogCatalog.get_dog(id)
	kennel.menu_open=false
	resume()
	toast("%s summoned · Leaving the castle" % dog.name)

func show_hero_roster():
	if not tower_defense_mode or not defense_beta or not playing or won or transitioning:return
	if paused and not (kennel.menu_open or barracks.menu_open):return
	if player.hp<=0 or encounters.base_hp<=0 or defense_drafting():return
	player.cancel_charge(true);Engine.time_scale=1
	paused=true;get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var root=menu_base()
	barracks.menu_open=true
	var picker=load("res://scripts/defense_hero_picker.gd").new()
	picker.game=self;root.add_child(picker)

func close_hero_roster():
	if not is_instance_valid(barracks) or not barracks.menu_open:return
	barracks.menu_open=false
	resume()

func summon_defense_hero(id: String):
	if not is_instance_valid(barracks) or not barracks.menu_open:return
	if not barracks.summon(id):return
	var hero=DefenseHeroCatalog.get_hero(id)
	barracks.menu_open=false
	resume()
	toast("%s summoned · Leaving the castle" % hero.name)

func start_mode(mode: String):
	if not launching_custom_map:custom_map_data.clear()
	if transitioning or mode not in ["descent","defense","survival","rogue","rogue_defense"]:return
	var was_rogue_roster=rogue_roster_mode
	if mode!="rogue_defense":restore_defense_settings()
	rogue_view.set_enabled(false)
	rogue_feedback.set_enabled(false)
	rogue_roster_open=false;rogue_pick_start=false
	rogue_roster_mode=mode=="rogue_defense" or (mode=="defense" and defense_beta)
	rogue_battle_mode=mode in ["rogue","rogue_defense"]
	# Stop the outgoing director before replacing its world and collision bodies.
	playing=false
	if is_instance_valid(kennel):kennel.reset()
	if is_instance_valid(barracks):barracks.reset()
	encounters.reset()
	encounters.set_physics_process(false)
	remove_child(encounters)
	encounters.queue_free()
	tower_defense_mode=mode in ["defense","rogue_defense"]
	descent_mode=mode in ["descent","rogue"]
	if rogue_roster_mode:
		if rogue_defense_settings.is_empty():rogue_defense_settings={"beta":defense_beta,"tactics":defense_tactics,"soft_target":player.soft_target}
		if not was_rogue_roster and player.ROSTER.has(player.character_id):rogue_original_character=player.character_id
		if mode=="rogue_defense":defense_beta=true;defense_tactics=true
		player.select_character(selected_rogue_id)
	elif was_rogue_roster or player.is_rogue_character():player.select_character(rogue_original_character)
	encounters=load("res://scripts/fire_siege.gd" if mode=="defense" and defense_beta else "res://scripts/tower_defense.gd").new() if tower_defense_mode else (preload("res://scripts/sky_descent.gd").new() if descent_mode else SwarmSurvival.new())
	if tower_defense_mode:
		encounters.beta_mode=defense_beta;encounters.tactics_enabled=defense_tactics;encounters.hard_mode=defense_hard
	encounters.game=self
	add_child(encounters)
	camera_rig.camera.far=3200 if descent_mode else 1400
	start_game()

func restore_defense_settings():
	if rogue_defense_settings.is_empty():return
	defense_beta=rogue_defense_settings.beta;defense_tactics=rogue_defense_settings.tactics
	player.soft_target=rogue_defense_settings.get("soft_target",true)
	rogue_defense_settings.clear()

func start_game(seed_override: int=-1):
	if transitioning:return
	player.reset_auto_attack()
	rogue_feedback.clear()
	adventure.reset()
	player.run_upgrades={"damage":0,"vitality":0,"tempo":0}
	player.attack_chain.reset()
	player.buildings_broken=0
	player.scale=Vector3.ONE
	player.cancel_charge()
	player.end_surge()
	player.clear_powerups()
	run_seed=seed_override if seed_override>=0 else (90824 if smoke_test else int(Time.get_ticks_usec())%2147483647)
	area_states.clear()
	area_cleared.clear()
	rebuild_area(0)
	clear_menu()
	get_tree().paused=false
	paused=false
	playing=true
	won=false
	boss_active=false
	kills=0
	player.progression.reset(descent_mode)
	chain=0
	sparks=0
	for mote in world.motes:
		if is_instance_valid(mote): mote.show()
	zone_seen.clear()
	checkpoint=Vector3(0,world.height_at(0,41)+0.3,41)
	player.scale=Vector3.ONE
	player.position=checkpoint
	player.velocity=Vector3.ZERO
	player.model.charge_requested=false
	player.model.charge_release=-1.0
	player.model.charge_pose_weight=0
	player.model.locomotion.reset()
	player.refresh_max_health()
	player.hp=player.max_hp
	player.invuln=0
	player.dodge_time=0
	player.dodge_cooldown=0
	player.impact_pause=0
	player.jump_windup=0
	player.heavy_buffer=0
	player.jump_buffer=0
	player.reset_wall_jump()
	player.coyote=0
	player.combo_window=0
	player.combo=0
	player.jumps_used=0
	player.air_turn=0
	player.weapon_slot=1
	player.character_models[1].chain_selected=false
	player.character_models[1].chain_pipe.hide()
	if is_instance_valid(player.musashi):
		player.musashi.shield_cooldown=0
		player.musashi.ranged_mode=true
	player.model.coin.visible=false
	hit_stop=0
	Engine.time_scale=1
	player.attack_left=0
	player.queued=false
	player.model.visible=true
	player.model.equipped=true
	player.facing=Vector3.FORWARD
	player.model.rotation=Vector3.ZERO
	for id in player.character_abilities:
		if player.RogueRoster.is_rogue(id):player.character_abilities[id].reset_run()
	camera_rig.yaw=0
	camera_rig.pitch=ActionCamera.CROSSHAIR_DEFAULT_PITCH if crosshair_aim_enabled() else .36
	camera_rig.distance=ActionCamera.CROSSHAIR_DEFAULT_DISTANCE if crosshair_aim_enabled() else 14.0
	camera_rig.reset_follow()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if rogue_battle_mode else Input.MOUSE_MODE_CAPTURED
	encounters.begin()
	kennel.begin()
	barracks.begin()
	orb_system.begin()
	rogue_view.set_enabled(rogue_battle_mode)
	if rogue_battle_mode:rogue_view.reset()
	rogue_feedback.set_enabled(rogue_battle_mode)
	if camera_combat():
		player.soft_target=false
		toast("FIRE SIEGE · Stand nearby to build · Hold Y to start · Q Heroes · G / H Allies" if is_fire_siege() else "FIRE SIEGE · Camera-facing combat · Q Heroes · C Evade · E Utility · F Towers · G / H Allies")
		return
	if rogue_roster_mode:
		toast("ROGUE SIEGE · Q Fighters · C Evade / E Dash · R Surge · F Upgrade · G / H Allies" if player.character_id==1 else "ROGUE SIEGE · Q Fighters · C / E Utility · R Skill · F Upgrade · G / H Allies")
		return
	if rogue_battle_mode:
		toast("ROGUE BATTLE · Mouse aim · Hold LMB combo · RMB heavy · C evade")
		return
	toast(("Choose a card · F build / upgrade · G dogs · H characters" if defense_beta else "F at a wall mount · Buy cannons · Defend all three lanes") if tower_defense_mode else ("Choose any island · Stand on clouds · Drop freely · Y new map" if descent_mode else "Survive 10 minutes · Waves grow by 10 enemies each minute · C Evade"))

func shuffle_map():
	if transitioning:return
	# Defer reconstruction out of input/physics callbacks and ignore key repeat.
	transitioning=true
	var root=menu_base()
	label_at(root,"GENERATING A NEW MAP…",Vector2(92,260),36)
	label_at(root,"Fresh islands, towns and encounters",Vector2(96,323),20,Color("dfc384"))
	call_deferred("finish_map_shuffle")

func finish_map_shuffle():
	# Allow the loading message to render before rebuilding scene geometry.
	await get_tree().process_frame
	await get_tree().process_frame
	var next_seed=(run_seed+104729+int(Time.get_ticks_usec())%1000000)%2147483647
	transitioning=false
	start_game(next_seed)
	toast("NEW MAP · Fresh descent · Y shuffle / Esc restart this map")

func _unhandled_input(event):
	if event.is_action_released("interact"):_siege_interact_held=false
	if is_instance_valid(map_editor):return
	if transitioning: return
	if is_fire_siege() and playing and not paused and event.is_action_pressed("siege_revive") and not event.is_echo():
		encounters.revive_now();get_viewport().set_input_as_handled();return
	if rogue_roster_mode and playing and event.is_action_pressed("character_toggle") and not event.is_echo():
		if rogue_roster_open:close_rogue_roster()
		else:show_rogue_roster()
		get_viewport().set_input_as_handled();return
	if event.is_action_pressed("summon_dogs") and not event.is_echo() and tower_defense_mode and defense_beta and playing:
		if not paused:show_dog_roster()
		get_viewport().set_input_as_handled();return
	if event.is_action_pressed("summon_heroes") and not event.is_echo() and tower_defense_mode and defense_beta and playing:
		if not paused:show_hero_roster()
		get_viewport().set_input_as_handled();return
	if tower_defense_mode and playing and encounters.base_hp<=0:return
	if defense_drafting() and event.is_action_pressed("prototype_lab"):
		get_viewport().set_input_as_handled();return
	if defense_drafting() and event.is_action_pressed("pause"):
		if is_instance_valid(menu) and menu.find_child("DefenseCard_0",true,false)!=null:show_pause()
		else:show_defense_cards()
		get_viewport().set_input_as_handled();return
	if event.is_action_pressed("shuffle_map") and descent_mode and playing:
		shuffle_map();get_viewport().set_input_as_handled();return
	if event.is_action_pressed("prototype_lab") and playing and player.hp>0 and not won:
		if paused: resume()
		else: show_lab()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact") and playing and not paused:
		if is_fire_siege():
			if event.is_echo() or _siege_interact_held:return
			_siege_interact_held=true
		if tower_defense_mode:
			encounters.try_purchase();get_viewport().set_input_as_handled()
		elif not adventure.pending_rewards.is_empty():adventure.show_choices()
		else:use_nearby_gate()
	if event.is_action_pressed("pause") and playing and (player.hp>0 or is_fire_siege()) and not won:
		if paused: resume()
		else: show_pause()
		get_viewport().set_input_as_handled()

func show_pause():
	player.cancel_charge(true)
	player.model.visible=true
	paused=true
	get_tree().paused=true
	Engine.time_scale=1
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var root=menu_base()
	label_at(root,"TAKE A BREATH",Vector2(92,160),43)
	label_at(root,"Waves, construction, income and revival are paused." if is_fire_siege() else "Waves, cannons, and the shrine are paused." if tower_defense_mode else ("Your descent and island encounters are paused." if descent_mode else "Countdown and enemy waves are paused."),Vector2(94,220),19,Color("dfc384"))
	if not defense_drafting():button_at(root,"F1 · Prototype Lab",Vector2(470,304),show_lab,340)
	if rogue_roster_mode:button_at(root,"Q · Choose hero",Vector2(470,367),show_rogue_roster,380)
	if descent_mode:
		button_at(root,"Y · Shuffle map + new run",Vector2(470,367),shuffle_map,380)
		label_at(root,"Map seed: %d" % run_seed,Vector2(474,437),16,Color("dfc384"))
	button_at(root,"Resume",Vector2(96,304),resume).grab_focus()
	button_at(root,"Settings",Vector2(96,367),func(): show_settings(true))
	button_at(root,"Restart Rogue Siege" if rogue_roster_mode and rogue_battle_mode else ("Restart Rogue Battle" if rogue_battle_mode else ("Restart defense" if tower_defense_mode else ("Restart descent" if descent_mode else "Restart survival"))),Vector2(96,430),restart_area)
	if not custom_map_data.is_empty():
		var edit_button=button_at(root,"Return to map builder",Vector2(470,430),open_map_editor,380)
		edit_button.name="ReturnToMapBuilder"
	button_at(root,"Main menu",Vector2(96,493),show_main_menu)
	button_at(root,"Quit",Vector2(96,556),quit_clean)

func resume():
	if won or (player.hp<=0 and not is_fire_siege()):return
	if tower_defense_mode and encounters.base_hp<=0:return
	rogue_roster_open=false;rogue_pick_start=false
	if defense_drafting():show_defense_cards();return
	adventure.choosing=false
	clear_menu()
	paused=false
	get_tree().paused=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if rogue_battle_mode or (is_fire_siege() and player.hp<=0) else Input.MOUSE_MODE_CAPTURED

func show_settings(from_pause: bool):
	var root=menu_base()
	label_at(root,"SETTINGS",Vector2(92,145),43)
	label_at(root,"Tune your adventure",Vector2(96,209),19,Color("dfc384"))
	label_at(root,"Master volume",Vector2(96,283),20)
	var volume=HSlider.new()
	volume.position=Vector2(340,288)
	volume.size=Vector2(290,30)
	volume.min_value=0
	volume.max_value=1
	volume.step=0.01
	volume.value=settings.volume
	root.add_child(volume)
	volume.value_changed.connect(func(v): settings.volume=v; AudioServer.set_bus_volume_db(0,linear_to_db(v)); save_settings())
	var background_music=CheckButton.new()
	background_music.name="BackgroundMusicToggle"
	background_music.text="Background music"
	background_music.position=Vector2(96,340)
	background_music.button_pressed=settings.music_enabled
	background_music.add_theme_font_size_override("font_size",20)
	root.add_child(background_music)
	background_music.toggled.connect(func(enabled):settings.music_enabled=enabled;apply_music_setting();save_settings())
	label_at(root,"Mouse sensitivity",Vector2(96,409),20)
	var sensitivity=HSlider.new()
	sensitivity.position=Vector2(340,414)
	sensitivity.size=Vector2(290,30)
	sensitivity.min_value=0.25
	sensitivity.max_value=2.5
	sensitivity.step=0.05
	sensitivity.value=settings.sensitivity
	root.add_child(sensitivity)
	sensitivity.value_changed.connect(func(v): settings.sensitivity=v; camera_rig.sens=v; save_settings())
	var full=CheckButton.new()
	full.text="Fullscreen"
	full.position=Vector2(96,476)
	full.button_pressed=settings.fullscreen
	full.add_theme_font_size_override("font_size",20)
	root.add_child(full)
	full.toggled.connect(func(v): settings.fullscreen=v; DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED); save_settings())
	label_at(root,"Graphics",Vector2(96,551),20)
	var options=OptionButton.new()
	options.position=Vector2(340,544)
	options.size=Vector2(290,44)
	options.add_item("Performance · no shadows")
	options.add_item("High · shadows + 2× MSAA")
	options.add_item("Ultra · shadows + 4× MSAA")
	options.selected=settings.quality
	root.add_child(options)
	options.item_selected.connect(func(v): settings.quality=v; apply_quality(); save_settings())
	button_at(root,"Playable skins · Choose your look",Vector2(710,211),func(): show_skin_picker(from_pause),480).name="PlayableSkinsButton"
	button_at(root,"Sound Studio · Record sounds",Vector2(710,351),func(): show_sound_studio(from_pause),480)
	if from_pause: button_at(root,"Prototype Lab · Gameplay tuning",Vector2(710,283),show_lab,400)
	label_at(root,"EDO · FIRE BEAM",Vector2(710,437),22,Color("dfc384"))
	for i in range(PrototypeTuning.BEAM_ROWS.size()):
		var row=PrototypeTuning.BEAM_ROWS[i]
		label_at(root,row[1],Vector2(710,488+i*58),18)
		var spin=SpinBox.new();spin.position=Vector2(1030,480+i*58);spin.size=Vector2(160,40)
		spin.min_value=row[2];spin.max_value=row[3];spin.step=row[4];spin.value=tuning[row[0]]
		root.add_child(spin);spin.value_changed.connect(func(v):update_tuning(row[0],v))
	label_at(root,"Hold T to sustain · Release T to stop",Vector2(710,673),15)
	button_at(root,"Back",Vector2(96,650),show_pause if from_pause else show_main_menu)

func show_skin_picker(from_pause: bool):
	var root=menu_base()
	var picker=preload("res://scripts/skin_picker.gd").new()
	picker.name="SkinPicker";picker.game=self;picker.from_pause=from_pause;root.add_child(picker)

func select_goemon_skin(id: String):
	settings.goemon_skin=HeroSkins.valid_id(id)
	player.character_models[1].apply_skin(settings.goemon_skin)
	save_settings()

func show_sound_studio(from_pause: bool):
	var root=menu_base()
	var studio=SoundStudio.new();studio.game=self;studio.from_pause=from_pause;root.add_child(studio)

func load_settings():
	var c=ConfigFile.new()
	settings=DEFAULT_SETTINGS.duplicate()
	if c.load(settings_path)==OK:
		for k in settings: settings[k]=c.get_value("settings",k,DEFAULT_SETTINGS[k])
		for k in tuning: tuning[k]=c.get_value("prototype",k,tuning[k])
		tuning=PrototypeTuning.sanitized(tuning)
	# Debug freeze belongs to this session, never the next playable launch.
	tuning.freeze_ai=false
	settings.goemon_skin=HeroSkins.valid_id(settings.goemon_skin)
	if is_instance_valid(player):player.character_models[1].apply_skin(settings.goemon_skin)
	AudioServer.set_bus_volume_db(0,linear_to_db(settings.volume))
	apply_music_setting()
	if settings.fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	apply_quality.call_deferred()

func save_settings():
	var c=ConfigFile.new()
	for k in settings: c.set_value("settings",k,settings[k])
	for k in tuning: c.set_value("prototype",k,false if k=="freeze_ai" else tuning[k])
	c.save(settings_path)

func apply_quality():
	var combat_fx=get_node_or_null("RogueSharedClassEffects")
	if combat_fx:combat_fx.apply_quality(settings.quality)
	get_viewport().msaa_3d=Viewport.MSAA_DISABLED if settings.quality==0 else (Viewport.MSAA_2X if settings.quality==1 else Viewport.MSAA_4X)
	if is_instance_valid(world):
		for n in world.get_children():
			if n is DirectionalLight3D: n.shadow_enabled=settings.quality>0
			if n is WorldEnvironment:
				n.environment.ssao_enabled=settings.quality>0
				n.environment.glow_enabled=settings.quality>0
		var spirit=world.get_node_or_null("SpiritFortressEffects")
		if spirit:spirit.apply_quality(settings.quality)

func toast(words: String):
	hud.toast_text=words
	hud.toast_time=3.8

func boss_intro():
	boss_active=true
	hud.banner=BOSS_NAMES[area_index].to_upper()+" · AREA GUARDIAN"
	hud.banner_time=3.5
	toast(["Evade the red tell, then counter.","Hisui throws crystal fans. Close in or use gold coins.","Hanami sends ground waves. Double jump over them.","Akagane mixes dash slashes, crystal fans and ground waves."][area_index])

func victory():
	if SURVIVAL_MODE:return
	area_cleared[area_index]=true
	won=area_cleared.size()==AREA_NAMES.size()
	boss_active=false
	hud.banner="ALL FOUR SEALS RESTORED" if won else BOSS_NAMES[area_index].to_upper()+" DEFEATED"
	hud.banner_time=6
	toast("Expedition complete · Return through any door to explore" if won else ("Guardian defeated · Doors remain open; F to travel" if area_index<3 else "Return through the entrance to finish remaining guardians"))
	player.refresh_max_health()
	player.hp=player.max_hp
	for gate in gates: gate.refresh()
	sound("spark")

func survival_victory():
	if won or player.hp<=0:return
	won=true
	encounters.active=false
	player.cancel_charge()
	player.end_surge()
	paused=true
	get_tree().paused=true
	Engine.time_scale=1
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var root=menu_base()
	label_at(root,"SANCTUARY SURVIVED",Vector2(92,230),42)
	label_at(root,"10:00 survived · %d waves · %d enemies defeated" % [encounters.wave,kills],Vector2(96,296),20,Color("e6cf97"))
	button_at(root,"Play again",Vector2(96,380),start_game).grab_focus()
	button_at(root,"Main menu",Vector2(96,449),show_main_menu)
	sound("spark")

func defense_victory():
	if won or (player.hp<=0 and not is_fire_siege()) or encounters.base_hp<=0:return
	if is_instance_valid(kennel):kennel.reset()
	if is_instance_valid(barracks):barracks.reset()
	won=true;encounters.active=false
	if is_fire_siege():
		encounters.runtime.revive_left=0;clear_siege_projectiles()
	player.cancel_charge();player.end_surge()
	paused=true;get_tree().paused=true;Engine.time_scale=1
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var root=menu_base()
	label_at(root,"ALL TEN WAVES DEFEATED",Vector2(92,230),42)
	label_at(root,"%d defeated · %d breached · Shrine %d / %d" % [encounters.run_kills,encounters.run_breaches,encounters.base_hp,encounters.base_max_hp],Vector2(96,296),20,Color("e6cf97"))
	label_at(root,("%s cleared · %.2f gold · Final wave reward +100 paid" % ["Hard" if encounters.hard_mode else "Beta",encounters.money]) if is_fire_siege() else ("%s cleared · %d upgrade cards chosen" % ["Hard mode" if encounters.hard_mode else "Beta",encounters.card_history.size()]) if encounters.tactics_enabled else "Fire Siege complete. Try another defense setup.",Vector2(96,336),18)
	button_at(root,"Restart Fire Siege",Vector2(96,400),restart_area,350).grab_focus()
	button_at(root,"Main menu",Vector2(96,469),show_main_menu,350)
	sound("spark")

func defeat():
	if is_fire_siege() and encounters.base_hp>0 and playing and not won:
		encounters.hero_died()
		return
	if is_fire_siege():
		encounters.phase="defeat";encounters.runtime.revive_left=0
		encounters.interrupt_inputs();encounters.retire_wave_effects()
		clear_siege_projectiles()
	if is_instance_valid(kennel):kennel.reset()
	if is_instance_valid(barracks):barracks.reset()
	player.quick_attacks.stop_coins()
	player.attack_chain.reset()
	encounters.active=false
	player.cancel_charge()
	paused=true
	get_tree().paused=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var root=menu_base()
	label_at(root,"THE SHRINE HAS FALLEN" if tower_defense_mode and encounters.base_hp<=0 else "A SPARK NEVER FADES",Vector2(92,230),42)
	var result="Wave %d · %d defeated · %d gold remaining" % [encounters.wave,kills,encounters.money] if tower_defense_mode else ("Island %d / %d · Level %d · %d defeated" % [encounters.current_island+1,world.sky_islands.COUNT,player.progression.level,kills] if descent_mode else "Survived %s · Wave %d · %d defeated" % [encounters.clock_text(encounters.elapsed),encounters.wave,kills])
	label_at(root,result,Vector2(96,296),20,Color("e6cf97"))
	button_at(root,"Try again",Vector2(96,380),restart_area).grab_focus()
	button_at(root,"Main menu",Vector2(96,449),show_main_menu)

func _process(delta):
	if transitioning: return
	if not playing:
		if is_instance_valid(player.model): player.model.animate(delta,0,true,0,0,false,0,false)
		return
	if paused: return
	portal_hint=""
	if tower_defense_mode:portal_hint=encounters.interaction_prompt()
	for gate in gates:
		if player.position.distance_to(gate.position)<AreaGate.INTERACTION_RADIUS: portal_hint=gate.prompt()
	hit_stop=maxf(0,hit_stop-delta) # Compatibility/debug meter; no global time dilation.
	chain_timer-=delta
	if chain_timer<=0: chain=0
	for key in world.landmarks:
		var p=world.landmarks[key]
		if absf(player.position.y-world.height_at(p.x,p.z))<8 and Vector2(player.position.x-p.x,player.position.z-p.z).length()<12 and not zone_seen.has(key):
			zone_seen[key]=true
			hud.banner=key
			hud.banner_time=3.5
			if key=="TIDEFALL TEMPLE":
				checkpoint=Vector3(-10,world.height_at(-10,-23)+0.5,-23)
				player.hp=minf(player.max_hp,player.hp+30)
				toast("Temple sanctuary reached · Vitality restored")
	for mote in world.motes:
		if is_instance_valid(mote) and mote.visible and player.position.distance_to(mote.position)<1.8:
			burst(mote.position,Color("ffe59c"),6)
			mote.hide()
			sparks+=1
			player.hp=minf(player.max_hp,player.hp+2)
			sound("spark",0.65)

func burst(p: Vector3,color: Color,count: int,scale_factor: float=1.0):
	var frame=Engine.get_physics_frames()
	if burst_feedback_frame!=frame:
		burst_feedback_frame=frame;burst_sparks_this_frame=0
	var quality=clampi(int(settings.quality),0,2)
	var admitted=mini(count,mini([12,24,36][quality]-burst_sparks_this_frame,[48,96,144][quality]-burst_sparks_live))
	if admitted<=0:return
	burst_sparks_this_frame+=admitted
	for i in range(admitted):
		var n=Geo.sphere(self,p+Vector3(randf_range(-0.2,0.2),0.15,randf_range(-0.2,0.2)),Vector3.ONE*randf_range(0.07,0.15)*scale_factor,Geo.mat(color.to_html(),0,0.2))
		n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		burst_sparks_live+=1
		n.tree_exited.connect(func():burst_sparks_live-=1,CONNECT_ONE_SHOT)
		var tween=create_tween().set_parallel(true)
		tween.tween_property(n,"position",p+Vector3(randf_range(-1.5,1.5),randf_range(0.3,1.8),randf_range(-1.5,1.5))*scale_factor,0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(n,"scale",Vector3.ONE*0.005,0.42)
		tween.chain().tween_callback(n.queue_free)

func wind(p: Vector3,dir: Vector3):
	var n=Geo.beam(self,p-dir*0.5,p+dir*1.8,0.018,Geo.mat("d2f1e6",0,0.3))
	var t=create_tween().set_parallel(true)
	t.tween_property(n,"scale",Vector3.ONE*0.01,0.24)
	t.chain().tween_callback(n.queue_free)

func slash(p: Vector3,dir: Vector3,heavy: bool,combo: int,color: Color=Color("ffdf83"),size_multiplier: float=1.0,plane: float=9.0):
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius=(3.1 if heavy else 2.3)*size_multiplier
	for i in range(20):
		var a=-1.55+i*3.1/20
		var b=-1.55+(i+1)*3.1/20
		for v in [Vector3(sin(a)*radius,0,-cos(a)*radius),Vector3(sin(a)*(radius-0.22),0,-cos(a)*(radius-0.22)),Vector3(sin(b)*radius,0,-cos(b)*radius),Vector3(sin(b)*radius,0,-cos(b)*radius),Vector3(sin(a)*(radius-0.22),0,-cos(a)*(radius-0.22)),Vector3(sin(b)*(radius-0.22),0,-cos(b)*(radius-0.22))]: st.add_vertex(v)
	st.generate_normals()
	var m=Geo.mat(color.to_html(),0,0.7)
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	var n=Geo.mesh(self,st.commit(),p,m)
	n.rotation.y=atan2(-dir.x,-dir.z)
	n.rotation.z=(0.25 if combo%2 else -0.25) if plane==9.0 else plane
	var t=create_tween().set_parallel(true)
	t.tween_property(n,"scale",Vector3.ONE*1.17,0.17)
	t.tween_property(n,"rotation:y",n.rotation.y+(0.8 if combo%2 else -0.8),0.17)
	t.chain().tween_callback(n.queue_free)

func damage_number(p: Vector3,amount: int,heavy: bool):
	# Crowd damage remains per target. Only the expensive text/tween feedback
	# is sampled, with both a contact-frame and a live-label budget.
	var frame=Engine.get_physics_frames()
	if damage_number_frame!=frame:
		damage_number_frame=frame;damage_numbers_this_frame=0
	var quality=clampi(int(settings.quality),0,2)
	if damage_numbers_this_frame>=[3,8,12][quality] or damage_numbers_live>=[16,32,48][quality]:return
	damage_numbers_this_frame+=1;damage_numbers_live+=1
	var label=Label3D.new()
	label.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.tree_exited.connect(func():damage_numbers_live-=1,CONNECT_ONE_SHOT)
	label.text=str(amount)
	label.font_size=48 if heavy else 36
	label.pixel_size=0.013
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test=true
	label.modulate=Color("ffe49a") if heavy else Color("ffffff")
	label.position=p
	add_child(label)
	var t=create_tween().set_parallel(true)
	t.tween_property(label,"position",p+Vector3(randf_range(-0.3,0.3),1.4,0),0.65)
	t.tween_property(label,"modulate:a",0.0,0.65)
	t.chain().tween_callback(label.queue_free)

func visual_test():
	await get_tree().create_timer(3).timeout
	get_viewport().get_texture().get_image().save_png("res://tests/menu.png")
	start_game()
	await get_tree().create_timer(3).timeout
	get_viewport().get_texture().get_image().save_png("res://tests/gameplay.png")
	print("VISUAL_CAPTURE_COMPLETE FPS=",Engine.get_frames_per_second()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if "--capture-only" in OS.get_cmdline_user_args(): get_tree().quit()

func run_smoke_test():
	tuning=PrototypeTuning.DEFAULTS.duplicate()
	await get_tree().process_frame
	start_game()
	player.smoke_mode=true
	await get_tree().create_timer(0.7).timeout
	var start=player.position
	player.smoke_move=Vector2(0,-1)
	await get_tree().create_timer(1).timeout
	player.smoke_move=Vector2.ZERO
	print("MOVEMENT ",start," -> ",player.position," velocity ",player.velocity," floor ",player.is_on_floor())
	assert(player.position.distance_to(start)>6,"Movement failed")
	send_action("jump")
	var y=player.position.y
	await get_tree().create_timer(0.25).timeout
	assert(player.position.y>y+1,"Jump failed")
	await get_tree().create_timer(1).timeout
	var target=enemies[0]
	player.position=target.position+Vector3(0,0,2.0)
	player.facing=Vector3.FORWARD
	player.invuln=10
	target.hp=500
	target.max_hp=500
	send_action("light_attack")
	await get_tree().create_timer(1.6).timeout
	assert(target.hp<target.max_hp,"Light attack failed")
	player.position=target.position+Vector3(0,0,2.0)
	var hp_before_heavy=target.hp
	send_action("heavy_attack")
	await get_tree().create_timer(1).timeout
	assert(target.hp==hp_before_heavy-48,"Heavy attack failed")
	target.take_hit(500,Vector3.FORWARD,true)
	send_action("pause")
	await get_tree().process_frame
	assert(get_tree().paused,"Pause failed")
	send_action("pause")
	await get_tree().process_frame
	assert(not get_tree().paused,"Resume failed")
	player.position=Vector3(-44,world.height_at(-44,-5)+0.2,-5)
	camera_rig.reset_follow()
	await get_tree().create_timer(0.5).timeout
	assert(camera_rig.current_distance<camera_rig.distance,"Camera cave collision failed")
	player.invuln=100
	player.position=Vector3(10,world.height_at(10,-8)+0.2,-8)
	player.velocity=Vector3.ZERO
	player.model.charge_requested=false
	player.model.charge_release=-1.0
	player.model.charge_pose_weight=0
	player.model.locomotion.reset()
	player.smoke_move=Vector2(1,0)
	await get_tree().create_timer(3.2).timeout
	player.smoke_move=Vector2.ZERO
	print("BRIDGE END ",player.position)
	assert(player.position.x>38,"Bridge traversal failed")
	player.position=Vector3(-8,world.height_at(-8,-21)+0.2,-21)
	player.velocity=Vector3.ZERO
	player.model.charge_requested=false
	player.model.charge_release=-1.0
	player.model.charge_pose_weight=0
	player.model.locomotion.reset()
	player.smoke_move=Vector2(0,-1)
	await get_tree().create_timer(2.0).timeout
	player.smoke_move=Vector2.ZERO
	print("TEMPLE END ",player.position)
	assert(player.position.z<-34,"Temple entry failed")
	var before=player.model.equipped
	send_action("equip")
	await get_tree().process_frame
	assert(player.model.equipped==before,"E must retain the equipped weapon")
	boss_enemy.take_hit(600,Vector3.FORWARD,true)
	assert(area_cleared.get(0,false),"Boss victory failed")
	player.dodge_time=0.25
	start_game()
	assert(player.dodge_time==0 and player.hp==100 and kills==0,"Restart reset failed")
	show_main_menu()
	assert(not playing and not get_tree().paused,"Main menu failed")
	print("SMOKE_TEST_PASS: movement, jump, light attack, heavy knockback, pause, resume, cave camera collision, boss victory, main menu, bridge crossing, temple entry, E retains weapon, actual input events, complete restart reset")
	quit_clean()

func _exit_tree():
	if is_instance_valid(music):
		music.stop()
		music.stream=null
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream=null
	sounds.clear()
	Geo.mats.clear()
	SkySmoke.meshes.clear()
	ChainPipeVisual.meshes.clear()
	EdoFireExplosion.fire_meshes.clear()
	GameAssets.scenes.clear()

func quit_clean():
	sound_library.cancel()
	music.stop()
	for voice in voices: voice.stop()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()

func send_action(action: String):
	var ev=InputEventAction.new()
	ev.action=action
	ev.pressed=true
	Input.parse_input_event(ev)
	var release=InputEventAction.new()
	release.action=action
	release.pressed=false
	Input.parse_input_event(release)

func is_fire_siege()->bool:
	return tower_defense_mode and is_instance_valid(encounters) and encounters.get("redesign_mode")==true

func siege_building()->bool:
	return is_fire_siege() and encounters.build_candidate()>=0

func clear_siege_projectiles():
	player.reset_auto_attack()
	player.cancel_charge()
	player.quick_attacks.stop_coins()
	player.end_surge()
	player.sky_strike.cancel()
	player.forward_dash.cancel()
	for group in ["projectiles","boss_waves","edo_explosions","combo_energy"]:
		for projectile in get_tree().get_nodes_in_group(group):
			projectile.set_process(false);projectile.set_physics_process(false);projectile.queue_free()

func camera_combat()->bool:
	return tower_defense_mode and rogue_roster_mode and not rogue_battle_mode

func attack_direction()->Vector3:
	if rogue_battle_mode and is_instance_valid(rogue_view):
		rogue_view.update_aim()
		return rogue_view.aim_direction()
	return Vector3.FORWARD.rotated(Vector3.UP,camera_rig.yaw)

func crosshair_aim_enabled()->bool:
	return camera_combat() and (OS.has_feature("crosshair_aim") or bool(ProjectSettings.get_setting("goemon/experimental_crosshair",false)))

func crosshair_target(max_distance: float=120.0)->Vector3:
	var camera: Camera3D=camera_rig.camera
	var center: Vector2=camera.get_viewport().get_visible_rect().size*.5
	var origin: Vector3=camera.project_ray_origin(center)
	var direction: Vector3=camera.project_ray_normal(center)
	var query=PhysicsRayQueryParameters3D.create(origin,origin+direction*max_distance,1|4)
	query.exclude=[player.get_rid()]
	var hit: Dictionary=camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else origin+direction*max_distance

func projectile_direction(origin: Vector3)->Vector3:
	if crosshair_aim_enabled():
		var offset: Vector3=crosshair_target()-origin
		var forward: Vector3=-camera_rig.camera.global_basis.z
		return offset.normalized() if offset.length_squared()>.01 and offset.dot(forward)>0 else forward
	if rogue_battle_mode and is_instance_valid(rogue_view):
		var offset: Vector3=rogue_view.aim+Vector3.UP*1.1-origin
		if offset.length_squared()>.01:return offset.normalized()
	return attack_direction()

func throw_coin(heavy: bool,charged: bool=false,power: float=1.0,ticket: Dictionary={},automatic: bool=false):
	if ticket.is_empty():ticket=player.attack_ticket if not player.attack_ticket.is_empty() else player.attack_chain.active_ticket
	var from=player.global_position+Vector3.UP*1.25*player.growth_multiplier()
	var direction=projectile_direction(from)
	var primary_range = player.BASIC_ATTACK_RANGE_MULTIPLIER if not heavy and not charged else 1.0
	# Key 2 always selects the closest unobstructed enemy actually in the camera.
	var target=AttackChain.screen_target(player,from,tuning.coin_speed*2.0*primary_range*player.growth_multiplier()-.5) if automatic or player.soft_target or player.growth_multiplier()>1.01 or (player.quick_attacks.active and player.quick_attacks.action==2) else null
	if target and (automatic or (not rogue_battle_mode and not camera_combat())):direction=(AttackChain.aim_point(target)-from).normalized()
	if not automatic:player.facing=Vector3(direction.x,0,direction.z).normalized()
	if automatic:
		var coin=spawn_gold_coin(from+direction*.48,direction,heavy,charged,power,false,0,ticket,false,player.progression.coin_count())
		coin.lifetime*=primary_range
		if player.scarf_equipped:spawn_gold_coin(from,direction.rotated(Vector3.UP,.12),false,false,1,false,0,ticket)
	else:
		var count=1 if charged else int(tuning.split_count if heavy else tuning.coin_count)
		for i in range(count):
			var angle=(i-(count-1)*.5)*(.16 if heavy else .07)
			var coin=spawn_gold_coin(from+direction*.48,direction.rotated(Vector3.UP,angle),heavy,charged,power,false,0,ticket)
			coin.lifetime*=primary_range
	# Coins still confirm combo hits, but only melee may create a red bonus slash.
	sound("giant_toss" if charged else "throw",0.4)

func spawn_gold_coin(origin: Vector3,direction: Vector3,heavy: bool=false,charged: bool=false,power: float=1.0,energy: bool=false,tilt: float=0.0,ticket: Dictionary={},cross: bool=false,count: int=1)->GoldCoin:
	var coin: GoldCoin=preload("res://scripts/coin_volley.gd").new() if count>1 else GoldCoin.new()
	coin.coin_count=count
	coin.game=self;coin.combo_energy=energy;coin.slash_tilt=tilt
	coin.attack_ticket=player.attack_chain.active_ticket if ticket.is_empty() else ticket
	coin.cross_slash=cross
	coin.heavy=heavy or charged
	coin.piercing=charged
	coin.damage=(tuning.charged_damage*power if charged else tuning.coin_damage*(1.2 if heavy else 1.0))*player.damage_multiplier()
	var size_bonus=tuning.surge_coin_size if player.surge_left>0 else 1.0
	coin.hit_radius=(tuning.charged_radius*(0.6+power*0.4) if charged else 0.3)*size_bonus*player.pickup_multiplier("range")*player.growth_multiplier()
	coin.visual_size=(coin.hit_radius/0.45 if charged else (1.3 if heavy else 1.0)*size_bonus)
	coin.position=origin
	coin.velocity=direction*tuning.coin_speed*(tuning.surge_coin_speed if player.surge_left>0 else 1.0)*player.attack_speed_multiplier()
	coin.lifetime=2.0*player.growth_multiplier()/player.attack_speed_multiplier()
	add_child(coin)
	return coin

func throw_robe_coins(heading: Vector3,radial: bool=false,spread: bool=false):
	var direction=Vector3(heading.x,0,heading.z).normalized()
	if direction.is_zero_approx():direction=Vector3.FORWARD
	var from=player.global_position+Vector3.UP*1.25*player.growth_multiplier()
	# One release per contact: every combo stage gets a coin, a spin gets a full ring.
	# Offset the extra ranged coin so it is visible alongside the normal toss.
	for i in range(16 if radial else 1):
		var ray=direction.rotated(Vector3.UP,TAU*i/16.0 if radial else (.12 if spread else 0.0))
		spawn_gold_coin(from,ray)
	if not spread:sound("throw",.4)

func spin_slash(p: Vector3,radius: float):
	for i in range(3):
		var ring=Geo.torus(self,p+Vector3.UP*(i-1)*0.16,radius-0.12,radius,Geo.mat("ffe399",0.1,0.8))
		ring.rotation.z=(i-1)*0.1
		var tween=create_tween().set_parallel(true)
		tween.tween_property(ring,"scale",Vector3.ONE*1.08,0.22)
		tween.tween_property(ring,"position:y",p.y+0.35,0.22)
		tween.chain().tween_callback(ring.queue_free)

func spawn_gates():
	gates.clear()
	if tower_defense_mode:return
	if SURVIVAL_MODE:
		WorldExpansion.walls(world,Geo.mat("69816a"))
		return
	if area_index>0:
		add_gate(world.entrance_point,area_index-1,false)
	if area_index<AREA_NAMES.size()-1:
		var exit=Vector3(-44,world.height_at(-44,11),11) if area_index==0 else world.exit_point
		add_gate(exit,area_index+1,true)
	if area_index==0:
		WorldExpansion.walls(world,Geo.mat("69816a"))

func add_gate(p: Vector3,destination: int,forward: bool):
	if SURVIVAL_MODE:return
	var gate=AreaGate.new()
	gate.game=self
	gate.position=p
	gate.destination=destination
	gate.forward_gate=forward
	world.add_child(gate)
	gates.append(gate)

func use_nearby_gate():
	for gate in gates:
		if player.position.distance_to(gate.position)<AreaGate.INTERACTION_RADIUS:
			if gate.unlocked: travel_to(gate.destination)
			else: toast(gate.prompt())
			return

func remember_area():
	var saved=area_states.get(area_index,{"enemies":{},"collected":[]})
	for enemy in enemies:
		if is_instance_valid(enemy): saved.enemies[enemy.encounter_id]={"hp":enemy.hp,"position":enemy.position,"dead":enemy.dead}
	var collected=[]
	for i in range(world.motes.size()):
		if is_instance_valid(world.motes[i]) and not world.motes[i].visible: collected.append(i)
	saved.collected=collected
	area_states[area_index]=saved

func remember_defeat(enemy: Ninja):
	if SURVIVAL_MODE:return
	if not area_states.has(area_index): area_states[area_index]={"enemies":{},"collected":[]}
	area_states[area_index].enemies[enemy.encounter_id]={"hp":0,"position":enemy.position,"dead":true}

func rebuild_area(index: int):
	if is_instance_valid(kennel):kennel.reset()
	if is_instance_valid(barracks):barracks.reset()
	if SURVIVAL_MODE:index=0
	encounters.reset()
	for projectile in get_tree().get_nodes_in_group("projectiles"): projectile.queue_free()
	for effect in get_tree().get_nodes_in_group("boss_waves"): effect.queue_free()
	for pickup in get_tree().get_nodes_in_group("energy_pickups"):pickup.queue_free()
	for effect in get_tree().get_nodes_in_group("sky_smoke"):effect.queue_free()
	for effect in get_tree().get_nodes_in_group("edo_explosions"):effect.queue_free()
	for effect in get_tree().get_nodes_in_group("combo_energy"):effect.queue_free()
	for effect in get_tree().get_nodes_in_group("building_rubble"):effect.queue_free()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	area_index=index
	boss_active=false
	world=load("res://scripts/map_builder_world.gd").new() if tower_defense_mode and not custom_map_data.is_empty() else (load("res://scripts/tower_defense_world.gd").new() if tower_defense_mode else (Sanctuary.new() if index==0 else ExpeditionArea.new()))
	if world.get("custom_map")==true:world.map_data=custom_map_data.duplicate(true)
	if tower_defense_mode:
		world.beta_mode=defense_beta;world.redesign_mode=is_fire_siege()
		world.expanded_mode=is_fire_siege() and world.get("custom_map")!=true
	world.descent_mode=descent_mode
	world.area_index=index
	world.generation_seed=run_seed+index*104729
	world.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	spawn_enemies()
	spawn_gates()
	pursuit.configure()
	var collected=area_states.get(index,{}).get("collected",[])
	for i in collected:
		if i<world.motes.size(): world.motes[i].hide()
	zone_seen.clear()
	apply_quality()

func reset_player_at(p: Vector3):
	player.attack_chain.reset()
	player.cancel_charge()
	checkpoint=p
	player.position=p
	player.velocity=Vector3.ZERO
	player.model.charge_requested=false
	player.model.charge_release=-1.0
	player.model.charge_pose_weight=0
	player.model.locomotion.reset()
	player.attack_left=0
	player.queued=false
	player.dodge_time=0
	player.dodge_cooldown=0
	player.impact_pause=0
	player.jump_windup=0
	player.heavy_buffer=0
	player.jump_buffer=0
	player.reset_wall_jump()
	player.jumps_used=0
	player.air_turn=0
	player.coyote=0
	player.invuln=1.0
	player.model.visible=true
	chain=0
	chain_timer=0
	hit_stop=0
	Engine.time_scale=1
	camera_rig.reset_follow()

func travel_to(index: int):
	if SURVIVAL_MODE:return
	if transitioning or index<0 or index>=AREA_NAMES.size(): return
	transitioning=true
	player.cancel_charge()
	Engine.time_scale=1
	var cover=ColorRect.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.color=Color("0b202c")
	cover.modulate.a=0
	ui.add_child(cover)
	label_at(cover,"TRAVELLING TO "+AREA_NAMES[index],Vector2(390,390),28,Color("f1d390"))
	var fade=create_tween()
	fade.tween_property(cover,"modulate:a",1.0,0.18)
	await fade.finished
	remember_area()
	var old_index=area_index
	rebuild_area(index)
	var arrival=world.spawn_point
	if index<old_index:
		for gate in gates:
			if gate.destination==old_index:arrival=gate.position+Vector3(0,.2,7)
	reset_player_at(arrival)
	camera_rig.yaw=0 if index>old_index else PI
	player.facing=Vector3.FORWARD.rotated(Vector3.UP,camera_rig.yaw)
	player.model.rotation.y=camera_rig.yaw
	hud.banner=AREA_NAMES[index]
	hud.banner_time=4
	toast("Area %d / 4 · %s · Seed %d" % [index+1,BOSS_NAMES[index],run_seed])
	await get_tree().process_frame
	var reveal=create_tween()
	reveal.tween_property(cover,"modulate:a",0.0,0.25)
	await reveal.finished
	cover.queue_free()
	transitioning=false

func restart_area():
	if SURVIVAL_MODE:
		start_game(run_seed)
		return
	player.cancel_charge()
	player.end_surge()
	player.clear_powerups()
	if transitioning: return
	clear_menu()
	get_tree().paused=false
	paused=false
	playing=true
	won=false
	area_states.erase(area_index)
	area_cleared.erase(area_index)
	rebuild_area(area_index)
	player.refresh_max_health()
	player.hp=player.max_hp
	player.scale=Vector3.ONE
	reset_player_at(world.spawn_point if area_index>0 else Vector3(0,world.height_at(0,41)+0.3,41))
	camera_rig.yaw=0
	camera_rig.pitch=0.36
	player.facing=Vector3.FORWARD
	player.model.rotation.y=0
	kills=0
	sparks=0
	for state in area_states.values():
		for e in state.enemies.values():
			if e.dead: kills+=1
		sparks+=state.collected.size()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if rogue_battle_mode else Input.MOUSE_MODE_CAPTURED
	hud.banner=AREA_NAMES[area_index]
	hud.banner_time=3

func area_visual_test():
	start_game()
	player.smoke_mode=true
	player.invuln=0
	player.select_weapon(2)
	await get_tree().create_timer(1).timeout
	get_viewport().get_texture().get_image().save_png("res://tests/coins-hud.png")
	for index in range(1,4):
		area_cleared[index-1]=true
		await travel_to(index)
		player.invuln=0
		for enemy in enemies: enemy.set_physics_process(false)
		await get_tree().create_timer(1.5).timeout
		get_viewport().get_texture().get_image().save_png("res://tests/area-%d.png" % index)
		print("AREA_VISUAL ",index," fps=",Engine.get_frames_per_second())
	quit_clean()


func show_lab():
	player.cancel_charge(true)
	paused=true
	get_tree().paused=true
	Engine.time_scale=1
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var root=menu_base()
	var lab=PrototypeLab.new()
	lab.game=self
	root.add_child(lab)

func update_tuning(key: String,value):
	tuning[key]=value
	tuning=PrototypeTuning.sanitized(tuning)
	player.refresh_max_health()
	player.hp=minf(player.hp,player.max_hp)
	save_settings()

func spawn_practice(dummy: bool)->int:
	var live=0
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.practice: live+=1
	var amount=mini(mini(int(tuning.spawn_count),80-live),enemy_spawn_capacity())
	var spawned=0
	for attempt in range(100):
		if spawned>=amount: break
		var angle=randf()*TAU
		var radius=randf_range(4,11)
		var pos=player.position+Vector3(sin(angle)*radius,0,cos(angle)*radius)
		if not world.playable_bounds.grow(-3).has_point(Vector2(pos.x,pos.z)):continue
		pos.y=world.height_at(pos.x,pos.z)+0.2
		if pos.y<0: continue
		var ray=PhysicsRayQueryParameters3D.create(player.position+Vector3.UP,pos+Vector3.UP,1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		var probe=PhysicsShapeQueryParameters3D.new()
		var shape=CapsuleShape3D.new()
		shape.radius=0.6
		shape.height=2.2
		probe.shape=shape
		probe.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*1.2)
		probe.collision_mask=7
		if not get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty(): continue
		var enemy=Ninja.new()
		enemy.game=self
		enemy.training_dummy=dummy
		enemy.practice=true
		enemy.variant=0 if dummy else lab_spawn_id%4
		enemy.encounter_id="lab_"+str(lab_spawn_id)
		lab_spawn_id+=1
		enemy.position=pos
		enemy.process_mode=Node.PROCESS_MODE_PAUSABLE
		add_child(enemy)
		enemies.append(enemy)
		spawned+=1
	return spawned

func clear_practice():
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.practice:
			enemies.erase(e)
			e.queue_free()

func combat_visual():
	start_game()
	tuning.freeze_ai=true
	player.activate_surge()
	camera_rig.distance=8
	camera_rig.yaw=PI
	await get_tree().create_timer(2).timeout
	get_viewport().get_texture().get_image().save_png("res://tests/golden-surge.png")
	show_lab()
	await get_tree().create_timer(1).timeout
	get_viewport().get_texture().get_image().save_png("res://tests/prototype-lab.png")
	quit_clean()

# Called only after confirmed damage, never on an animation timer or a miss.
func confirm_impact(victim: Ninja, point: Vector3, direction: Vector3, strength: int, projectile: bool):
	var duration=[0.035,0.060,0.095][clampi(strength,0,2)]
	impact_confirmed.emit(victim,strength,duration)
	victim.impact_pause=maxf(victim.impact_pause,duration)
	# Red pipe chains keep moving through impact; enemy recoil still sells the hit.
	if not projectile and (rogue_battle_mode or not (player.character_id==1 and player.weapon_slot==1 and player.attack_chain.energized())):
		player.impact_pause=maxf(player.impact_pause,duration)
	hit_stop=maxf(hit_stop,duration)
	camera_rig.kick(direction,[0.035,0.065,0.12][clampi(strength,0,2)])
	sound(("coin_heavy_hit" if strength==2 else "coin_hit") if projectile else ("heavy_hit" if strength==2 else "hit"),0.7)
	sound("enemy_reaction",0.22 if strength<2 else 0.38)
	if rogue_battle_mode:rogue_feedback.impact(victim,point,direction,strength,projectile)
	else:impact_effect(point,direction,strength)

func impact_effect(point: Vector3, direction: Vector3, strength: int):
	if rogue_battle_mode:
		rogue_feedback.impact(null,point,direction,strength,false)
		return
	# This native path serves Goemon, Edo and environmental contacts. Damage,
	# recoil, audio and hit-stop are resolved before cosmetic admission.
	var frame=Engine.get_physics_frames()
	if impact_feedback_frame!=frame:
		impact_feedback_frame=frame;impacts_this_frame=0
	var quality=clampi(int(settings.quality),0,2)
	if impacts_this_frame>=[3,8,12][quality] or impacts_live>=[12,24,36][quality]:return
	impacts_this_frame+=1;impacts_live+=1
	var effect=Node3D.new();add_child(effect)
	effect.tree_exited.connect(func():impacts_live-=1,CONNECT_ONE_SHOT)
	var lifetime=create_tween();lifetime.tween_interval(.2);lifetime.tween_callback(effect.queue_free)
	var flash=Geo.sphere(effect,point,Vector3.ONE*(0.12+strength*0.055),Geo.mat("fff4c4",0,1.8))
	flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ft=create_tween()
	ft.tween_property(flash,"scale",Vector3.ONE*0.005,0.085)
	ft.tween_callback(flash.queue_free)
	for i in range(4+strength*2):
		var ray=(direction+Vector3(randf_range(-0.7,0.7),randf_range(-0.2,0.8),randf_range(-0.7,0.7))).normalized()
		var streak=Geo.beam(effect,point,point+ray*(0.26+strength*0.13),0.018,Geo.mat("ffd477",0,1.0))
		streak.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tween=create_tween().set_parallel(true)
		tween.tween_property(streak,"position",streak.position+ray*(0.4+strength*0.22),0.16)
		tween.tween_property(streak,"scale",Vector3.ONE*0.01,0.18)
		tween.chain().tween_callback(streak.queue_free)

func combo_slash(point: Vector3, direction: Vector3, stage: int, size: float):
	var idx=clampi(stage-1,0,2)
	slash(point,direction,false,stage,Color("fff1b0") if stage==3 else Color("ffe19a"),size*[0.82,1.04,1.26][idx],[0.88,-0.12,0.30][idx])

func drop_powerup(point: Vector3):
	if tower_defense_mode and defense_beta:return
	orb_system.drop(point)

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:_siege_interact_held=false
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player) and is_instance_valid(player.musashi):
		player.musashi.release_primary()
		if rogue_battle_mode:
			player.rogue_controls.reset()
			if playing and not paused and not won and player.hp>0 and not smoke_test:show_pause()

func open_map_editor():
	if is_instance_valid(map_editor):return
	clear_siege_projectiles()
	playing=false;paused=true;get_tree().paused=true
	Engine.time_scale=1;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	clear_menu();hud.hide()
	if map_editor_draft==null:
		map_editor_draft=load("res://scripts/map_document.gd").new();map_editor_draft.reset_template()
	map_editor=load("res://scripts/map_editor.gd").new();map_editor.game=self;map_editor.document=map_editor_draft
	add_child(map_editor)

func play_custom_map(map_data: Dictionary):
	var verifier=load("res://scripts/map_document.gd").new()
	if not verifier.decode(JSON.stringify(map_data)).is_empty() or not verifier.validate().is_empty():return
	custom_map_data=verifier.data.duplicate(true)
	if is_instance_valid(map_editor):
		map_editor_draft=map_editor.document;remove_child(map_editor);map_editor.queue_free();map_editor=null
	get_tree().paused=false;paused=false;hud.show()
	launching_custom_map=true;defense_beta=true;defense_tactics=true
	start_mode("defense");launching_custom_map=false
