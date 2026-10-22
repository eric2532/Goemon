class_name EnergyPickup
extends Node3D
const DROP_KINDS=["attack_speed","ice","fire"]
const COLORS={"attack_speed":Color("ffe35c"),"ice":Color("70ddff"),"fire":Color("ff6838"),"damage":Color("ffe35c"),"range":Color("ff5268")}
const LABELS={"ice":"ICE", "fire":"FIRE", "damage":"DAMAGE +50%", "range":"EXTENDED RANGE", "attack_speed":"ATTACK SPEED +50%"}
const DURATION=20.0
const ATTRACT_RADIUS=8.0
var game: Node
var kind="attack_speed"
var age=0.0
var remaining=90.0
var orb: Node3D
var attracted=false
var magnetized=false
var collected=false
var flight_speed=24.0
func _ready():
	add_to_group("energy_pickups")
	process_mode=Node.PROCESS_MODE_PAUSABLE
	orb=Node3D.new();add_child(orb)
	var color: Color=COLORS[kind]
	var material=Geo.mat(color.to_html(false),.15,1.3)
	Geo.sphere(orb,Vector3.ZERO,Vector3.ONE*.48,material)
	if kind=="ice":
		for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:Geo.beam(orb,-axis*.36,axis*.36,.035,material)
	elif kind=="fire":Geo.spike(orb,Vector3.ZERO,Vector3(0,.6,0),.22,material)
	else:
		var halo=Geo.torus(orb,Vector3.ZERO,.30,.34,material);halo.rotation.x=PI/3
func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning:return
	age+=delta
	if not attracted:remaining-=delta
	if remaining<=0:queue_free();return
	orb.position.y=.85+sin(age*4)*.16+maxf(0,1-age*2)*.6
	orb.rotation.y+=delta*2
	orb.visible=remaining>4 or int(age*8)%2==0
	var hero=game.player
	if hero.hp<=0:return
	var distance=global_position.distance_to(hero.global_position)
	if not attracted and distance<=ATTRACT_RADIUS:
		var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,hero.global_position+Vector3.UP,1)
		attracted=get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	if not attracted:return
	# Remember proximity immediately, even when a fast runner leaves before the
	# small drop animation finishes; the orb will still chase and catch them.
	if age<.35 and not magnetized:return
	flight_speed=minf(180,flight_speed+delta*100)
	var speed=maxf(flight_speed,hero.velocity.length()+24)
	if magnetized:speed=maxf(speed,distance*3)
	global_position=global_position.move_toward(hero.global_position,speed*delta)
	if global_position.distance_to(hero.global_position)>.9:return
	collect()

func attract_from_magnet():
	if collected:return
	magnetized=true;attracted=true

func collect():
	if collected:return
	collected=true
	var hero=game.player
	hero.collect_powerup(kind)
	game.orb_system.pickup_feedback(kind)
	queue_free()
