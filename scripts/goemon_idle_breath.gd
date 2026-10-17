extends RefCounted
## A quiet 3.6-second breath shared by the original Goemon body and its costumes.
## Advance only with simulation time; skeleton sampling never advances the clock.
const Body=preload("res://scripts/goemon_reference_run_body.gd")
var phase=0.0
var weight=0.0
var allowed=false

func reset():
	phase=0;weight=0;allowed=false

func update(delta: float,speed: float,grounded: bool,busy: bool):
	var dt=maxf(0,delta)
	phase=fposmod(phase+dt/3.6,1.0)
	allowed=grounded and not busy
	var target=1.0-smoothstep(.08,1.3,maxf(0,speed)) if allowed else 0.0
	weight=move_toward(weight,target,dt*(6.0 if target<weight else 2.0))

func apply(sk: Skeleton3D):
	if not allowed or weight<.001:return
	var breath=sin(TAU*phase)*weight
	# Lift only the upper body. Soles and pelvis stay planted; no mesh scaling.
	var spine=sk.find_bone("Spine");var shifted={}
	for i in range(sk.get_bone_count()):
		var ancestor=i
		while ancestor>=0 and ancestor!=spine:ancestor=sk.get_bone_parent(ancestor)
		if ancestor!=spine:continue
		var value=sk.get_bone_global_pose(i);value.origin.y+=.018*breath;shifted[i]=value
	for i in shifted:sk.set_bone_global_pose(i,shifted[i])
	Body.turn_chain(sk,"Spine",Vector3(-.012*breath,0,0))
	Body.turn_chain(sk,"Chest",Vector3(-.018*breath,0,0))
	Body.turn_chain(sk,"Neck",Vector3(.019*sin(TAU*(phase-.045))*weight,0,0))
	Body.turn_chain(sk,"Arm_L",Vector3(0,0,-.012*breath))
	Body.turn_chain(sk,"Arm_R",Vector3(0,0,.012*breath))
