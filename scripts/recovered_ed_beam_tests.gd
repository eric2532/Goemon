extends SceneTree
## Real beam runtime, production fitted capsules, world cover and SoundLibrary.
var checks=0
var failures=0
var arena
var caster: Hero
var beam_script
var lib: SoundLibrary
var beams: Array=[]

class Arena:
	extends Node3D
	var paused=false
	var playing=true
	var transitioning=false
	var aim=Vector3.RIGHT
	var player: Hero
	var enemies=[]
	var confirmations=[]
	var visual_feedback=[]
	var sound_library: SoundLibrary
	func attack_direction()->Vector3:return aim
	func hero_tuning(_key: String)->float:return 1.0
	func balance_value(_id: int,_key: String)->float:return 1.0
	func burst(_point: Vector3,_color: Color,_count: int,_scale: float=1.0):pass
	func confirm_impact(victim: Ninja,_point: Vector3,_direction: Vector3,_strength: int,_projectile: bool,_source_character: int=0,spawn_visuals: bool=true):confirmations.append([victim,0]);visual_feedback.append(spawn_visuals)
	func confirm_ally_impact(victim: Ninja,_point: Vector3,_direction: Vector3,_strength: int,_projectile: bool,id: int=0,spawn_visuals: bool=true):confirmations.append([victim,id]);visual_feedback.append(spawn_visuals)

class Caster:
	extends Hero
	func _ready():set_physics_process(false)
	func _physics_process(_delta):pass

class Victim:
	extends Ninja
	const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
	var fitted: Dictionary
	var received_ticket={}
	var hits=0
	func _ready():
		hp=1000;max_hp=1000;body_radius=0
		var capsule=CapsuleShape3D.new();capsule.radius=.3;capsule.height=.6
		fitted={"shape":capsule,"center":Vector3.ZERO}
	func _physics_process(_delta):pass
	func combat_segment_contact(from: Vector3,to: Vector3,radius: float)->Dictionary:
		var t=Contact._capsule_segment(fitted,from-global_position,to-global_position,radius)
		return {"point":global_position+Contact._capsule_contact(fitted,from.lerp(to,t)-global_position),"t":t} if t>=0 else {}
	func take_hit(amount: float,_direction: Vector3,_heavy: bool,ticket: Dictionary={}):
		hp-=amount;received_ticket=ticket;hits+=1

func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",message)
func target(at: Vector3)->Victim:
	var enemy=Victim.new();enemy.position=at;arena.add_child(enemy);arena.enemies.append(enemy);return enemy
func beam():
	var effect=beam_script.new();effect.game=arena;effect.hero=caster
	effect.attack_ticket={"source_hero":weakref(caster),"action":"ed_beam_test","chain_enabled":false}
	arena.add_child(effect);beams.append(effect);return effect
func wall(at: Vector3,size: Vector3)->StaticBody3D:
	var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;body.position=at
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape);arena.add_child(body);return body
func clear():
	for effect in beams:
		if is_instance_valid(effect):effect.free()
	beams.clear()
	for enemy in arena.enemies:
		if is_instance_valid(enemy):enemy.free()
	arena.enemies.clear();arena.confirmations.clear();arena.visual_feedback.clear()
	lib._custom_profiles[14].clear();lib._gain_profiles[14].clear();lib._mute_profiles[14].clear()
	caster.hp=100;caster.character_id=14;caster.ai_controlled=false;caster.position=Vector3.ZERO
	caster.buildings_broken=0;caster.powerups.range=0;caster.powerups.damage=0;arena.aim=Vector3.RIGHT
	arena.playing=true;arena.transitioning=false;arena.paused=false;lib.recording=false;paused=false
func fixture()->AudioStreamWAV:
	var audio=AudioStreamWAV.new();audio.format=AudioStreamWAV.FORMAT_16_BITS;audio.mix_rate=16000
	var data=PackedByteArray();data.resize(16000)
	for i in 8000:data.encode_s16(i*2,int(sin(i*TAU*300/16000)*3000))
	audio.data=data;return audio
