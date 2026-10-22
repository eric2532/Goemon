extends SceneTree
## Real beam contact, Ninja damage/recoil and production impact dispatch.
## Only the audio/visual output boundaries are recorded by the fixture.
const Beam=preload("res://scripts/recovered_ed_beam.gd")
var checks=0
var failures=0
var game
var contacts=[]

class Arena extends "res://scripts/game.gd":
	var sound_calls=[]
	var visual_calls=0
	func _ready():set_process(false);set_process_unhandled_input(false)
	func attack_direction()->Vector3:return Vector3.RIGHT
	func projectile_direction(_origin:Vector3)->Vector3:return Vector3.RIGHT
	func sound(kind:String,volume:float=1.0,enemy_source:bool=false,ticket:Dictionary={},source_id:int=0):
		sound_calls.append([kind,volume,enemy_source,ticket,source_id])
	func impact_effect(_point:Vector3,_direction:Vector3,_strength:int):visual_calls+=1

class Caster extends Hero:
	func _ready():set_physics_process(false)
	func combat_attack_direction()->Vector3:return Vector3.RIGHT

class Victim extends Ninja:
	func _ready():
		set_physics_process(false)
		hp=1000000;max_hp=hp;collision_layer=4
		model=HeroModel.new(true);model.crowd_proxy=true;add_child(model)
		bar=MeshInstance3D.new();add_child(bar)

func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",message)
func reset_feedback():
	game.sound_calls.clear();game.visual_calls=0;contacts.clear()
	game.camera_rig.kick_age=1;game.camera_rig.kick_strength=0
	game.player.impact_pause=0;game.hit_stop=0

func run():
	game=Arena.new();game.playing=true;game.descent_mode=false;root.add_child(game)
	game.player=Caster.new();game.player.game=game;game.player.character_id=14;game.add_child(game.player)
	game.camera_rig=ActionCamera.new();game.camera_rig.game=game;game.camera_rig.player=game.player
	game.add_child(game.camera_rig);game.camera_rig.set_process(false)
	game.camera_rig.camera.position=Vector3(0,4,10);game.camera_rig.camera.look_at(Vector3(0,1,-3))
	game.sound_library=SoundLibrary.new();game.sound_library.config_path="user://ed-impact-%d/studio.cfg"%OS.get_process_id()
	game.sound_library.folder="user://ed-impact-%d/recordings"%OS.get_process_id()
	game.add_child(game.sound_library);game.sound_library.set_process(false)
	game.impact_confirmed.connect(func(victim,strength,duration):contacts.append([victim,strength,duration]))
	for index in 24:
		var victim=Victim.new();victim.game=game;victim.position=Vector3(2+index*.5,0,0)
		game.add_child(victim);game.enemies.append(victim)
	var effect=Beam.new();effect.game=game;effect.hero=game.player
	effect.attack_ticket={"source_hero":weakref(game.player),"action":"beam","chain_enabled":false}
	game.add_child(effect)
	var renderer=preload("res://scripts/recovered_ed_beam_renderer.gd").ensure(game)
	renderer.set_process(false)
	reset_feedback();effect.advance(.14)
	var amount=Beam.DAMAGE*game.player.damage_multiplier()
	var all_damaged=true;var all_reacted=true
	for enemy in game.enemies:
		all_damaged=all_damaged and is_equal_approx(enemy.hp,1000000-amount)
		all_reacted=all_reacted and is_equal_approx(enemy.impact_pause,.060) and is_equal_approx(enemy.stun,.20) and is_equal_approx(enemy.recoil_strength,.22) and enemy.velocity.x>0
	check(all_damaged,"A real beam pulse damages all twenty-four victims exactly once")
	check(all_reacted,"Continuous beam contacts preserve every victim's hit pause, stun, recoil and knockback")
	check(contacts.size()==24 and contacts.all(func(hit):return hit[1]==1 and is_equal_approx(hit[2],.060)),"Every actual victim still emits the normal impact confirmation")
	check(game.camera_rig.kick_age==1 and game.camera_rig.kick_strength==0,"A continuous beam pulse does not restart the camera kick for each victim")
	check(game.sound_calls.is_empty(),"Continuous beam contacts retain source beam audio without shared coin/reaction one-shots")
	check(game.player.impact_pause==0 and Engine.time_scale==1,"Beam impact never freezes its caster or dilates the world clock")
	check(game.visual_calls==0,"The beam keeps its own native contact visuals")
	benchmark_contacts(effect)
	reset_feedback();game.player.ai_controlled=true;game.player.ai_aim=effect.global_position+Vector3.RIGHT*100
	effect.damage_tick()
	check(contacts.size()==24 and game.sound_calls.is_empty(),"An allied continuous beam also confirms all victims without repeated shared impact audio")
	game.player.ai_controlled=false
	var target:Ninja=game.enemies[0]
	reset_feedback();game.confirm_impact(target,target.position,Vector3.RIGHT,1,true,14,true)
	check(game.camera_rig.kick_age==0 and game.sound_calls.size()==2 and game.visual_calls==1,"Ed's separate fireball impact retains its camera, sound and visual feedback")
	reset_feedback();game.confirm_ally_impact(target,target.position,Vector3.RIGHT,1,true,14,true)
	check(game.sound_calls.size()==1 and game.visual_calls==1,"Allied Ed fireballs retain their ordinary impact feedback")
	reset_feedback();game.confirm_impact(target,target.position,Vector3.RIGHT,1,true,2,false)
	check(game.camera_rig.kick_age==0 and game.sound_calls.size()==2,"Another character's projectile keeps feedback even when its shared visuals are omitted")
	reset_feedback();game.confirm_impact(target,target.position,Vector3.RIGHT,0,false,14,false)
	check(game.camera_rig.kick_age==0 and game.player.impact_pause>0 and game.sound_calls.size()==2,"Ed's melee contacts retain ordinary attacker hit pause and impact feedback")
	effect.stop();effect.free();game.queue_free();renderer.queue_free()
	await process_frame;await create_timer(.35).timeout
	print("RECOVERED_ED_BEAM_IMPACT_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func benchmark_contacts(effect):
	var samples=[];var total=0
	var calls_before=game.sound_calls.size()
	for pulse in 20:
		var begin=Time.get_ticks_usec();effect.damage_tick();var duration=Time.get_ticks_usec()-begin
		samples.append(duration);total+=duration
	print("RECOVERED_ED_BEAM_IMPACT_BENCHMARK ",JSON.stringify({"pulses":20,"victims_per_pulse":24,"mean_ms":float(total)/20000.0,"max_ms":samples.max()/1000.0,"min_ms":samples.min()/1000.0,"shared_sound_calls":game.sound_calls.size()-calls_before,"global_time_scale":Engine.time_scale,"scope":"Real beam path, fitted contacts, physics cover queries, Ninja damage/recoil, budgeted damage labels and impact dispatch; audio output recorded, rendering disabled"}))
