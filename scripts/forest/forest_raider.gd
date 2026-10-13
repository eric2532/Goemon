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
	stun=maxf(0,stun-delta);impact_pause=maxf(0,impact_pause-delta);recoil_age+=delta;pulse+=delta
	state="windup" if data.attack else "chase";timer=.22 if data.attack else 0.0
	if velocity.length_squared()>.01:model.rotation.y=atan2(velocity.x,velocity.z)
	if data.hp<hp:
		super.take_hit(hp-data.hp,Vector3.UP,false,{"tower":true})
	bar.scale.x=maxf(.01,hp/max_hp)
func take_hit(damage: float,dir: Vector3,heavy: bool,ticket: Dictionary={}):
	super.take_hit(damage,dir,heavy,ticket)
	if game.model.enemies.has(forest_id):
		game.model.enemies[forest_id].hp=hp
		game.model.enemies[forest_id].stun=maxf(stun,impact_pause)
