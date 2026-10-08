extends SceneTree
## Scene-node regression checks; real Ninja damage and physics-world obstruction.

class FixtureGame extends Node3D:
	var enemies: Array=[]
	var tuning={"enemy_hp":20.0,"boss_hp_mult":1.0}
	var kills=0
	var descent_mode=false
	var encounters: Node
	func remember_defeat(_enemy):pass

class FixtureDirector extends Node:
	var generation=1
	var wave=1
	var active=true
	var phase="spawning"
	func owns(enemy)->bool:
		return is_instance_valid(enemy) and enemy.get_meta("generation",0)==generation
	func record_defeat(_enemy):pass

var failures=0
var checks=0
var fixture: FixtureGame
var director: FixtureDirector
var structure_script: Script

func _initialize():call_deferred("run")
func check(value: bool,label: String):
	checks+=1
	if not value:failures+=1;push_error("FAIL: "+label)
	else:print("PASS: "+label)

func actor(point: Vector3,hp_value: float=100.0)->Ninja:
	var enemy=Ninja.new()
	enemy.game=fixture;enemy.defense_lane=1;enemy.position=point
	enemy.set_meta("generation",director.generation)
	fixture.add_child(enemy);enemy.set_physics_process(false)
	enemy.hp=hp_value;enemy.max_hp=hp_value;fixture.enemies.append(enemy)
	return enemy

func tower(point: Vector3=Vector3.ZERO,kind_value: String="arrow"):
	var result=structure_script.new()
	result.game=fixture;result.director=director;result.kind=kind_value;result.position=point
	fixture.add_child(result)
	return result

func clear_fixture():
	if is_instance_valid(fixture):fixture.free()
	fixture=FixtureGame.new();root.add_child(fixture)
	director=FixtureDirector.new();fixture.add_child(director);fixture.encounters=director

func pose_snapshot(model: Node)->Dictionary:
	var snapshot={}
	for mesh in model.find_children("*","MeshInstance3D",true,false):snapshot[String(mesh.name)]=mesh.global_transform
	return snapshot

func geometry():
	var world=TowerDefenseWorld.new()
	world.beta_mode=true
	var available=world.get("redesign_mode")!=null
	check(available,"World exposes the redesigned-mode boundary")
	if not available:world.free();return
	world.redesign_mode=true;root.add_child(world);world.set_process(false)
	check(world.cannon_sites.size()==12,"Redesigned world has exactly twelve purchasable empty sites")
	var expected=[]
	for x in [-16.0,-9.0,9.0,16.0]:expected.append(Vector3(x,2.65,170))
	for x in [-12.0,12.0]:
		for z in [116.0,130.0,144.0,158.0]:expected.append(Vector3(x,.15,z))
	var exact=world.cannon_sites.size()==expected.size()
	var pads_clear=true
	for site in world.cannon_sites:
		exact=exact and expected.has(site.position)
		var offset=5.3 if site.position.y>2 else 3.5
		pads_clear=pads_clear and is_equal_approx(site.build_position.z-site.position.z,offset) and absf(site.build_position.x)>=9
	check(exact,"All sites occupy the four front-wall and eight straight-row positions")
	check(pads_clear,"Interaction pads stay south of their site and outside the 12m enemy corridor")
	check(world.get_node_or_null("MainCastleWall")!=null and world.cover_walls.size()>6,"Both original defensive walls remain despite removal of rear build sites")
	check(world.mine_position==Vector3(-16,0,282) and world.mine_build_position.z>world.mine_position.z,"Mine is left of the base with a reachable southern work pad")
	await physics_frame
	var space=root.world_3d.direct_space_state
	var corridor_clear=true
	for x in [-5.5,0,5.5]:
		corridor_clear=corridor_clear and space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,1,110),Vector3(x,1,298),1)).is_empty()
	check(corridor_clear,"Actual world colliders leave the enemy corridor open through both walls")
	var site_clear=true
	for site in world.cannon_sites:
		if site.position.y>2:continue
		var at=site.position
		site_clear=site_clear and space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3(-1.4,1,0),at+Vector3(1.4,1,0),1)).is_empty()
	check(site_clear,"Ground tower footprints do not intersect old entrance gate posts")
	world.free()
	var legacy=TowerDefenseWorld.new();legacy.beta_mode=true;root.add_child(legacy);legacy.set_process(false)
	check(legacy.cannon_sites.size()==8,"Legacy beta layout retains its eight mounts")
	legacy.free()