func run():
	check(ResourceLoader.exists("res://scripts/recovered_ed_beam.gd"),"Sustained Ed beam runtime exists")
	if failures:quit(1);return
	beam_script=load("res://scripts/recovered_ed_beam.gd")
	arena=Arena.new();root.add_child(arena)
	lib=SoundLibrary.new();lib.config_path="user://ed-beam-test-%d/studio.cfg"%OS.get_process_id();lib.folder="user://ed-beam-test-%d/recordings"%OS.get_process_id()
	arena.add_child(lib);lib.set_process(false);arena.sound_library=lib;lib.custom_for(14,"ed_beam_charge")
	caster=Caster.new();caster.character_id=14;caster.game=arena;arena.player=caster;arena.add_child(caster)
	await physics_frame
	await extended_reach()
	await native_volume_and_side_cover()
	await timing_and_fitted_targets()
	await damage_pickup()
	await follow_and_cover()
	await audio_and_lifecycle()
	await normal_release()
	clear();arena.free();await process_frame
	# Allow the real audio mixer to retire stopped one-shot playback handles.
	await create_timer(.35).timeout
	print("RECOVERED_ED_BEAM_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)

func extended_reach():
	var far=target(Vector3(18,.8588,0));var beyond=target(Vector3(24,.8588,0))
	var effect=beam();effect.advance(.14)
	check(far.hp==784,"The longer beam damages a fitted victim beyond its previous reach")
	check(beyond.hp==1000,"The longer beam retains a finite fitted contact limit")
	check(absf(effect.length_now-22.902176)<.001,"Held beam reach is twice the previous source-scaled distance")
	check(effect.visual.companion.to_global(Vector3(0,0,-784)).distance_to(effect.global_position+Vector3.RIGHT*28.055166)<.001,"The recovered visible beam extends with its doubled damage reach")
	clear()
	var exposed=target(Vector3(14,.8588,0));var covered=target(Vector3(19,.8588,0))
	var barrier=wall(Vector3(16,.8588,0),Vector3(.2,5,4));await physics_frame;await physics_frame
	effect=beam();effect.advance(.14)
	check(exposed.hp==784 and covered.hp==1000,"Cover beyond the former reach still blocks the extended beam")
	check(absf(effect.length_now-15.9)<.001,"Extended cover probe clips both damage and visible impact position")
	barrier.free();clear()

func native_volume_and_side_cover():
	var inside=target(Vector3(5,.8588,.5));var outside=target(Vector3(5,.8588,1.5))
	var distant=target(Vector3(10,.8588,0));var effect=beam();effect.advance(.14)
	check(inside.hp==784,"The native hit volume reaches a fitted victim half a metre beside its center")
	check(outside.hp==1000,"The native hit volume rejects a fitted victim 1.5 metres off-axis")
	check(distant.hp==784,"The native hit volume reaches a fitted victim ten metres ahead")
	clear()
	var exposed=target(Vector3(6,.8588,-.5));var covered=target(Vector3(6,.8588,.5))
	var barrier=wall(Vector3(3,.8588,.3),Vector3(.2,5,.3));await physics_frame;await physics_frame
	effect=beam();effect.advance(.14)
	check(exposed.hp==784 and covered.hp==1000,"A wide off-axis hit cannot pass through world cover missed by the center ray")
	check(absf(effect.length_now-22.902176)<.001,"Side cover preserves the unobstructed native beam centerline")
	barrier.free();clear()

func timing_and_fitted_targets():
	var near=target(Vector3(3,.48,0));var far=target(Vector3(9,.8588,0))
	var off_axis=target(Vector3(5,.8588,1.5));var beyond=target(Vector3(24,.8588,0))
	# Duplicate snapshots must not double damage the same actor in one pulse.
	arena.enemies.append(near)
	var effect=beam();effect.advance(0);effect.advance(.1)
	check(near.hp==1000 and far.hp==1000,"Four source ticks of windup prevent input-frame and early damage")
	effect.advance(.034)
	check(near.hp==784 and far.hp==784,"First sustained pulse pierces all real fitted victims for 216 damage")
	check(off_axis.hp==1000 and beyond.hp==1000,"Fitted contacts reject off-axis and beyond-range victims")
	check(near.hits==1 and near.received_ticket==effect.attack_ticket,"A pulse deduplicates actors and retains cast attribution")
	check(effect.visual.companion.to_global(Vector3(0,0,-784)).distance_to(effect.global_position+Vector3.RIGHT*28.055166)<.001,"The extended companion preserves the source visual-to-hit length ratio")
	effect._process(2)
	check(near.hp==784 and is_equal_approx(effect.elapsed,.134),"Render processing never advances damage or its cast clock")
	effect.advance(.199)
	check(near.hp==784,"Pulse spacing does not fire before its 0.2 second interval")
	effect.advance(.001)
	check(near.hp==568 and far.hp==568,"Holding the beam emits the next piercing pulse after 0.2 seconds")
	effect.advance(.4)
	check(near.hp==136 and near.hits==4,"A long combat frame preserves every elapsed pulse without per-actor duplication")
	arena.enemies.erase(near);clear()

func damage_pickup():
	caster.powerups.damage=1
	var victim=target(Vector3(3,.48,0));var effect=beam();effect.advance(.14)
	check(victim.hp==676 and victim.hits==1,"Damage pickup multiplies the stronger beam pulse to 324 damage")
	effect.advance(.2)
	check(victim.hp==352 and victim.hits==2,"Damage pickup preserves the 0.2 second pulse interval")
	caster.powerups.damage=0;effect.advance(.2)
	check(victim.hp==136 and victim.hits==3,"Pickup expiry returns the same held beam to 216 damage per pulse")
	clear()

func follow_and_cover():
	var effect=beam();caster.position=Vector3(2,3,4);caster.buildings_broken=50;caster.powerups.range=1
	arena.aim=Vector3.FORWARD;effect.update_path()
	check(effect.global_position.is_equal_approx(Vector3(2,4.7176632,4)) and effect.visual.global_position.distance_to(effect.global_position)<.001,"Fire stream and damage start at the moving grown caster's resized source waist")
	check(absf(effect.length_now-68.706528)<.001 and effect.direction.is_equal_approx(Vector3.FORWARD),"Range pickups and growth extend the persistent beam along current aim")
	check(effect.visual.to_global(Vector3(0,0,-784)).distance_to(Vector3(2,4.7176632,-80.165498))<.001,"Native visual proportions follow character growth and the existing range pickup")
	caster.ai_controlled=true;caster.ai_aim=caster.position+Vector3.LEFT*20;effect.update_path()
	check(effect.direction.is_equal_approx((caster.ai_aim-effect.global_position).normalized()),"Allied Ed uses his own three-dimensional combat aim rather than the player's camera")
	clear()
	var before=target(Vector3(2,.48,0));var behind=target(Vector3(5,.48,0))
	var barrier=wall(Vector3(4,.48,0),Vector3(.2,5,4));await physics_frame;await physics_frame
	effect=beam();effect.advance(.14)
	check(before.hp==784 and behind.hp==1000,"Real wall collision clips the path before fitted enemy damage")
	check(absf(effect.length_now-3.9)<.001 and absf(effect.wall_distance-3.9)<.001,"The native wall probe stops damage at cover")
	barrier.free();clear()

func audio_and_lifecycle():
	var effect=beam()
	check(effect.charge.playing and not effect.loop.playing and not effect.bed.playing,"Source 97E transients begin once at cast entry")
	effect.advance(.034)
	check(effect.bed.playing and effect.bed.stream.loop_begin==28 and effect.bed.stream.loop_end==7476,"Source 97E sustain begins after two ticks and uses only its verified loop")
	effect.advance(.965)
	check(not effect.loop.playing,"Source 97F hum waits until one full second from cast entry")
	effect.advance(.002)
	check(effect.loop.playing and effect.loop.stream.loop_begin==28 and effect.loop.stream.loop_end==8456,"Source 97F joins at one second using its verified audible loop")
	check(is_equal_approx(effect.charge.pitch_scale,1) and is_equal_approx(effect.bed.pitch_scale,1) and is_equal_approx(effect.loop.pitch_scale,1),"All recovered beam sound layers retain source pitch")
	check(effect.loop.stream!=SoundLibrary.original_for(14,"move_primary_1_weapon"),"Loop configuration duplicates the source WAV rather than mutating its preview")
	# AudioStreamPlayer3D submits its pending playback on the engine frame.
	await physics_frame;await physics_frame
	arena.paused=true;effect._process(0);var age=effect.elapsed;effect.advance(.5)
	check(effect.loop.stream_paused and effect.bed.stream_paused and effect.elapsed==age,"Game pause freezes all layers and manual damage time (hum=%s bed=%s age=%s/%s)"%[effect.loop.stream_paused,effect.bed.stream_paused,effect.elapsed,age])
	arena.paused=false;paused=true;effect._process(0);effect.advance(.5)
	check(effect.loop.stream_paused and effect.elapsed==age,"SceneTree pause also freezes always-processing beam audio and damage (hum=%s age=%s/%s)"%[effect.loop.stream_paused,effect.elapsed,age])
	paused=false;effect._process(0)
	check(not effect.loop.stream_paused and effect.loop.playing,"Resuming preserves the sustained loop")
	lib._mute_profiles[14]["move_primary_1_weapon"]=true;effect._process(0)
	check(not effect.loop.playing,"Changing the live weapon mute immediately stops its hum")
	lib._mute_profiles[14].erase("move_primary_1_weapon");effect._process(0)
	check(effect.loop.playing,"Unmuting restores the same held cast's hum")
	effect.stop();check(not effect.active and not effect.charge.playing and not effect.bed.playing and not effect.loop.playing,"Cancel stops every layer synchronously")
	clear()
	var custom=fixture();lib._custom_profiles[14]["move_primary_1_weapon"]=custom;lib._gain_profiles[14]["move_primary_1_weapon"]=.5
	effect=beam();effect.advance(1.01)
	check(effect.loop.playing and effect.loop.stream.data==custom.data and effect.loop.stream.loop_begin==0 and effect.loop.stream.loop_end==8000,"Custom primary recording replaces native 97F and loops its complete take")
	check(is_equal_approx(db_to_linear(effect.loop.volume_db),.35*.5),"Held primary audio preserves the studio weapon gain")
	clear();lib._custom_profiles[14]["ed_beam_charge"]=custom
	effect=beam();effect.advance(.1)
	check(effect.charge.stream==custom and not effect.bed.playing,"A custom charge replaces the composite without adding the native bed")
	clear()
	for reason in ["focus","switch","death","phase","transition","recording","invalid"]:
		effect=beam();effect.advance(1.01)
		match reason:
			"focus":effect._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			"switch":caster.character_id=15
			"death":caster.hp=0
			"phase":arena.playing=false
			"transition":arena.transitioning=true
			"recording":lib.recording=true
			"invalid":effect.hero=null
		effect._process(0)
		check(not effect.active and not effect.charge.playing and not effect.bed.playing and not effect.loop.playing,"%s boundary cannot leak any held beam sound"%reason)
		clear()

func normal_release():
	var victim=target(Vector3(4,.8588,0));var effect=beam();effect.advance(.2)
	var before=victim.hp;effect.release()
	check(not effect.active and effect.releasing and effect.is_visible_in_tree(),"Normal release stops attack ownership while retaining the native shrink")
	arena.paused=true;effect._process(.2)
	check(effect.release_elapsed==0 and effect.releasing,"Pause freezes the native release animation")
	arena.paused=false
	effect.damage_tick();effect.advance(.5)
	check(victim.hp==before,"The release animation cannot damage a victim")
	effect._process(8.0/30.0)
	check(effect.visual.main.scale.x<.6 and effect.visual.main.scale.z==1,"Native release narrows the tube while retaining its original length")
	check(not effect.charge.playing and not effect.bed.playing,"Normal release stops97E without replaying the charge")
	effect._process(8.0/30.0)
	check(not effect.active and not effect.releasing and not effect.visible,"The sixteenth release tick removes the complete beam")
	check(not arena.visual_feedback.has(true),"Native beam hits suppress invented generic impact cosmetics")
	clear()
	effect=beam();effect.advance(.2);effect.release();caster.character_id=15;effect._process(0)
	check(not effect.releasing and not effect.visible,"Switching characters immediately removes an unfinished release")
	clear()
	effect=beam();effect.advance(.75);effect.release();effect._process(.3)
	check(not effect.loop.playing,"Releasing before97F's onset cannot start a new hum during shrink")
	clear()
