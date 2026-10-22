extends RefCounted
## Hero movement contract for the recovered Halo character rig.
var model:Node3D
var step_events=0
var free_feet=false
var reference_jump_flip=-1.0
var jump_compression=0.0
var grounded=true
var vertical=0.0
var actual_speed=0.0
var phase=0.0
var step_clock=0.0
func _init(owner_model:Node3D):model=owner_model
func update(delta:float,velocity_world:Vector3,on_floor:bool,vy:float,_attack:float,_dodge:bool):
	grounded=on_floor;vertical=vy
	actual_speed=Vector2(velocity_world.x,velocity_world.z).length()
	phase+=delta
	if grounded and actual_speed>.25:
		step_clock+=delta*maxf(2.5,actual_speed*.9)
		while step_clock>=1.0:step_events+=1;step_clock-=1.0
	else:step_clock=0
func evaluate():
	model.body.position.y=sin(phase*2.0)*.006 if grounded and actual_speed<.25 else 0.0
func reset():
	phase=0;step_clock=0;actual_speed=0;free_feet=false
func attach_weapons():pass
