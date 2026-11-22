extends RefCounted
## Optional movement on the existing Hero body. Attacks retain their own motion.
const Roster=preload("res://scripts/rogue_roster.gd")
const MusashiMotion=preload("res://scripts/recovered_musashi_locomotion.gd")
const STYLES={
	"double":{"name":"Goemon · Double Jump","source":1,"jumps":2,"description":"Jump again in the air. Uses Goemon's jump tuning."},
	"single":{"name":"Master Chief · Single Jump","source":18,"jumps":1,"description":"One grounded jump. Uses Chief's jump tuning."},
	"dragoon":{"name":"Dragoon · High Jump / Hover","source":8,"jumps":1,"description":"One high leap; hold Space to hover at the apex."},
	"ranger":{"name":"Ranger · Double Jump / Glide","source":10,"jumps":2,"description":"Two high jumps; hold Space while falling to glide."},
	"musashi":{"name":"Musashi · Variable Double Jump","source":13,"jumps":2,"description":"Musashi's original jump timing and second jump. Release Space to shorten the rise."},
	"sonic":{"name":"Sonic · Variable Jump","source":19,"jumps":1,"description":"Sonic's jump height and gravity. Release Space for a short hop. No contact damage or homing."},
	"ben":{"name":"Ben · Propeller Flight","source":15,"jumps":0,"description":"Hold Space to rise, release to descend. Hold Shift to boost. No bombs or attacks."}
}
var hero
var selected=""
var character=0
var gliding=false
var hovering=false
var coyote=0.0
var sonic:Dictionary={}
var sonic_speed=0.0
var sonic_hz=0.0
var sonic_source:Script
var sonic_ticks=0.0
var musashi_motion:RefCounted
var musashi_until_tick=0.0
var musashi_vertical=0.0

func _init(owner):hero=owner
func active()->bool:return not selected.is_empty() and (hero.ai_controlled or not hero.game.has_method("forest_enemy_visible"))

static func valid_assignments(value:Variant)->Dictionary:
	var result={}
	if not value is Dictionary:return result
	for key in value:
		var id=str(key)
		if not id.is_valid_int() or id!=str(int(id)) or int(id) not in Roster.PLAYABLE_IDS:continue
		if value[key] is String and STYLES.has(value[key]):result[id]=value[key]
	return result

func assignment(id:int)->String:
	return str(valid_assignments(hero.game.settings.get("jump_styles",{})).get(str(id),""))

func equip(id:int,style:String)->bool:
	if id not in Roster.PLAYABLE_IDS or (not style.is_empty() and not STYLES.has(style)):return false
	var saved=valid_assignments(hero.game.settings.get("jump_styles",{}))
	if style.is_empty():saved.erase(str(id))
	else:saved[str(id)]=style
	hero.game.settings.jump_styles=saved;hero.game.save_settings()
	prepare()
	return true

func prepare():
	var next=assignment(hero.character_id)
	if next.is_empty() and hero.character_id==28:next="musashi"
	if selected==next and character==hero.character_id:return
	if character==hero.character_id and not active() and hero.is_rogue_character():
		hero.active_ability._restore_ranger_fall();hero.active_ability.player.dragoonHovering=false
	if gliding and hero.velocity.y<0:hero.velocity.y*=3.0
	gliding=false;hovering=false;coyote=0
	selected=next;character=hero.character_id
	hero.jump_buffer=0;hero.jump_windup=0;hero.air_turn=0;hero.reset_wall_jump()
	# Changing equipment in midair never replenishes the jump budget.
	if not hero.is_on_floor():hero.jumps_used=maxi(hero.jumps_used,hero.maximum_jumps())
	if selected=="sonic" and sonic.is_empty():
		sonic_source=load("res://scripts/sonic_combat.gd")
		sonic=sonic_source.physics_parameters();sonic_speed=sonic_source.SPEED_UNIT;sonic_hz=sonic_source.HZ
	if selected=="musashi":
		musashi_motion=MusashiMotion.new();musashi_until_tick=0;musashi_vertical=hero.velocity.y
		musashi_motion.airborne=not hero.is_on_floor();musashi_motion.jumps_used=hero.jumps_used
		musashi_motion.source_vertical=int(-hero.velocity.y/musashi_scale())
	if character==13 and hero.active_ability!=null:
		var motion=hero.active_ability.locomotion
		motion.reset();motion.airborne=not hero.is_on_floor();motion.jumps_used=hero.jumps_used
		motion.source_vertical=int(-hero.velocity.y/motion.vertical_velocity_scale())

func maximum_jumps()->int:
	if selected=="musashi":return 2
	return maxi(4,int(STYLES[selected].jumps)) if hero.scarf_equipped and character!=13 else int(STYLES[selected].jumps)

func ben_flight()->bool:return selected=="ben" or (not active() and hero.character_id==15)
func held()->bool:return not hero.ai_controlled and Input.is_action_pressed("jump")
func boosted()->bool:return not hero.ai_controlled and Input.is_action_pressed("sprint")
func flight_speed()->float:
	return ((36.0 if boosted() else 21.0) if ben_flight() else (64.0 if boosted() else 36.0))*hero.progression.movement_multiplier()*hero.food_multiplier("movement_speed")*float(hero.accessory_bonuses.get("movement_speed",1.0))

