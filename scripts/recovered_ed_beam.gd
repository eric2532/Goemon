extends Node3D
## Ed's held primary: a fire stream and the recovered blue shield.
## Combat owns active time; render processing finishes the source release phase.
const LENGTH=6.4
const REACH_MULTIPLIER=2.0
const RADIUS=.44
const DAMAGE=72.0
const INTERVAL=.2
const BED_START=2.0/60.0
const HUM_START=1.0
const Visual=preload("res://scripts/recovered_ed_beam_visual.gd")
const NativeState=preload("res://scripts/recovered_ed_beam_native_state.gd")
var hero: Hero
var game: Node
var attack_ticket: Dictionary={}
var active=true
var releasing=false
var release_elapsed=0.0
var warmup=4.0/30.0
var elapsed=0.0
var length_now=0.0
var direction=Vector3.FORWARD
var visual: Node3D
var wall_distance=-1.0
var charge: AudioStreamPlayer3D
var bed: AudioStreamPlayer3D
var loop: AudioStreamPlayer3D
var _next_pulse=-1.0
var _charge_started=false
var _charge_recorded=false
var _bed_source: AudioStream
var _hum_source: AudioStream
var _focused=true
var shield: Node3D
var native_phase: RefCounted
var native_main_ticks=0
var native_release_base=0
var companion_clock: Node

static func model_scale(caster: Hero)->float:
	if is_instance_valid(caster.model) and is_instance_valid(caster.model.rig_visual):return caster.model.rig_visual.scale.x
	return preload("res://scripts/character_proportions.gd").ED_HEIGHT/1.8

static func source_origin(caster: Hero)->Vector3:
	# Ed's rig is raised by its imported lower bound to place his feet on ground.
	if is_instance_valid(caster.model) and is_instance_valid(caster.model.rig_visual):return caster.model.rig_visual.global_position
	return caster.global_position

static func maximum_length(caster: Hero)->float:
	return LENGTH*REACH_MULTIPLIER*model_scale(caster)*caster.growth_multiplier()*caster.pickup_multiplier("range")

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_to_group("projectiles");add_to_group("ed_beams")
	for other in get_tree().get_nodes_in_group("ed_beams"):
		if other!=self and other.hero==hero:other.stop()
	if not hero.has_meta(NativeState.META):hero.set_meta(NativeState.META,NativeState.new())
	native_phase=hero.get_meta(NativeState.META)
	companion_clock=NativeState.world_clock(game)
	_advance_native_main_to(1)
	visual=Visual.new();add_child(visual)
	charge=_audio_player("EdBeamCharge");bed=_audio_player("EdBeamBed");loop=_audio_player("EdBeamHum")
	if not _live():stop();return
	shield=preload("res://scripts/recovered_ed_shield.gd").new();shield.hero=hero;hero.add_child(shield)
	update_path();_sync_audio()
	preload("res://scripts/recovered_ed_beam_renderer.gd").ensure(self)

func _audio_player(label: String)->AudioStreamPlayer3D:
	var player=AudioStreamPlayer3D.new();player.name=label;player.unit_size=6;player.max_distance=48
	player.pitch_scale=1;add_child(player);return player

func _live()->bool:
	return (active or releasing) and _focused and is_instance_valid(hero) and hero.is_inside_tree() and hero.hp>0 and hero.character_id==14 and is_instance_valid(game) and game.playing and not game.transitioning and is_instance_valid(game.sound_library) and not game.sound_library.recording

func _paused()->bool:return game.paused or get_tree().paused

func _notification(what: int):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused=false;stop()

func _process(delta: float):
	if not _live():stop();return
	if releasing and not _paused():
		release_elapsed+=maxf(0,delta);elapsed+=maxf(0,delta)
		_advance_native_main_to(native_release_base+mini(16,floori(release_elapsed*30.0+.000001)))
		if is_instance_valid(shield):shield.advance(delta)
		if release_elapsed>=16.0/30.0:stop();return
		update_path()
	_sync_audio()

