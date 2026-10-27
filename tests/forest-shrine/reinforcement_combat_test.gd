extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
var checks=0
var failures=0
var runtime
var model
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func fresh():
	runtime.clear();runtime.navigation_revision=-1;runtime.set_navigation(1,{"width":0})
func sample(kind:int,scale_:float,external:bool)->Vector2:
	fresh()
	var enemy=runtime.spawn(1,0,kind,Vector3.ZERO,100000,.4)
	check(runtime.native.set_enemy_scaling(enemy,1.2,scale_),"Accept valid enemy scaling")
	var targets={}
	if external:targets={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3(0,0,-3)]),"hp":PackedFloat32Array([100000000])}
	else:runtime.spawn(-1,1,12,Vector3(0,0,-3),100000000,.4)
	var result=Vector2.ZERO
	for tick in 1800:
		runtime.step(1.0/60,{"targets":targets})
		for event in runtime.take_events():
			if event.source_id==1 and event.kind in ["damage","external_damage"] and event.amount>0:
				result.x+=event.amount;result.y+=1
	return result
func orphan_bullet(scale_:float)->float:
	fresh()
	var enemy=runtime.spawn(1,0,1,Vector3.ZERO,100,.4)
	runtime.native.set_enemy_scaling(enemy,1.0,scale_)
	var targets={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3(0,0,-8)]),"hp":PackedFloat32Array([100000])}
	for tick in 300:
		runtime.step(1.0/60,{"targets":targets})
		for event in runtime.take_events():
			if event.kind=="bullet":runtime.despawn(enemy)
			if event.kind=="external_damage":return event.amount
	return 0
func run():
	model=Model.new();model.reset(42,{}, {},false)
	runtime=Runtime.new();check(runtime.configure(null),"Native runtime loads")
	var kits=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(model)
	runtime.configure_kits(kits)
	for kind in model.Balance.TYPES:
		for external in [false,true]:
			var base=sample(kind,1.0,external);var stronger=sample(kind,1.3,external)
			check(base.x>0 and base.y==stronger.y and is_equal_approx(stronger.x,base.x*1.3),"Kind %d scales real damage once, retaining contacts (external=%s, base=%s, scaled=%s)"%[kind,external,base,stronger])
	var bullet=orphan_bullet(1.0)
	check(bullet>0 and is_equal_approx(orphan_bullet(1.3),bullet*1.3),"In-flight bullets retain scaled damage after shooter retirement")
	fresh()
	var enemy=runtime.spawn(1,0,6,Vector3.ZERO,120,.4)
	var ally=runtime.spawn(-1,1,12,Vector3(20,0,0),100,.4)
	check(not runtime.native.set_enemy_scaling(ally,1.2,1.1),"Enemy scaling cannot change allies")
	for values in [[NAN,1.0],[1.0,INF],[0.0,1.0],[1.0,-1.0]]:
		check(not runtime.native.set_enemy_scaling(enemy,values[0],values[1]),"Reject invalid scaling")
	runtime.native.set_enemy_scaling(enemy,1.4,1.2);runtime.configure_kits(kits)
	var hit=runtime.apply_hit(enemy,{"amount":1000.0})
	var state=runtime.unit_state(enemy)
	check(hit.accepted and not hit.dead and state.kind==14 and is_equal_approx(state.max_hp,model.waves.role_stats(14).hp*1.4),"Vambee retains scaled health through form changes and profile refresh")
	check(not runtime.take_events().any(func(event):return event.kind=="death"),"Changing form awards no extra defeat")
	runtime.despawn(enemy)
	check(not runtime.native.set_enemy_scaling(enemy,2.0,2.0),"Stale handles cannot scale a recycled unit")
	var replacement=runtime.spawn(2,0,6,Vector3.ZERO,100,.4)
	runtime.apply_hit(replacement,{"amount":1000.0})
	check(is_equal_approx(runtime.unit_state(replacement).max_hp,model.waves.role_stats(14).hp),"Reused slots reset scaling to the opening strength")
	runtime.clear();runtime.free()
	print("REINFORCEMENT_COMBAT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
