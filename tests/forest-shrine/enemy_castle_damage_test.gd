extends "res://scripts/recovered_leaders_tests.gd"
class Battle extends "res://scripts/forest/forest_game.gd":
	func _sync_camera_mouse():Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
var OUT="res://build/Other Files/Asset Toolkit/Wind Meadow/Castle Breaches/"
const Castle=preload("res://scripts/forest/forest_enemy_castle.gd")
var timings={}

func run():
	root.size=Vector2i(1280,800)
	set_meta("forest_fighter",1);set_meta("forest_painterly_preview",true)
	var doc=preload("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_valley()
	if "--large" in OS.get_cmdline_user_args():doc.load_valley_large();OUT+="Large/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	set_meta("forest_custom_layout",doc.data)
	game=Battle.new();game.settings_path="user://castle-damage-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(5)
	var targets=game.enemy_objectives.duplicate();var castle=targets[0];var player=game.player
	check(targets.size()==4,"Four keeps retain the existing objective and victory ownership")
	for keep in targets:
		check(keep.hp==6000 and keep.max_hp==6000,"Enemy keep starts with 6000 HP")
		var statue=keep.visual.get_node("SkullpionStatue")
		check(statue.get_node("CarvedSkullpion").mesh==Castle.STATUE and Castle.STATUE.get_surface_count()==1,"Each castle reuses the same single-surface Skullpion statue")
		check(statue.find_children("*","AnimationPlayer",true,false).is_empty() and statue.find_children("*","Skeleton3D",true,false).is_empty(),"Static statues have no boss animation or skeleton runtime")
		check(statue.basis.is_equal_approx(Castle.basis(keep.data())) and keep.name_tag.text.contains("SKULLPION STATUE"),"Every rotated castle faces its statue toward the entrance and names the objective")
		check(keep.target_boxes.size()==23 and keep.physical.get_child_count()==23,"Pedestal and 22 fitted parts share combat and physical shapes")
		check(not game.model.waves.navigation.move_clear(keep.position+Vector3(14,1,0),1.3),"Native navigation includes the wider statue pedestal")
		check(keep.sections.size()>50 and keep.sections.all(func(p):return p.hp==6000 and p.max_hp==6000),"Every wall panel, gate and tower has its own 6000 HP pool")
		check(keep.sections.filter(func(p):return p.data().kind=="wall").all(func(p):return p.wall_damage[0].stage==0),"Healthy panels start without cracks")
		check(keep.castle_art.walls.size()==1,"Intact wall panels share one rendering batch")
		check(keep.ruins.find_children("*","MultiMeshInstance3D",true,false).size()==5 and not keep.castle_ruins.keep.visible and not keep.castle_ruins.collapse.visible,"Four rubble batches and one idle falling-masonry batch are prepared")
		check(keep.ruins.find_children("*","CollisionObject3D",true,false).is_empty(),"Rubble is cosmetic and cannot block a breach")
	game.show_core_balance(false);await frames(2)
	var wall_spin=game.menu.find_child("Core_enemy_wall_health",true,false)
	var keep_spin=game.menu.find_child("Core_enemy_castle_health",true,false)
	check(wall_spin!=null and keep_spin!=null,"Core balance exposes wall/fortification and keep health separately")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"00-balance-settings.png")
	wall_spin.value=4500;keep_spin.value=9000
	game.load_settings()
	check(game.core_balance.enemy_wall_health==4500 and game.core_balance.enemy_castle_health==9000,"Both health settings persist through disk")
	check(castle.hp==6000 and castle.sections[0].hp==6000,"Balance edits preserve the current run's health and breaches")
	var next=preload("res://scripts/forest/forest_model.gd").new();next.reset(42,game.core_balance,doc.data,false)
	check(next.portals[0].hp==9000 and next.portals[0].sections[0].hp==4500,"The next run uses independent configured health values")
	var cleaned=preload("res://scripts/forest/core_balance.gd").sanitized({"enemy_wall_health":NAN,"enemy_castle_health":-1})
	check(cleaned.enemy_wall_health==6000 and cleaned.enemy_castle_health==1,"Nonfinite and out-of-range health inputs are sanitized")
	game.reset_core_balance();game.resume();game.start_wave();game.model.waves.spawn_clock=100000
	game.set_physics_process(false);player.set_physics_process(false);game.army_runtime.set_physics_process(false)
	game.camera_rig.set_process(false);game.tuning.critical_chance=0;game.character_tuning={}
	var frame=Castle.basis(castle.data());var target=panel_near(castle,castle.position+frame*Vector3(-48,2,0))
	var center:Vector3=target.local_bounds.get_center();center.y=.1
	var outward:Vector3=frame*Vector3.LEFT
	player.position=castle.position+center+outward*5.2;player.facing=-outward;player.velocity=Vector3.ZERO
	game.model.update_vision(player.position);game.world.update_fog()
	var walk=Transform3D(player.basis,castle.position+center+outward*8)
	check(player.test_move(walk,-outward*16),"An intact panel blocks the real player collider")
	check(not game.model.waves.navigation.move_clear(castle.position+center,1.3),"Native pathfinding sees the intact panel")
	var queried=game.army_runtime.enemy_candidates(player.position,8)
	check(queried.has(target) and queried.size()<10,"Local combat queries return nearby panels, not all castle targets")
	await shot("01-healthy-panel",castle,Vector3(-70,10,19),Vector3(-46,7,0))
	await measure("healthy",target)
	var hp:float=target.hp
	target.take_hit(1,Vector3.RIGHT,false,{"tower":true})
	check(target.hp==hp-1 and castle.sections.filter(func(p):return p!=target).all(func(p):return p.hp==6000),"A targeted hit changes exactly one independent panel")
	player.set_auto_attack(false);player.start_attack(false,1)
	for tick in 100:player._physics_process(1.0/60)
	check(target.hp<hp and castle.hp==6000,"Actual Goemon pipe contacts damage a wall panel without damaging the keep")
	check(target.wall_damage[0].stage==1 and target.wall_damage[0].visible,"Real melee reveals this panel's first fracture stage")
	check(castle.sections.filter(func(p):return p.combat_contact_point(player.position).distance_to(player.position)>16).all(func(p):return p.hp==6000),"The melee sweep can hit nearby panels but cannot damage distant fortifications")
	check(target.name_tag.text.contains("WALL PANEL") and target.name_tag.text.contains(str(ceili(target.hp))) and target.name_tag.no_depth_test,"The struck panel displays its own readable HP")
	check(castle.sections.filter(func(p):return p.name_tag.visible).size()==1,"A broad swing shows one readable panel label without overlapping health text")
	await shot("02-local-cracks",castle,Vector3(-70,10,19),Vector3(-46,7,0))
	player.cancel_charge(true);player.select_character(player.RogueRoster.MASTER_CHIEF_ID)
	var from:Vector3=castle.position+center+outward*16+Vector3.UP*2
	var to:Vector3=castle.position+center-outward*12+Vector3.UP*2
	var contact=player.master_chief_combat.trace(from,to)
	var end:Vector3=contact.point+(to-from).normalized()*.02
	check(AttackChain.segment_enemy_candidates(game,from,end,0).has(target),"Castle-level query bounds retain the panel's outward contact padding")
	check(contact.target==target,"The real bullet trace selects the contacted panel")
	hp=target.hp
	player.master_chief_combat.fire_bullets(from,(to-from).normalized(),from,{"impact":false},player.attack_chain.begin("chief"),10,{"range":100.0},false)
	check(target.hp<hp and castle.hp==6000,"Actual bullet damage stays on the selected wall")
	player.select_character(1)
	for remaining in [4400.0,2600.0,1100.0]:
		target.take_hit(target.hp-remaining,Vector3.RIGHT,true,{"tower":true})
		var expected=2 if remaining==4400 else (3 if remaining==2600 else 4)
		check(target.hp==remaining and target.wall_damage[0].stage==expected,"Only the struck panel advances to fracture stage %d"%expected)
	await shot("03-severe-panel",castle,Vector3(-70,10,19),Vector3(-46,7,0))
	await measure("damaged",target)
	var nodes=castle.find_children("*","",true,false).size()
	var mesh=target.wall_damage[0].get_node("Fractures").mesh;var material=target.wall_damage[0]._material
	var chip_mesh=castle.castle_impact.chips.mesh;var hit_us=[]
	for i in 100:
		var start=Time.get_ticks_usec();target.take_hit(.1,Vector3.RIGHT,false,{"tower":true});hit_us.append(Time.get_ticks_usec()-start);target._process(.016)
	timings.repeated_hit_microseconds=hit_us
	check(castle.find_children("*","",true,false).size()==nodes,"One hundred hits do not grow the castle's node tree")
	check(target.wall_damage[0].get_node("Fractures").mesh==mesh and target.wall_damage[0]._material==material and castle.castle_impact.chips.mesh==chip_mesh,"Repeated hits reuse prepared geometry, materials and shared emitters")
	target._process(.5);check(not target.is_processing(),"Settled panel feedback stops processing")
	hp=target.hp
	for invalid in [0.0,-1.0,NAN,INF]:target.take_hit(invalid,Vector3.ZERO,false)
	check(target.hp==hp,"Invalid damage cannot change panel health")
	game.model.phase="preparing";target.take_hit(9999,Vector3.ZERO,false);check(target.hp==hp,"Preparation prevents panel destruction");game.model.phase="wave"
	var row=game.model.waves.spawn_enemy(0,Vector3.ZERO);game.sync_enemies();game.army_runtime.integration_tick(.01)
	var revision=game.model.navigation_revision
	var neighbors=castle.sections.filter(func(p):return p!=target).map(func(p):return p.hp)
	var start=Time.get_ticks_usec();target.take_hit(99999,Vector3.RIGHT,true,{"tower":true});timings.breach_microseconds=Time.get_ticks_usec()-start
	check(target.dead and not target.visual.visible and not game.enemies.has(target),"The destroyed panel retires from rendering and combat")
	check(target.collision_layer==0 and target.visual.find_children("*","StaticBody3D",true,false).all(func(body):return body.collision_layer==0),"Only the broken panel releases its physical collision")
	check(castle.hp==6000 and not castle.dead and game.model.active_enemy_camps()==4,"A breach keeps the castle and all four reinforcement sources alive")
	check(game.model.enemies.has(row.id) and game.model.waves.spawn_batch()>0,"Living soldiers survive and the breached castle can still reinforce")
	check(game.model.navigation_revision>revision and game.model.waves.navigation.move_clear(castle.position+center,1.3),"Native navigation updates to permit the breach")
	var saved=preload("res://tests/forest-shrine/reference/map_document.gd").new();saved.capture(game.model)
	check(saved.data.portals.all(func(p):return p.keys().size()==3 and not p.has("sections")),"Saved map layouts exclude transient damage and panel state")
	check(not player.test_move(walk,-outward*16),"The actual player collider can move through the broken panel")
	if DisplayServer.get_name()!="headless":
		var rubble=castle.castle_ruins.states[target.section_index]
		var rubble_box:AABB=rubble.batches[0].multimesh.get_instance_transform(rubble.slot)*rubble.batches[0].multimesh.mesh.get_aabb()
		check(rubble_box.end.y<1.2,"Broken wall rubble stays low enough to make the opening visually clear")
	check(player.master_chief_combat.trace(from,to).target==null,"A projectile passes through the breach without phantom wall contact")
	var neighbor=panel_near(castle,castle.position+center+frame*Vector3(0,0,6))
	check(neighbor!=target and neighbor.hp>0 and neighbor.collision_layer==4 and castle.sections.filter(func(p):return p!=target).map(func(p):return p.hp)==neighbors,"Breaching one section preserves every neighbor's health and collision")
	check(not game.model.waves.navigation.move_clear(castle.position+Vector3(neighbor.local_bounds.get_center().x,.1,neighbor.local_bounds.get_center().z),1.3),"Neighboring masonry still blocks native movement")
	check(castle.castle_impact.dust.emission_shape==CPUParticles3D.EMISSION_SHAPE_POINT,"Breach dust is localized rather than spread across the entire fort")
	var collapse=castle.castle_ruins.collapse;var slot:int=castle.castle_art.wall_slots[target.section_index]
	check(collapse.active.has(slot) and collapse.visible,"The breached panel starts its prepared break-and-fall animation")
	check(is_equal_approx(castle.castle_impact.dust.scale_amount_max,3.2),"Local breach dust leaves the falling upper masonry visible")
	var collapse_mesh=collapse.multimesh.mesh;var collapse_material=collapse.material_override
	var collapse_count=castle.find_children("*","",true,false).size()
	var start_chunk:Transform3D
	if DisplayServer.get_name()!="headless":start_chunk=collapse.multimesh.get_instance_transform(slot*collapse.CHUNKS+4)
	collapse.set_process(false)
	paused=true;check(not collapse.can_process(),"Ordinary pause freezes cosmetic wall falls with the world");paused=false
	for step in [0.18,0.32,0.35]:
		collapse._process(step);collapse.set_process(false)
		if DisplayServer.get_name()!="headless" and step==0.32:
			var falling:Transform3D=collapse.multimesh.get_instance_transform(slot*collapse.CHUNKS+4)
			check((falling*Vector3(0,3,0)).y<(start_chunk*Vector3(0,3,0)).y-2.0 and not falling.basis.is_equal_approx(start_chunk.basis),"Upper masonry falls and rotates instead of scaling straight down")
			check(falling.basis.get_scale().is_equal_approx(start_chunk.basis.get_scale()),"Falling chunks retain their solid size")
		await shot("04-falling-%.2f"%collapse.active[slot],castle,Vector3(-70,10,19),Vector3(-46,7,0),1)
	var age:float=collapse.active[slot];collapse.play(slot)
	check(collapse.active[slot]==age,"Repeated breach synchronization cannot restart a falling panel")
	collapse._process(1.0)
	check(collapse.active.is_empty() and not collapse.visible and not collapse.is_processing(),"Settled masonry releases its animation work and leaves the low traversable rubble")
	collapse.play(slot)
	check(collapse.active.is_empty() and castle.find_children("*","",true,false).size()==collapse_count and collapse.multimesh.mesh==collapse_mesh and collapse.material_override==collapse_material,"Finished breaches cannot replay or allocate new nodes, geometry or materials")
	await frames(100);await shot("05-breachable-wall",castle,Vector3(-70,10,19),Vector3(-46,7,0))
	player.position=walk.origin
	for tick in 80:
		await physics_frame
		player.velocity=-outward*12;player.move_and_slide()
	check((player.position-(castle.position+center)).dot(-outward)>2,"The player actually walks from outside into the courtyard through the new gap")
	player.velocity=Vector3.ZERO
	for i in range(1,4):
		var keep=targets[i];var wall=panel_near(keep,keep.position+Castle.basis(keep.data())*Vector3(-48,2,0))
		wall.take_hit(1,Vector3.RIGHT,false,{"tower":true});check(wall.wall_damage[0].stage==1 and keep.hp==6000,"Rotated castle %d keeps panel damage independent"%i)
		wall.take_hit(99999,Vector3.RIGHT,true,{"tower":true});check(wall.dead and not keep.dead,"Rotated castle %d permits a local breach"%i)
		keep.castle_impact.last_hit_ms-=100
		wall=panel_near(keep,keep.position+Castle.basis(keep.data())*Vector3(48,2,0));wall.take_hit(1,Vector3.LEFT,false,{"tower":true})
		check(keep.castle_impact.dust.scale_amount_max==2,"Shared emitters reset after a breach before the next ordinary hit")
	for keep in targets:
		var forward=Castle.basis(keep.data())*Vector3.BACK
		player.position=keep.position+forward*18+Vector3.UP*.1;player.facing=-forward
		var before:float=keep.hp
		player.cancel_charge(true);player.select_character(1)
		game.camera_rig.yaw=atan2(forward.x,forward.z)
		game.camera_rig.camera.global_position=player.position+forward*5+Vector3.UP*4
		game.camera_rig.camera.look_at(keep.position+Vector3.UP*2)
		await frames(2);player.start_attack(false,1)
		for tick in 100:player._physics_process(1.0/60)
		check(keep.hp<before and not keep.dead,"Actual Goemon melee damages the statue at the pedestal on every rotation")
		player.cancel_charge(true);player.select_character(player.RogueRoster.MASTER_CHIEF_ID)
		var start_point:Vector3=keep.position+forward*20+Vector3.UP*2
		var end_point:Vector3=keep.position+Vector3.UP*2
		check(player.master_chief_combat.trace(start_point,end_point).target==keep,"Actual bullet trace selects the statue through the open courtyard")
		before=keep.hp
		player.master_chief_combat.fire_bullets(start_point,-forward,start_point,{"impact":false},player.attack_chain.begin("chief"),10,{"range":30.0},false)
		check(keep.hp<before,"Actual bullets damage the same statue health pool")
		player.select_character(1)
		await shot("statue-%d"%keep.objective_index,keep,Vector3(5,16,32),Vector3(0,13,0))
		var statue_nodes=keep.find_children("*","",true,false).size()
		for i in 5:keep.take_hit(1,Vector3.FORWARD,false,{"tower":true})
		check(keep.find_children("*","",true,false).size()==statue_nodes and keep.visual.get_node("SkullpionStatue/CarvedSkullpion").mesh==Castle.STATUE,"Repeated hits reuse the statue, materials and prepared effects")
		keep.take_hit(99999,Vector3.FORWARD,true,{"tower":true})
		check(keep.dead and keep.sections.all(func(p):return p.dead) and keep.castle_ruins.keep.visible,"Destroying the keep retires remaining fortifications and reveals the complete ruins")
		check(keep.physical.collision_layer==0 and player.master_chief_combat.trace(start_point,end_point).target==null,"Destroyed statues leave no physical or projectile blocker")
		check(game.model.waves.navigation.move_clear(keep.position+Vector3(14,1,0),1.3),"Statue destruction releases its native navigation obstacle")
	check(game.model.phase=="victory" and game.model.waves.spawn_batch()==0,"Only destroying all four keeps wins and stops reinforcements")
	check(preload("res://scripts/forest/forest_camp_prototype.gd").obstacles(game.model).is_empty() and game.enemy_objective_targets.is_empty(),"Defeated forts leave no navigation obstacles or registered static targets")
	check(targets.all(func(k):return k.castle_ruins.collapse.active.size()>20),"All four destroyed keeps animate their remaining wall panels together")
	game.set_phase_view()
	check(paused and targets.all(func(k):return k.castle_ruins.collapse.can_process()),"The victory pause still lets the final castle falls finish")
	var falling_nodes=targets.map(func(k):return k.find_children("*","",true,false).size())
	for keep in targets:keep.castle_ruins.collapse.set_process(false)
	var collapse_us=[];var collapse_frames=[];var last_frame=Time.get_ticks_usec()
	for tick in 84:
		var tick_start=Time.get_ticks_usec()
		for keep in targets:keep.castle_ruins.collapse._process(1.0/60.0)
		collapse_us.append(Time.get_ticks_usec()-tick_start)
		await process_frame
		var now=Time.get_ticks_usec();collapse_frames.append((now-last_frame)/1000.0);last_frame=now
	timings.simultaneous_collapse_microseconds=collapse_us;timings.simultaneous_collapse_frame_ms=collapse_frames
	check(targets.all(func(k):return k.castle_ruins.collapse.active.is_empty() and not k.castle_ruins.collapse.visible and not k.castle_ruins.collapse.is_processing()),"Simultaneous castle falls all finish and stop updating")
	check(targets.map(func(k):return k.find_children("*","",true,false).size())==falling_nodes,"Simultaneous falls retain a fixed prepared node count")
	await shot("06-castle-ruins",castle,Vector3(102,82,120),Vector3(0,3,0))
	var old_targets=targets.duplicate();game.model.reset(42,{},doc.data,false);game.world.reload_map();game.army_runtime.reset_world();game.set_phase_view();await frames(3)
	check(game.enemy_objectives.size()==4 and game.enemy_objectives.all(func(k):return k.hp==6000 and k.sections.all(func(p):return p.hp==6000 and not p.dead)),"Restart rebuilds pristine panels and default 6000 HP keeps")
	check(old_targets.all(func(k):return not is_instance_valid(k)),"Reload frees the old castle target trees")
	check(game.enemies.size()==game.enemy_objective_targets.size()+int(is_instance_valid(game.training_dummy) and game.enemies.has(game.training_dummy)),"Reload has no stale or duplicate combat targets")
	var path=game.settings_path
	stop_audio(game);current_scene=null;game.queue_free();paused=false;await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	FileAccess.open(OUT+("headless" if DisplayServer.get_name()=="headless" else "desktop")+"-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"timings":timings},"  "))
	print("ENEMY_CASTLE_DAMAGE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

func panel_near(keep,point:Vector3):
	var best;var distance=INF
	for part in keep.sections:
		if part.dead or part.data().kind!="wall":continue
		var next:float=part.combat_contact_point(point).distance_squared_to(point)
		if next<distance:best=part;distance=next
	return best

func shot(label_:String,target,eye:Vector3,focus:Vector3,delay:int=12):
	if DisplayServer.get_name()=="headless":return
	var frame=Castle.basis(target.data());var camera=game.camera_rig.camera
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=60
	camera.global_position=target.position+frame*eye;camera.look_at(target.position+frame*focus)
	await frames(delay);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label_+".png")

func measure(label_:String,target):
	if DisplayServer.get_name()=="headless":return
	var samples=[];var last=Time.get_ticks_usec()
	for i in 90:
		await process_frame
		var now=Time.get_ticks_usec();samples.append((now-last)/1000.0);last=now
	timings[label_]={"frame_ms":samples,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"castle_nodes":target.find_children("*","",true,false).size()}
