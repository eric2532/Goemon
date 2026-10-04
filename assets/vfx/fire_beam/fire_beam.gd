class_name EdoFireBeam
extends Node3D
# A piercing volume: blue-orb stacks increase length and damage pulse rate.
var attack_ticket: Dictionary={}
var game: Node
var hero: Hero
var ability: Node
var balance: MusashiBalance
var remaining=3.0
var tick_left=0.0
var elapsed=0.0
var active=true
var sustained=false
var length_now=0.0
var direction=Vector3.FORWARD
var shells: Array[MeshInstance3D]=[]
var rings: Array[MeshInstance3D]=[]
var source: FireEnergy
var tip: FireEnergy
var loop: AudioStreamPlayer3D
func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	add_to_group("projectiles");add_to_group("musashi_projectiles");add_to_group("edo_beams")
	remaining=balance.beam_duration
	for i in range(3):
		var material=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color=[Color("ff3c10"),Color("ff931f"),Color("fff4b0")][i]
		material.emission_enabled=true;material.emission=material.albedo_color;material.emission_energy_multiplier=1.5
		if i<2:
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a=.25 if i==0 else .5
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		var shell=Geo.cylinder(self,Vector3.ZERO,balance.beam_radius*[1.0,.79,.42][i],1,material)
		shell.rotation.x=PI/2;shell.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;shells.append(shell)
	for i in range(12):
		var ring=Geo.torus(self,Vector3.ZERO,balance.beam_radius*.84,balance.beam_radius*.95,Geo.mat("ffab32",0,1.8))
		ring.rotation.x=PI/2;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;rings.append(ring)
	source=FireEnergy.new();source.charged=true;add_child(source);source.scale=Vector3.ONE*2.6
	tip=FireEnergy.new();tip.charged=true;add_child(tip);tip.scale=Vector3.ONE*3
	var light=OmniLight3D.new();light.light_color=Color("ff7528");light.light_energy=2;light.omni_range=8;add_child(light)
	loop=AudioStreamPlayer3D.new();loop.stream=game.sound_library.custom.get("edo_beam_loop",game.sounds.edo_beam_loop).duplicate()
	loop.stream.loop_end=int(loop.stream.get_length()*loop.stream.mix_rate);loop.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	loop.volume_db=linear_to_db(.35*float(game.sound_library.gains.get("edo_beam_loop",1)));loop.pitch_scale=1.0 if game.sound_library.custom.has("edo_beam_loop") else .8;add_child(loop);loop.play()
	update_path()
func update_path():
	direction=game.attack_direction()
	global_position=hero.global_position+(Vector3.UP*1.65+direction*.8)*hero.growth_multiplier()
	if game.rogue_battle_mode:direction=game.projectile_direction(global_position)
	length_now=balance.beam_length*hero.base_attack_speed_multiplier()*hero.growth_multiplier()
	if hero.growth_multiplier()>1.01 and not game.rogue_battle_mode:
		var target=AttackChain.screen_target(hero,global_position,length_now)
		if target!=null:direction=(AttackChain.aim_point(target)-global_position).normalized()
	look_at(global_position+direction,Vector3.UP)
	var pulse=1.0+sin(elapsed*32)*.045
	for i in range(shells.size()):
		shells[i].position.z=-length_now*.5
		shells[i].scale=Vector3(pulse,maxf(.01,length_now),pulse)
	for i in range(rings.size()):
		var t=fmod(elapsed*1.6+float(i)/rings.size(),1.0)
		rings[i].position.z=-t*length_now;rings[i].scale=Vector3.ONE*(.8+sin(t*TAU+elapsed*12)*.13)
	tip.position.z=-length_now
func damage_tick():
	var end=global_position+direction*length_now
	BreakableBuilding.hit_segment(game,global_position,end,balance.beam_tick_damage*hero.damage_multiplier(),attack_ticket)
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		var target=enemy.global_position+Vector3.UP*(1.5 if enemy.boss else 1.1)
		var along=(target-global_position).dot(direction)
		if along<0 or along>length_now:continue
		var nearest=Geometry3D.get_closest_point_to_segment(target,global_position,end)
		if nearest.distance_to(target)>balance.beam_radius+enemy.body_radius:continue
		enemy.take_hit(balance.beam_tick_damage*hero.damage_multiplier(),direction,false,attack_ticket)
		game.confirm_impact(enemy,nearest,direction,1,true)
		game.burst(nearest,Color("ff8d32"),3,.7)
		game.chain+=1;game.chain_timer=3
func _physics_process(delta):
	if not active:return
	if not is_instance_valid(hero) or hero.hp<=0 or hero.character_id!=2:stop();return
	if not game.playing or game.paused or game.transitioning:return
	if not sustained:remaining=maxf(0,remaining-delta)
	elapsed+=delta
	if not sustained and remaining<=0:
		if is_instance_valid(ability):ability.finish_beam(self)
		stop();return
	update_path();tick_left-=delta*hero.attack_speed_multiplier()
	while tick_left<=0:
		tick_left+=maxf(.05,balance.beam_tick);damage_tick()
func stop():
	active=false;hide()
	if is_instance_valid(loop):loop.stop()
	queue_free()