func update_flight():
	hero.flying=hero.can_fly() and (held() or not hero.is_on_floor())

func steer_flight(delta:float,direction:Vector3):
	var motion=Vector3(hero.velocity.x,0,hero.velocity.z).move_toward(direction*flight_speed(),90.0*hero.progression.movement_multiplier()*delta)
	hero.velocity.x=motion.x;hero.velocity.z=motion.z

func step(delta:float,allow_jump:bool=true):
	var grounded:bool=hero.is_on_floor()
	if grounded:
		coyote=.13;hero.jumps_used=0;gliding=false;hovering=false
	else:coyote=maxf(0,coyote-delta)
	if hero.flying:
		hero.jump_buffer=0;hero.jump_windup=0;hero.air_turn=0;gliding=false;hovering=false
		if ben_flight():
			hero.velocity.y=move_toward(hero.velocity.y,hero.BEN_FLIGHT_BOOST_ASCENT_SPEED if boosted() else hero.BEN_FLIGHT_ASCENT_SPEED,120.0*delta) if held() and (allow_jump or not grounded) else -hero.BEN_DESCENT_SPEED
		else:hero.velocity.y=move_toward(hero.velocity.y,(32.0 if boosted() else 18.0) if held() and (allow_jump or not grounded) else -10.0,60.0*delta)
		return
	if allow_jump and hero.jump_buffer>0 and not grounded and hero.wall_jump_grace>0 and hero.wall_jump_recovery<=0:
		hero.perform_wall_jump();coyote=0;gliding=false;hovering=false
		if selected=="musashi":
			musashi_motion.airborne=true;musashi_motion.jumps_used=hero.jumps_used
			musashi_motion.source_vertical=int(-hero.velocity.y/musashi_scale())
			musashi_vertical=hero.velocity.y;musashi_until_tick=MusashiMotion.TICK
	if selected=="musashi":
		step_musashi(delta,allow_jump)
		return
	var launched=false
	if hero.jump_buffer>0 and allow_jump:
		if coyote>0 or hero.jumps_used<maximum_jumps():
			var first=coyote>0
			hero.jumps_used=1 if first else maxi(2,hero.jumps_used+1)
			var key="jump_speed" if first else "second_jump_speed"
			hero.velocity.y=float(sonic.jmp_y_spd)*sonic_speed*hero.combat_tuning("jump_height") if selected=="sonic" else hero.game.balance_value(int(STYLES[selected].source),key)*sqrt(hero.combat_tuning("jump_height"))*hero.progression.jump_velocity_multiplier()
			hero.air_turn=.42 if not first else 0.0
			hero.jump_buffer=0;coyote=0;gliding=false;hovering=false;launched=true;sonic_ticks=0
			hero.play_sound("jump")
	if selected=="sonic":
		if not grounded or launched:
			var ticks=sonic_hz*delta
			hero.velocity.y=sonic_source.jump_velocity(hero.velocity.y/hero.combat_tuning("jump_height"),ticks,held() and hero.jumps_used>0,sonic_ticks)*hero.combat_tuning("jump_height")
			if held() and hero.jumps_used>0:sonic_ticks+=ticks
	elif not grounded:
		var fall:float=hero.velocity.y*3.0 if gliding and hero.velocity.y<0 else hero.velocity.y
		fall=maxf(-55,fall-30*delta)
		gliding=selected=="ranger" and fall<0 and held()
		hovering=selected=="dragoon" and fall<=0 and held()
		hero.velocity.y=0.0 if hovering else fall/3.0 if gliding else fall
	elif not launched and hero.velocity.y<0:hero.velocity.y=0

func musashi_scale()->float:
	return MusashiMotion.TO_VELOCITY*preload("res://scripts/character_proportions.gd").MUSASHI_SIZE*hero.combat_tuning("jump_height")

func step_musashi(delta:float,allow_jump:bool):
	if hero.is_on_ceiling() and musashi_motion.source_vertical<0:
		musashi_motion.source_vertical=0;musashi_vertical=0
	var remaining=delta
	var distance=0.0
	while remaining>.00000001:
		if musashi_until_tick<=.00000001:
			var before:int=musashi_motion.jumps_used
			musashi_motion.source_tick(Vector3.ZERO,hero.is_on_floor(),hero.jump_buffer>0 and allow_jump,held(),false,false)
			musashi_vertical=-musashi_motion.source_vertical*musashi_scale()
			# The source's takeoff entry consumes one tick without travelling.
			if before==0 and musashi_motion.jumps_used==1:musashi_vertical=0
			if musashi_motion.jumps_used>before:hero.play_sound("jump")
			hero.jump_buffer=0;musashi_until_tick=MusashiMotion.TICK
		var part=minf(remaining,musashi_until_tick)
		distance+=musashi_vertical*part;remaining-=part;musashi_until_tick-=part
	hero.velocity.y=distance/delta;hero.jumps_used=musashi_motion.jumps_used