func advance(delta: float):
	if not _live():stop();return
	if _paused():_sync_audio();return
	if not active:return
	elapsed+=maxf(0,delta)
	_advance_native_main_to(maxi(1,floori(elapsed*30.0+.000001)+1))
	if is_instance_valid(shield):shield.advance(delta)
	update_path();_sync_audio()
	if _next_pulse<0:_next_pulse=warmup
	while active and elapsed+.000001>=_next_pulse:
		_next_pulse+=INTERVAL
		damage_tick()

func update_path():
	if (not active and not releasing) or not is_instance_valid(hero) or not hero.is_inside_tree():return
	var growth=hero.growth_multiplier()*model_scale(hero)
	var origin=source_origin(hero)
	global_position=origin+Vector3.UP*.48*growth
	if is_instance_valid(shield):shield.global_position=origin
	direction=hero.combat_attack_direction()
	if hero.ai_controlled:direction=hero.ai_aim-global_position
	elif game.has_method("projectile_direction"):direction=game.projectile_direction(global_position)
	if direction.length_squared()<.0001:direction=hero.facing
	if direction.length_squared()<.0001:direction=Vector3.FORWARD
	direction=direction.normalized()
	length_now=maximum_length(hero)
	# Extend the source probe, visual and hit reach together; keep their original proportions.
	var query=PhysicsRayQueryParameters3D.create(global_position,global_position+direction*8.96*REACH_MULTIPLIER*growth*hero.pickup_multiplier("range"),1)
	query.exclude=[hero.get_rid()];query.hit_from_inside=true
	var wall=get_world_3d().direct_space_state.intersect_ray(query)
	wall_distance=-1.0 if wall.is_empty() else global_position.distance_to(wall.position)
	if wall_distance>=0:length_now=minf(length_now,wall_distance)
	look_at(global_position+direction,Vector3.FORWARD if absf(direction.dot(Vector3.UP))>.999 else Vector3.UP)
	var tick=maxi(1,floori(elapsed*30.0+.000001)+1)
	var world_tick=companion_clock.ticks
	visual.wall_glow_color=native_phase.wall_glow_color
	visual.sample(tick,world_tick,.01*growth,REACH_MULTIPLIER*hero.pickup_multiplier("range"),wall_distance,floori(release_elapsed*30.0+.000001) if releasing else -1)
	native_phase.wall_glow_color=visual.wall_glow_color
	# The visual's startup clock is local to this cast, while the source actor's
	# main rotation and palette resume from its last active update.
	var tube_scale=Vector3(visual.main_material.get_shader_parameter("native_scale"))
	visual.main.basis=(native_phase.roll_basis_q12()/4096.0).scaled(tube_scale)
	visual.main_material.set_shader_parameter("palette_row",native_phase.main_palette_row())
	if visual.entry.visible:visual.entry.position=NativeState.entry_center(native_phase.roll_angle())

func _advance_native_main_to(ticks: int):
	if ticks>native_main_ticks:
		native_phase.main_updates+=ticks-native_main_ticks
		native_main_ticks=ticks

func native_state()->Dictionary:
	return {"cast_tick":maxi(1,floori((elapsed-release_elapsed)*30.0+.000001)+1),
		"release_tick":floori(release_elapsed*30.0+.000001) if releasing else -1,
		"main_updates":native_phase.main_updates,"roll_angle":native_phase.roll_angle(),
		"roll_basis_q12":native_phase.roll_basis_q12(),"main_palette_row":native_phase.main_palette_row(),
		"companion_palette_row":posmod(visual.global_phase,8),
		"shield_updates":native_phase.shield_updates,"shield_phase":native_phase.shield_phase()}

