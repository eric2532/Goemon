extends Ninja
var forest_id=-1
func _physics_process(delta):
	if game.paused:return
	if dead:
		death_timer-=delta
		if death_timer<=0:queue_free()
		return
	if not game.model.enemies.has(forest_id):queue_free();return
	var data: Dictionary=game.model.enemies[forest_id]
	global_position=data.pos+Vector3.UP*.05;velocity=data.velocity
	stun=data.stun;frozen_left=data.get("frozen",0.0)
	if frozen_left<=0 and is_instance_valid(frozen_visual):frozen_visual.hide()
	impact_pause=maxf(0,impact_pause-delta);recoil_age+=delta;pulse+=delta
	state="windup" if data.attack else "chase";timer=.22 if data.attack else 0.0
	if velocity.length_squared()>.01:model.rotation.y=atan2(velocity.x,velocity.z)
	if data.hp<hp:
		super.take_hit(hp-data.hp,Vector3.UP,false,{"tower":true})
	bar.scale.x=maxf(.01,hp/max_hp)
func take_hit(damage: float,dir: Vector3,heavy: bool,ticket: Dictionary={}):
	super.take_hit(damage,dir,heavy,ticket)
	if game.model.enemies.has(forest_id):
		game.model.enemies[forest_id].hp=hp
		var data: Dictionary=game.model.enemies[forest_id]
		data.stun=maxf(data.stun,maxf(stun,impact_pause))
		data.knockback=Vector3(velocity.x,0,velocity.z)

func apply_rogue_bash(direction: Vector3):
	if dead or not game.model.enemies.has(forest_id):return
	var data: Dictionary=game.model.enemies[forest_id]
	data.knockback=data.get("knockback",Vector3.ZERO)+Vector3(direction.x,0,direction.z)*7
	data.clock=maxf(data.clock,1.2);data.stun=maxf(data.stun,.2)
func freeze_for(seconds: float):
	super.freeze_for(seconds)
	if not dead and game.model.enemies.has(forest_id):
		var data: Dictionary=game.model.enemies[forest_id]
		data.frozen=maxf(data.get("frozen",0.0),seconds);data.knockback=Vector3.ZERO
func apply_defense_slow(factor: float,seconds: float):
	if dead or not game.model.enemies.has(forest_id):return
	var data: Dictionary=game.model.enemies[forest_id]
	data.slow=minf(data.get("slow",1.0),clampf(factor,.1,1));data.slow_left=maxf(data.get("slow_left",0.0),seconds)
