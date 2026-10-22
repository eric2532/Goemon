extends SceneTree
var game
var checks=0
var failures=0
var cfg="user://barracks-shelter-%d.cfg"%OS.get_process_id()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func _initialize():
	set_meta("forest_army_backend","legacy")
	create_timer(60).timeout.connect(func():printerr("FAIL: shelter timeout");quit(1))
	run.call_deferred()
func frames():
	for i in 3:await process_frame
func run():
	var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
	await frames();AudioServer.set_bus_mute(0,true)
	var m=game.model;var h=game.explorer_helpers
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
	m.gold=5000
	var b=m.build("barracks",Vector2i(12,10),0)
	check(not b.is_empty(),"A barracks can be built on reachable ground")
	game.world.sync(0)
	var point=m.point(Vector2i(5,10))
	check(h.purchase(1,point),"A Ranger can be hired with available food")
	if h.active_units().is_empty():await finish();return
	var unit=h.active_units()[0];unit.set_physics_process(false);h.set_process(false)
	var original_post=unit.guard_post
	check(unit.get("shelter")!=null,"Hired fighters have automatic shelter behavior")
	if unit.get("shelter")==null:await finish();return
	var used=m.food_used();m.starting_food=used-5
	var money=m.gold
	check(not h.purchase(1,m.point(Vector2i(7,10))) and m.gold==money,"A fighter needing two food cannot bypass a full population")
	m.phase="wave";game.paused=false;paused=false;unit.state="acting";unit.hp=25;unit.invuln=0
	unit.shelter.tick(.1)
	check(unit.state=="retreating" and unit.ai_move.length()>.1,"Weak fighter starts walking toward a reachable barracks")
	check(h.target_actor(unit.gate_id)==unit and unit.visible,"Retreating fighter remains visible and targetable")
	unit.set_physics_process(true)
	for i in 20:await physics_frame
	unit.set_physics_process(false)
	check(unit.global_position.distance_to(original_post)>.5,"Retreat drives the real fighter movement controller")
	unit.set_physics_process(true)
	for i in 720:
		if unit.state=="sheltered":break
		await physics_frame
	unit.set_physics_process(false);h.sync_targets()
	check(unit.state=="sheltered","Fighter walks the full route past the barracks collider and enters unaided")
	check(unit.state=="sheltered" and not unit.visible and h.target_actor(unit.gate_id)==null,"Arriving fighter hides and leaves enemy targeting")
	check(h.active_units().size()==1 and m.food_used()==used,"Hidden fighter still occupies food capacity")
	var hp=unit.hp;unit.invuln=0;unit.take_hit(100,Vector3.FORWARD)
	check(unit.hp==hp,"Bunker interior protects a fighter from damage")
	unit.shelter.tick(1)
	check(is_equal_approx(unit.hp,hp+10),"Shelter restores ten health per second")
	game.ordinary_pause=true;unit.shelter.tick(2)
	check(is_equal_approx(unit.hp,hp+10),"Pause freezes shelter healing")
	game.ordinary_pause=false;unit.shelter.tick(20)
	check(unit.hp==unit.max_hp and unit.state=="returning" and unit.visible,"Full health releases the fighter onto open ground")
	check(unit.guard_post==original_post,"Shelter preserves the fighter's assigned guard post")
	unit.set_physics_process(true)
	for i in 720:
		if unit.state=="acting":break
		await physics_frame
	unit.set_physics_process(false)
	check(unit.state=="acting","Leaving the bunker resumes combat immediately")
	unit.hp=20;unit.shelter.tick(.1);unit.global_position=m.point(m.entry(b));unit.shelter.tick(.1)
	m.damage_building(b.id,100000);unit.shelter.tick(.1);h.sync_targets()
	check(unit.visible and unit.hp>0 and unit.state!="sheltered" and not m.allied_grid.is_point_solid(m.cell_of(unit.global_position)),"Destroyed bunker ejects its surviving fighter onto open ground")
	check(m.food_used()==used and not m.can_recruit(1),"Capacity loss preserves existing fighters and blocks recruitment")
	m.phase="preparing";m.gold=5000
	var replacement=m.build("barracks",Vector2i(12,10),0)
	unit.state="acting";unit.global_position=original_post;unit.shelter.reset();m.phase="wave"
	m.allied_grid.set_point_solid(m.entry(replacement),true);m.navigation_revision+=1
	unit.shelter.tick(1)
	check(unit.state=="acting","A blocked bunker entrance does not start an impossible retreat")
	m.allied_grid.set_point_solid(m.entry(replacement),false);m.navigation_revision+=1
	unit.shelter.tick(1);unit.global_position=m.point(m.entry(replacement));unit.shelter.tick(.1)
	m.phase="preparing";game.paused=true;h.rest();hp=unit.hp;h._process(1)
	check(unit.state=="sheltered" and is_equal_approx(unit.hp,hp+10),"Sheltered survivors keep healing between waves")
	check(m.food_used()==used,"Between-wave shelter retains food accounting")
	money=m.gold
	check(m.build("tower",m.cell_of(original_post),0).is_empty() and m.gold==money,"Sheltered fighter's assigned post stays reserved without charging construction")
	h._process(20)
	check(unit.state=="prepared" and unit.visible and unit.global_position==original_post and not m.allied_grid.is_point_solid(m.cell_of(unit.global_position)),"Finishing recovery between waves returns to the preserved open guard post")
	unit.hp=0;unit.disappear();h.sync_targets()
	check(m.food_used()==used-2,"A dead hired fighter releases two food")
	check(m.placement_error("tower",m.cell_of(original_post),0).is_empty(),"A dead fighter releases its old post for construction")
	await finish()
func finish():
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames();await create_timer(.25).timeout
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("BARRACKS_SHELTER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