func construction():
	clear_fixture()
	for kind_value in ["arrow","mine"]:
		var structure=tower(Vector3.ZERO,kind_value)
		structure.set_build_progress(.6,true)
		var assembled_pose=pose_snapshot(structure.visual_root)
		check(structure.progress_fill.visible and is_equal_approx(structure.progress_fill.scale.x,.6) and structure.hammer.visible,"%s exposes normalized progress and working hammer" % kind_value)
		structure.tick(.1,0)
		var hammer_pivot=structure.hammer.find_child("FX_HammerSwingPivot",true,false)
		var hammer_pose=hammer_pivot.transform
		structure.set_build_progress(.2,false);structure.tick(.1,0)
		check(pose_snapshot(structure.visual_root)!=assembled_pose and not structure.hammer.visible and hammer_pivot.transform==hammer_pose,"%s assembly reverses on decay and hammer stops when work stops" % kind_value)
		structure.set_build_progress(.6,true)
		check(pose_snapshot(structure.visual_root)==assembled_pose,"%s reholding seeks to the same exact assembly pose" % kind_value)
		structure.set_build_progress(1,false)
		check(not structure.completed and structure.completion_events==0,"Visual progress alone cannot activate or flash unpaid %s" % kind_value)
		structure.complete_build();structure.complete_build()
		check(structure.completed and structure.completion_events==1 and structure.completion_light.visible and not structure.progress_root.visible,"Paid %s completion activates once and emits one light" % kind_value)
		structure.tick(1.1,0)
		check(not structure.completion_light.visible,"%s completion light expires" % kind_value)

func asset_contracts():
	clear_fixture()
	var arrow=tower()
	var arrow_root=arrow.visual_root.find_child("TOWER_ROOT",true,false)
	check(arrow_root!=null,"The supplied animated tower GLB replaces temporary geometry")
	var mine=tower(Vector3(10,0,0),"mine")
	var mine_root=mine.visual_root.find_child("GoldMine_Root",true,false)
	check(mine_root!=null,"The supplied mine GLB replaces temporary geometry")
	if arrow_root==null or mine_root==null:return
	var visible_meshes=0
	for mesh in arrow.visual_root.find_children("*","MeshInstance3D",true,false):
		if mesh.is_visible_in_tree():visible_meshes+=1
	check(visible_meshes==15,"An unbought tower starts in its fifteen-piece empty foundation pose")
	check(arrow.build_player.has_animation("Tower_Build_Recoil_Reverse") and is_equal_approx(arrow.build_player.get_animation("Tower_Build_Recoil_Reverse").length,179.0/24.0),"Tower import retains the exact 24FPS combined clip")
	arrow.set_build_progress(1,false)
	check(arrow.to_local(arrow.muzzle.global_position).distance_to(Vector3(0,1.86,1.73))<.001,"Imported arrow socket preserves Godot Y-up and +Z-forward coordinates")
	check(is_equal_approx(arrow.progress_fill.position.x,-.975),"Imported progress fill retains its fixed left anchor")
	check(arrow.hammer.find_child("FX_HammerSwingPivot",true,false)!=null and arrow.completion_light.find_child("Completion_OuterRing",true,false)!=null,"Supplied hammer and completion GLBs provide construction feedback")
	check(arrow.progress_root.find_child("BPrompt_Keycap",true,false)!=null,"Supplied B prompt appears with construction feedback")
	var pulse=arrow.completion_player.get_animation("Complete_GoldPulse")
	var blend_tracks=0;var spark_nodes={}
	for i in range(pulse.get_track_count()):
		if pulse.track_get_type(i)==Animation.TYPE_BLEND_SHAPE:blend_tracks+=1
		var path=String(pulse.track_get_path(i))
		if "Completion_Spark_" in path:spark_nodes[path.get_slice(":",0)]=true
	check(blend_tracks==2 and spark_nodes.size()==10,"Imported completion animation preserves both ring morphs and all ten spark transforms")
	mine.set_build_progress(1,false)
	var cart=mine.visual_root.find_child("07_WORKING_CART_Root",true,false)
	check(cart!=null and is_equal_approx(cart.position.z,1.56),"Mine construction preserves the cart's constant placement track")
	check(mine.build_player.has_animation("work_loop") and mine.build_player.has_animation("reverse_build") and mine.build_player.has_animation("upgrade_preview"),"Mine import preserves all four clip names without suffix rewriting")
	check(mine.income_socket.global_position.distance_to(mine.global_position+Vector3(0,2.4,1.3))<.001,"Mine income socket retains the authored placement")
	mine.complete_build();director.phase="setup"
	var cart_pose=cart.transform
	mine.tick(.5,0)
	check(cart.transform==cart_pose,"A completed mine's work animation stays stopped in setup")
	director.phase="spawning";mine.tick(.5,0)
	check(cart.transform!=cart_pose and mine.build_player.get_animation("work_loop").loop_mode==Animation.LOOP_LINEAR,"The mine animates its imported looping cart only during spawning income")
	cart_pose=cart.transform;director.phase="clearance";mine.tick(.5,0)
	check(cart.transform==cart_pose,"Mine work animation stops during clearance when income stops")
	director.phase="spawning";arrow.complete_build()
	var ring=arrow.completion_light.find_child("Completion_OuterRing",true,false)
	var spark=arrow.completion_light.find_child("Completion_Spark_01",true,false)
	arrow.tick(.25,0)
	check(ring.get_blend_shape_value(0)<.01 and spark.scale.x>.01,"Paid completion actually evaluates authored ring morphs and spark animation")
	arrow.tick(.8,0)
	check(ring.get_blend_shape_value(0)>.99 and not arrow.completion_light.visible,"Completion clip collapses its rings before the effect is hidden")
	var recoil_rest=arrow.recoil.position
	actor(Vector3(0,0,30),1000);arrow.tick(.001,.001)
	check(not arrow.embedded_arrow.visible,"Firing hides the embedded demonstration arrow while the independent bolt travels")
	if not arrow.shells.is_empty():
		var bolt=arrow.shells[0].node
		check(bolt.find_child("ARROW_PROJECTILE_ROOT",true,false)!=null and bolt.find_child("SOCKET_ARROW_TIP",true,false)!=null and bolt.find_children("*","MeshInstance3D",true,false).size()==5,"Travelling bolt uses the supplied five-mesh arrow GLB and tip socket")
	arrow.tick(.05,0)
	check(arrow.recoil.position.distance_to(recoil_rest)>.05,"Each gameplay shot drives the supplied local recoil animation")
	arrow.tick(.4,0)
	check(arrow.embedded_arrow.visible and arrow.recoil.position.distance_to(recoil_rest)<.001,"Recoil settles and reloads the embedded arrow independently of powered firing cadence")