func damage_tick():
	if not _live():stop();return
	if not active or _paused() or elapsed+.000001<warmup:return
	# Re-read movement, aim and cover immediately before fitting any victims.
	update_path()
	if length_now<=.001:return
	var end=global_position+direction*length_now
	var amount=DAMAGE*hero.damage_multiplier()
	BreakableBuilding.hit_segment(game,global_position,end+direction*.01,amount,attack_ticket)
	var struck: Dictionary={}
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or struck.has(enemy.get_instance_id()):continue
		struck[enemy.get_instance_id()]=true
		var hit=AttackChain.segment_contact(enemy,global_position,end,RADIUS*model_scale(hero)*hero.growth_multiplier())
		if hit.is_empty():continue
		# Fitted shapes have rounded end caps; the extended contact limit
		# remains a plane, preserving the source 640:784 hit-to-visual ratio.
		var along: float=(hit.point-global_position).dot(direction)
		if along<0 or along>length_now:continue
		# The native hit volume can reach beside the center ray. Each actual
		# fitted surface must also be exposed to the source, rather than hidden
		# behind side cover that the centerline does not intersect.
		if global_position.distance_squared_to(hit.point)>.000001:
			var sight=PhysicsRayQueryParameters3D.create(global_position,hit.point,1)
			sight.exclude=[hero.get_rid()];sight.hit_from_inside=true
			if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():continue
		enemy.take_hit(amount,direction,false,attack_ticket)
		if hero.ai_controlled:game.confirm_ally_impact(enemy,hit.point,direction,1,true,14,false)
		else:game.confirm_impact(enemy,hit.point,direction,1,true,14,false)

func _original(slot: String)->AudioStream:
	return SoundLibrary.original_for(14,slot)

func _sync_audio():
	var lib=game.sound_library
	var pause=_paused()
	if not releasing and not _charge_started and not pause:
		_charge_started=true
		var audio: Dictionary=lib.playback_for(14,"ed_beam_charge",_original("ed_beam_charge"))
		_charge_recorded=audio.recorded
		if audio.stream!=null and not audio.muted:
			charge.stream=audio.stream;charge.volume_db=linear_to_db(maxf(.000001,.22*audio.gain));charge.play()
	if charge.playing:
		if lib.is_muted_for(14,"ed_beam_charge"):charge.stop()
		else:charge.volume_db=linear_to_db(maxf(.000001,.22*lib.gain_for(14,"ed_beam_charge")))
	var bed_audio: Dictionary=lib.playback_for(14,"ed_beam_bed",_original("ed_beam_bed"))
	# A recorded charge already supplies the user's complete replacement mix.
	if not releasing and elapsed>=BED_START and not _charge_recorded:
		_bed_source=_sustain(bed,bed_audio,_bed_source,28,7476,.22,pause)
	else:bed.stop()
	var hum_audio: Dictionary=lib.playback_for(14,"move_primary_1_weapon",_original("edo_beam_loop"),"edo_beam_start")
	if elapsed>=HUM_START and (not releasing or _hum_source!=null):
		_hum_source=_sustain(loop,hum_audio,_hum_source,28,8456,.35,pause)
	else:loop.stop()
	for player in [charge,bed,loop]:player.stream_paused=pause

func _sustain(player: AudioStreamPlayer3D,audio: Dictionary,previous: AudioStream,begin: int,end: int,gain: float,pause: bool)->AudioStream:
	if audio.muted or audio.stream==null:
		player.stop();return previous
	if previous!=audio.stream:
		player.stop()
		var wav=audio.stream.duplicate() as AudioStreamWAV
		if wav==null:return null
		wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin=0 if audio.recorded else begin
		wav.loop_end=maxi(1,roundi(wav.get_length()*wav.mix_rate)) if audio.recorded else end
		player.stream=wav;previous=audio.stream
	player.pitch_scale=1;player.volume_db=linear_to_db(maxf(.000001,gain*audio.gain))
	if not player.playing and not pause:player.play()
	return previous

func stop():
	if not active and not releasing:return
	active=false;releasing=false;hide()
	if is_instance_valid(shield):shield.hide();shield.queue_free()
	shield=null
	for player in [charge,bed,loop]:
		if is_instance_valid(player):player.stop()
	queue_free()

func release():
	if not active:return
	active=false;releasing=true;release_elapsed=0
	native_release_base=native_main_ticks+1;_advance_native_main_to(native_release_base)
	charge.stop();bed.stop()
	if is_instance_valid(shield):shield.begin_release()
	update_path();_sync_audio()

func _exit_tree():
	if is_instance_valid(shield):shield.queue_free()
	for player in [charge,bed,loop]:
		if is_instance_valid(player):player.stop()
