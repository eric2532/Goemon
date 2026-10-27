extends "res://scripts/character_combat.gd"
## Player adapter; shared movement, native target queries, pooled shots and spells.
const Model=preload("res://scripts/kojiro_model.gd")
const Shot=preload("res://scripts/kojiro_projectile.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const ATTACK_RATE=2.0
const DAMAGE_SCALE=3.0
const POOL_SIZES={"homing":18,"wave":12,"wind":12,"spark":144,"dust":128}
const SWORD_SECTIONS=[
	{"action":"slash","clip":"Source__801e2b50","ticks":24},
	{"action":"air_cut","clip":"Ground__turning_cut","ticks":24},
	{"action":"air_spin","clip":"Ground__somersault_cut","ticks":30}]
var mode=""
var clip=""
var elapsed=0.0
var duration=0.0
var marker=0
var hits={}
var ticket={}
var spec={}
var queued=false
var air_combo=0
var combo=-1
var combo_timer=0.0
var contact_tick=15.0
var events:Array=[]

func prepare_projectiles():
	preload("res://scripts/kojiro_audio.gd").prepare()
	for kind in POOL_SIZES:Pool.service(game).warm(hero,Shot,kind,{"kind":kind},POOL_SIZES[kind])

func input(event:InputEvent):
	if not active or event.is_echo() or hero.dodge_time>0:return
	if event.is_action_pressed("light_attack"):
		if mode in ["slash","air_cut","air_spin"]:queued=true
		else:start_attack()
	elif event.is_action_pressed("heavy_attack"):start_skill("wave")
	elif event.is_action_pressed("equip"):start_skill("homing")
	elif event.is_action_pressed("surge"):start_skill("wind")
	elif event.is_action_pressed("sky_strike"):start_skill("wave")

func start_attack():
	var action="slash"
	if not hero.is_on_floor():
		action="air_cut" if air_combo%2==0 else "air_spin";air_combo+=1
	else:air_combo=0
	start_skill(action)

func start_skill(action:String):
	if is_attacking() or hero.hp<=0 or not Model.data().actions.has(action):return
	hero.facing=hero.combat_attack_direction();cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
	mode=action;spec=Model.data().actions[action]
	if action=="slash":
		combo=0 if combo_timer<=0 else (combo+1)%SWORD_SECTIONS.size()
		spec=Model.data().actions[SWORD_SECTIONS[combo].action]
	else:combo=-1;combo_timer=0
	clip=SWORD_SECTIONS[combo].clip if action=="slash" else spec.clip
	elapsed=0;marker=0;hits.clear();queued=false
	duration=float(SWORD_SECTIONS[combo].ticks if action=="slash" else spec.ticks)/30.0
	contact_tick=float(spec.get("contacts",[15])[0])
	events=spec.releases if spec.has("releases") else [contact_tick]
	ticket=hero.attack_chain.begin("kojiro_"+action,"primary_%d"%(combo+1) if action=="slash" else "")
	hero.attack_ticket=ticket
	if action=="slash":hero.combo=combo+1
	hero.attack_duration=(duration-elapsed)/ATTACK_RATE;hero.attack_left=hero.attack_duration
	if spec.has("voice"):sound(spec.voice)

func tick_timers(delta:float):combo_timer=maxf(0,combo_timer-delta)
func tick(delta:float,after_pose:bool=false):
	if after_pose or not active or game.paused or game.transitioning or not game.playing:return
	if mode=="hurt":
		elapsed+=delta
		if elapsed>=duration:cancel(true)
		return
	if not is_attacking():
		if spell_owner==null and hero.auto_attack_running():start_attack()
		return
	elapsed+=delta*hero.attack_speed_multiplier()*ATTACK_RATE
	hero.attack_left=maxf(0,(duration-elapsed)/ATTACK_RATE)
	while marker<events.size() and elapsed*30+.00001>=float(events[marker]):
		if spec.has("releases"):release(marker)
		else:strike()
		marker+=1
	if elapsed>=duration:
		var next=queued;finish_attack()
		if next:start_attack()

func strike():
	sound("sword_cut")
	var points: Array=Model.data().contacts.air_spin if spec.clip==Model.data().semantics.air_spin else Model.data().contacts.slash
	var visual=cast_model();var origin:Vector3=visual.source_point(points[0])
	var radius=24.0*visual.source_unit()*hero.melee_reach_setting()
	for endpoint in points.slice(1):
		var end:Vector3=visual.source_point(endpoint)
		end=origin+(end-origin)*hero.melee_reach_setting()*hero.pickup_multiplier("range")
		for enemy in AttackChain.segment_enemy_candidates(game,origin,end,radius):
			if not is_instance_valid(enemy) or enemy.dead or hits.has(enemy.get_instance_id()):continue
			if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
			var contact=AttackChain.segment_contact(enemy,origin,end,radius)
			if contact.is_empty() or not AttackChain.clear_line(hero,origin,AttackChain.aim_point(enemy,origin)):continue
			hits[enemy.get_instance_id()]=true
			enemy.take_hit(float(spec.damage)*DAMAGE_SCALE*hero.damage_multiplier(),hero.facing,false,ticket)
			if hero.ai_controlled:game.confirm_ally_impact(enemy,contact.point,hero.facing,1,false,28)
			else:game.confirm_impact(enemy,contact.point,hero.facing,1,false,28)

func release(index:int):
	var visual=cast_model()
	var unit=visual.source_unit()
	var point=visual.source_point([16,-32,-24] if mode=="homing" else [0,-32 if mode=="wave" else 0,-24])
	var direction:Vector3=hero.facing
	if mode=="wave":
		point=hero.global_position+Vector3.UP*1.65*hero.contact_size_multiplier()
		direction=(hero.ai_aim-point).normalized() if hero.ai_controlled else game.projectile_direction(point)
		if hero.is_on_floor():direction.y=0
		direction=direction.normalized() if direction.length_squared()>.001 else hero.facing
		point+=direction*.9*hero.contact_size_multiplier()
	# Launch just above the ground for the authored ground-hugging wind sheet.
	if mode=="wind":point.y=hero.global_position.y+.08
	if index==0:sound(spec.sound)
	var target=AttackChain.screen_target(hero,point,100.0,true) if mode=="homing" else null
	var spread:Array=spec.get("spread",[0])
	for angle in spread:
		Pool.service(game).launch(hero,Shot,mode,{"kind":mode,"position":point,"velocity":direction.rotated(Vector3.UP,float(angle)*TAU/4096)*(24 if mode=="homing" else 16)*30*unit,
			"target":target,"unit":unit,"size_factor":float(spec.scales[index]) if spec.has("scales") else 1.0,
			"damage":(32.0 if mode=="homing" else 48.0)*DAMAGE_SCALE*hero.damage_multiplier(),"attack_ticket":ticket.duplicate(true)})

func sound(key:String):game.sound("kojiro_"+key,.8,false,ticket,28)
func blade_active()->bool:
	if mode=="slash":return elapsed*30>=contact_tick-2 and elapsed*30<=contact_tick+6
	return is_attacking() and mode in ["air_cut","air_spin","wave","wind"]
func is_attacking()->bool:return Model.data().actions.has(mode)
func blocks_movement()->bool:return false
func ground_attack_velocity()->Vector3:return Vector3.ZERO if is_attacking() and hero.is_on_floor() else Vector3.INF
func protects_player()->bool:return false
func interrupt_for_dodge():cancel(true)
func hit():
	cancel(true);mode="hurt";clip=Model.data().semantics.hurt;duration=8.0/30
func die():
	cancel();mode="dead";clip=Model.data().semantics.death;cast_model().pose(clip,0)
func finish_attack():
	if mode=="slash":combo_timer=.85
	mode="";clip="";elapsed=0;marker=0;queued=false;hits.clear();ticket={};spec={};events=[];hero.attack_left=0
func cancel(_preserve_power:bool=false):
	finish_attack();combo=-1;combo_timer=0;air_combo=0
	if is_instance_valid(cast_model()) and is_instance_valid(cast_model().trail):cast_model().trail.clear()