func projectiles():
	clear_fixture()
	var structure=tower();structure.complete_build()
	var near=actor(Vector3(0,0,10))
	var downstream=actor(Vector3(0,0,35),1000)
	var too_far=actor(Vector3(0,0,70))
	director.phase="setup";structure.tick(.5,.5)
	check(structure.shells.is_empty(),"Completed towers cannot attack during setup")
	director.phase="spawning";structure.tick(.001,.001)
	check(structure.shells.size()==1 and structure.target==downstream and downstream.hp==1000,"First eligible powered tick launches a visible committed arrow at the furthest in-range enemy without instant damage")
	if not structure.shells.is_empty():check(structure.shells[0].node is Node3D and structure.shells[0].node.visible,"Arrow flight has a visible scene node")
	var flight_start: Vector3=structure.shells[0].node.global_position if not structure.shells.is_empty() else Vector3.ZERO
	structure.tick(.2,0)
	check(downstream.hp==1000 and structure.shells.size()==1,"Depleted towers keep existing arrows travelling without firing new arrows")
	if not structure.shells.is_empty():check(is_equal_approx(flight_start.distance_to(structure.shells[0].node.global_position),13.0),"An arrow covers thirteen metres in 0.2 seconds")
	structure.tick(.4,0)
	check(downstream.hp==950 and structure.shells.is_empty() and near.hp==100 and too_far.hp==100,"Arrow impact deals exactly fifty damage only to its committed target")
	structure.tick(.499,.499)
	check(structure.shots_fired==2,"The second arrow launches after exactly half a second of accumulated powered time")
	structure.tick(1.0,1.0)
	check(structure.shots_fired==4,"A delayed tick preserves every half-second firing opportunity")
	structure.retire_wave_effects()
	check(structure.shells.is_empty() and structure.target==null,"Wave retirement clears all arrows and target references")
	clear_fixture();structure=tower();structure.complete_build()
	var left=actor(Vector3(-7,0,20));var right=actor(Vector3(2,0,20))
	structure.tick(.001,.001)
	check(structure.target==right,"Downstream priority breaks equal progress ties by nearest distance")
	structure.tick(.05,0);right.dead=true;structure.tick(.05,0)
	check(structure.shells.is_empty() and left.hp==100,"An arrow expires when its committed target dies without retargeting")
	clear_fixture();structure=tower();structure.complete_build()
	var enemy=actor(Vector3(0,0,30));structure.tick(.001,.001)
	director.generation+=1;structure.tick(1.0,0)
	check(structure.shells.is_empty() and enemy.hp==100,"A stale generation arrow cannot damage a replacement run")
	clear_fixture();structure=tower();structure.complete_build()
	enemy=actor(Vector3(0,0,30));structure.tick(.001,.001)
	director.wave+=1;structure.tick(1.0,0)
	check(structure.shells.is_empty() and enemy.hp==100,"A stale wave arrow cannot cross into the next wave")
	clear_fixture();structure=tower();structure.complete_build()
	enemy=actor(Vector3(0,0,30));structure.tick(.001,.001)
	enemy.free();structure.tick(1.0,0)
	check(structure.shells.is_empty(),"Freed target weak references safely retire their arrows")
	clear_fixture();structure=tower();structure.complete_build()
	enemy=actor(Vector3(0,0,30))
	var wall=StaticBody3D.new();wall.position=Vector3(0,2,15);wall.collision_layer=1
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(10,4,1);shape.shape=box
	wall.add_child(shape);fixture.add_child(wall)
	await physics_frame
	structure.tick(.001,.001);structure.tick(1.0,0)
	check(enemy.hp==100 and structure.shells.is_empty(),"A real world wall stops the travelling arrow before impact")
	wall.position.z=2
	await physics_frame
	structure.retire_wave_effects();structure.tick(.001,.001);structure.tick(1,0)
	check(enemy.hp==100 and structure.shells.is_empty(),"An arrow muzzle inside solid geometry cannot shoot through it")
	clear_fixture();structure=tower();structure.set_build_progress(1,false)
	enemy=actor(Vector3(0,0,30));structure.tick(1,1)
	check(structure.shells.is_empty() and enemy.hp==100,"Unpaid visual completion never fires")
	structure.complete_build();structure.tick(1,0)
	check(structure.shells.is_empty(),"A zero-wallet tower cannot take its first shot until paid time arrives")
	structure.tick(.001,.001);director.active=false;structure.tick(1,1)
	check(structure.shells.is_empty() and enemy.hp==100,"Terminal deactivation retires pending arrows without damage")
	clear_fixture();structure=tower();structure.complete_build()
	enemy=actor(Vector3(0,0,30));structure.tick(.001,.001)
	enemy.set_meta("generation",99);structure.tick(1,0)
	check(enemy.hp==100 and structure.shells.is_empty(),"An actor that leaves the owned roster cannot receive an old arrow")
	clear_fixture();structure=tower();structure.complete_build()
	enemy=actor(Vector3(0,0,30));structure.tick(.001,.001)
	var late_target=actor(Vector3(0,0,40));enemy.position.x=4
	structure.tick(.6,0)
	check(enemy.hp==50 and late_target.hp==100,"Travelling arrows track their moving committed target instead of switching to a new higher-priority actor")
	clear_fixture();structure=tower(Vector3.ZERO,"mine");structure.complete_build()
	enemy=actor(Vector3(0,0,30));structure.tick(1,1)
	check(structure.shells.is_empty() and enemy.hp==100,"A completed mine never performs tower attacks")

