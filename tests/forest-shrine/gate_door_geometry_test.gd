extends SceneTree
const Art=preload("res://scripts/forest/forest_art.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const Painterly=preload("res://scripts/forest/forest_painterly_pilot.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func ray(gate:Node3D,from:Vector3,to:Vector3,mask:int)->Dictionary:
	return gate.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(gate.to_global(from),gate.to_global(to),mask))
func run():
	for rotation in 4:
		var gate=Art.building({"kind":"gate","id":100+rotation,"rotation":rotation});root.add_child(gate)
		var door=gate.get_node("GateDoor")
		check(door.mesh.size.x>=9.5 and door.mesh.size.y>=11.0,"Door %d fills the larger entrance"%rotation)
		check(is_zero_approx(door.position.y-door.mesh.size.y*.5),"Closed door %d reaches the ground"%rotation)
		var bodies=door.find_children("*","StaticBody3D",true,false)
		check(bodies.size()==1 and bodies[0].collision_layer==32,"Door %d owns its movable layer-32 collider"%rotation)
		await physics_frame
		check(ray(gate,Vector3(4.7,2,-4),Vector3(4.7,2,4),1).is_empty(),"Opening %d remains clear to the widened edge"%rotation)
		check(ray(gate,Vector3(0,10.5,-4),Vector3(0,10.5,4),1).is_empty(),"Stone header %d clears the taller doorway"%rotation)
		check(not ray(gate,Vector3(5.4,2,-4),Vector3(5.4,2,4),1).is_empty(),"Gate %d retains solid permanent pillars"%rotation)
		check(not ray(gate,Vector3(0,11.5,-4),Vector3(0,11.5,4),1).is_empty(),"Gate %d retains a solid permanent header"%rotation)
		check(not ray(gate,Vector3(4.7,2,-4),Vector3(4.7,2,4),32).is_empty(),"Closed leaf %d covers the widened entrance"%rotation)
		check(not ray(gate,Vector3(0,10.5,-4),Vector3(0,10.5,4),32).is_empty(),"Closed leaf %d covers the taller entrance"%rotation)
		var damage=gate.get_node("WallDamage")
		var fracture_bounds=damage.get_node("Fractures").mesh.get_aabb()
		check(fracture_bounds.size.x>9.5 and fracture_bounds.position.x>=-4.83 and fracture_bounds.end.x<=4.83 and fracture_bounds.end.y<=11.01,"Door %d fractures cover only its larger leaf"%rotation)
		door.position.y=Profile.GATE_OPEN_Y;damage.sync_health(1000,2000,0)
		await physics_frame
		check(door.position.y+door.mesh.size.y*.5<=Profile.GATE_HEIGHT and door.position.y-door.mesh.size.y*.5>=11.0,"Raised leaf %d fits behind the stone header"%rotation)
		check(ray(gate,Vector3(0,2,-4),Vector3(0,2,4),32).is_empty(),"Raised leaf %d moves its collider out of the passage"%rotation)
		check(is_equal_approx(damage.position.y,door.position.y-Profile.GATE_CLOSED_Y),"Cracks %d follow the raised leaf"%rotation)
		door.hide()
		for body in bodies:body.collision_layer=0
		await physics_frame
		check(not ray(gate,Vector3(5.4,2,-4),Vector3(5.4,2,4),1).is_empty() and not ray(gate,Vector3(0,11.5,-4),Vector3(0,11.5,4),1).is_empty(),"Removing leaf %d leaves its stone frame solid"%rotation)
		gate.free()
	var details=Node3D.new();root.add_child(details)
	var painterly=Painterly.new(null);painterly.gate_details(details)
	for part in details.find_children("*","MeshInstance3D",true,false):
		var box:AABB=part.transform*part.mesh.get_aabb()
		check(box.end.x<=-4.79 or box.position.x>=4.79,"Painterly gate decoration stays outside the doorway")
	details.free()
	painterly=null
	await process_frame
	await process_frame
	print("GATE_DOOR_GEOMETRY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
