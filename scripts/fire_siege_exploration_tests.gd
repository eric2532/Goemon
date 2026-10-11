extends SceneTree
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
func run():
	var world=TowerDefenseWorld.new();world.redesign_mode=true
	if world.get("expanded_mode")==null:
		check(false,"Expanded world can opt into explorable bounds");world.free();finish();return
	world.set("expanded_mode",true);root.add_child(world);world.set_process(false)
	check(world.playable_bounds==Rect2(-160,50,320,480),"Expanded field includes side districts")
	check(world.lanes[1][0]==Vector3(0,0,110) and world.lanes[1][-1]==Vector3(0,0,220),"Enemy approach is 110 metres")
	check(world.cannon_sites.size()==12 and world.mine_sites.size()==4,"Twelve towers and four mines retained")
	check(world.height_at(95,400)==0,"Exploration keeps flat movement contract")
	await physics_frame
	var clear=true
	for x in [-5.5,0,5.5]:
		clear=clear and root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,1,110),Vector3(x,1,218),1)).is_empty()
	check(clear,"Physical approach remains clear through both walls")
	for site in world.cannon_sites:
		check(world.playable_bounds.has_point(Vector2(site.build_position.x,site.build_position.z)),"Tower work pad stays in bounds")
	world.free()
	var legacy=TowerDefenseWorld.new();legacy.beta_mode=true;root.add_child(legacy);legacy.set_process(false)
	check(legacy.playable_bounds==Rect2(-80,50,160,310) and legacy.cannon_sites.size()==8,"Compact legacy layout stays intact")
	legacy.free();finish()
func finish():
	print("EXPLORATION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
