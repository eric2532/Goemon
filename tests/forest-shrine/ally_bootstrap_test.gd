extends SceneTree
const GuardFixture=preload("res://tests/forest-shrine/guard_combat_fixture.gd")
var failures=0
var checks=0
var native_models=0
var game
var config_path="user://ally-bootstrap-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func count_native_model(node:Node):
	if node.get_script()==game.player.ROSTER[1].model:native_models+=1
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate()
	game.settings_path=config_path;root.add_child(game);current_scene=game
	await process_frame
	node_added.connect(count_native_model)
	var start=Time.get_ticks_usec()
	var units=[]
	for slot in game.explorer_helpers.KITS.size():
		var unit=game.explorer_helpers.make_unit(slot);units.append(unit)
		check(unit.character_id==game.explorer_helpers.KITS[slot],"Ally starts with its assigned kit")
		check(unit.character_models.size()==1 and unit.character_models.has(unit.kit_id),"Ally retains exactly its assigned visual")
		check(unit.model==unit.character_models[unit.kit_id] and unit.active_ability==unit.character_abilities[unit.kit_id],"Visual and native combat use the same kit")
		check(unit.hp==game.explorer_helpers.HEALTH[slot] and unit.max_hp==unit.hp,"Kit health initialized")
		check(unit.state=="idle" and not unit.visible and not unit.is_physics_processing(),"New pooled ally is parked")
	var elapsed=(Time.get_ticks_usec()-start)/1000.0
	node_added.disconnect(count_native_model)
	check(native_models==0,"Summoning never creates a discarded native Goemon model (created %d)"%native_models)
	game.player.select_character(11)
	check(GuardFixture.deploy(game.explorer_helpers,1),"A Ranger fixture still activates its assigned kit")
	check(game.explorer_helpers.active_units().size()==1,"Ranger deployment contains one individual ally")
	check(is_instance_valid(game.player.character_models[1]),"Player retains the selectable native Goemon")
	print("ALLY_BOOTSTRAP_PROFILE ",JSON.stringify({"five_kits_ms":elapsed,"discarded_native_models":native_models}))
	await game.quit_clean()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("ALLY_BOOTSTRAP_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