func run():
	await geometry()
	var available=ResourceLoader.exists("res://scripts/fire_siege_structure.gd")
	check(available,"Structure visual and arrow adapter exists")
	if available:
		structure_script=load("res://scripts/fire_siege_structure.gd")
		asset_contracts();construction();await projectiles()
		if "--visual-structures" in OS.get_cmdline_user_args():await render_review()
	if is_instance_valid(fixture):fixture.free()
	print("FIRE_SIEGE_STRUCTURE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func render_review():
	clear_fixture();root.size=Vector2i(1440,900)
	var environment=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("344956")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("a6b8c0");environment.environment.ambient_light_energy=.65
	fixture.add_child(environment)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-25,0);light.light_energy=1.4;light.shadow_enabled=true;fixture.add_child(light)
	var camera=Camera3D.new();camera.position=Vector3(5,13,26);fixture.add_child(camera);camera.look_at(Vector3(2,1.2,0));camera.fov=49;camera.current=true
	Geo.box(fixture,Vector3(0,-.2,0),Vector3(42,.3,20),Geo.mat("657067"))
	for data in [[-7.5,0.0,"arrow","EMPTY SITE"],[-3.5,.55,"arrow","HOLD B / ASSEMBLING"],[.5,1.0,"arrow","ARROW TOWER I"],[6.5,.55,"mine","MINE / ASSEMBLING"],[12.5,1.0,"mine","GOLD MINE I"]]:
		var structure=tower(Vector3(data[0],0,0),data[2]);structure.set_build_progress(data[1],data[1]>0 and data[1]<1)
		if data[1]>=1:structure.complete_build()
		structure.tick(.25,0)
		var label=Label3D.new();label.text=data[3];label.position=Vector3(data[0],5.5,0);label.font_size=26;label.pixel_size=.013;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		fixture.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/fire-siege-structure-assets.png")
	print("STRUCTURE_VISUAL /tmp/fire-siege-structure-assets.png")
