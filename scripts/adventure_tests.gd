extends "res://scripts/destruction_tests.gd"
func capture_adventure(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/adventure/"+label+".png")
func run():
	visual="--adventure-visual" in OS.get_cmdline_user_args()
	if visual:DirAccess.make_dir_recursive_absolute("res://tests/adventure")
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var p=game.player;var adventure=game.adventure;var run=game.encounters;var sky=game.world.sky_islands
	await frames(30)
	var chain=AttackChain.new();chain.confirm(chain.begin("heavy"));chain.tick(1.2)
	check(chain.count==1 and chain.remaining>0,"A combo survives a 1.2-second gap")
	chain.tick(.56);check(chain.count==0,"A combo still ends after 1.75 seconds without contact")
	for amount in [25,50,100]:
		chain.reset()
		for i in range(amount):chain.confirm(chain.begin("pipe"))
		check(chain.milestone==amount,"The %d-link milestone is announced only after confirmed hits" % amount)
	check(adventure.kind(0)==0 and adventure.kind(1)==1 and adventure.kind(2)==2,"Islands offer elite, shrine and ambush objectives")
	var elite=game.enemies.filter(func(e):return e.island_index==0 and e.island_elite)[0]
	check(elite.body_radius>.6 and elite.max_hp>game.tuning.enemy_hp*Ninja.COMBO_TEST_HEALTH,"An elite has a larger body and extra health")
	var small=game.enemies.filter(func(e):return e.island_index==0 and not e.island_elite)[0]
	check(small.growth_knockback()==1,"Normal-size attacks keep their original knockback")
	p.buildings_broken=50;p.scale=Vector3.ONE*2
	check(small.growth_knockback()==2.5 and elite.growth_knockback()==1.6,"Growing doubles size and launches ordinary enemies farther than resistant elites")
	small.ground_giant=true;check(small.growth_knockback()==1.2,"Giants resist size-based knockback");small.ground_giant=false
	p.buildings_broken=0;p.scale=Vector3.ONE
	await frames(120)
	check(p.attack_left==0 and p.attack_chain.count==0 and elite.hp==elite.max_hp,"Standing near an enemy never attacks automatically")
	game.camera_rig.set_process(false)
	game.camera_rig.camera.global_position=sky.islands[0]+Vector3(15,10,17)
	game.camera_rig.camera.look_at(sky.islands[0]+Vector3.UP*2)
	await capture_adventure("01-elite-objective")
	# Exercise the ordinary manual input route against the elite objective.
	elite.set_physics_process(false);elite.hp=48
	game.reset_player_at(elite.position+Vector3.BACK*2.4);p.facing=Vector3.FORWARD;game.camera_rig.yaw=0
	press_melee("heavy_attack");await drain()
	check(elite.dead and adventure.is_complete(0) and adventure.pending_rewards.size()==1,"A manual heavy attack completes the elite objective and banks an upgrade")
	adventure.record_defeat(elite)
	check(adventure.pending_rewards.size()==1,"An objective never grants the same reward twice")
	var roster=run.remaining_on(0);run.reinforce()
	check(run.remaining_on(0)==roster,"Completed objectives stop that island's reinforcements")
	await key(KEY_F)
	check(game.paused and adventure.choosing and get_tree().paused,"F opens upgrade choices and pauses combat")
	var grace=p.attack_chain.remaining;await frames(10)
	check(p.attack_chain.remaining==grace,"The upgrade menu freezes the combo timer")
	await capture_adventure("02-upgrade-choice")
	await key(KEY_ESCAPE)
	check(not game.paused and not adventure.choosing and adventure.pending_rewards.size()==1,"Escape postpones the choice without losing the earned upgrade")
	await key(KEY_F)
	var buttons=game.menu.find_children("*","Button",true,false)
	buttons.filter(func(b):return b.text.begins_with("POWER"))[0].pressed.emit()
	check(not game.paused and p.run_upgrades.damage==1 and is_equal_approx(p.damage_multiplier(),1.1) and adventure.pending_rewards.is_empty(),"Choosing Power applies a run-long damage upgrade once and resumes play")
	adventure.choose("damage");check(p.run_upgrades.damage==1,"A stale button callback cannot duplicate an upgrade")
	game.reset_player_at(sky.islands[1]+Vector3(0,.2,4));run.refresh_encounters();adventure.sync_shrines();await frames(3)
	check(adventure.shrines.has(1) and adventure.shrines.size()<=10,"Only nearby shrine objectives allocate nodes")
	var shrine=adventure.shrines[1]
	shrine.take_hit(110,p.attack_chain.begin("pipe"),shrine.bounds.get_center())
	var saved_hp=shrine.hp
	game.reset_player_at(sky.islands[sky.COUNT-1]+Vector3.UP*.2);run.refresh_encounters();adventure.sync_shrines();await frames(2)
	check(not adventure.shrines.has(1),"Leaving the area unloads the shrine")
	game.reset_player_at(sky.islands[1]+Vector3(0,.2,4));run.refresh_encounters();adventure.sync_shrines();await frames(2)
	shrine=adventure.shrines[1]
	check(shrine.hp==saved_hp and shrine.damage_stage>=1,"Returning restores shrine health and visible damage")
	game.camera_rig.camera.global_position=sky.islands[1]+Vector3(10,9,16);game.camera_rig.camera.look_at(sky.islands[1]+Vector3.UP*2)
	await capture_adventure("03-guarded-shrine")
	shrine.take_hit(1000,p.attack_chain.begin("heavy"),shrine.bounds.get_center());await frames(2)
	check(adventure.is_complete(1) and adventure.pending_rewards.size()==1,"Destroying a guarded shrine completes its objective")
	game.reset_player_at(sky.islands[2]+Vector3.UP*.2);p.set_physics_process(false)
	adventure._physics_process(10);var survived=adventure.survival[2]
	game.show_pause();adventure._physics_process(100)
	check(adventure.survival[2]==survived,"Pausing does not advance an ambush objective");game.resume()
	p.position+=Vector3.UP*30;adventure._physics_process(10)
	check(adventure.survival[2]==survived,"Leaving an ambush island pauses its survival timer")
	p.position-=Vector3.UP*30;adventure._physics_process(15)
	check(adventure.is_complete(2) and adventure.pending_rewards.size()==2,"Surviving 25 seconds near the island completes the ambush")
	adventure._physics_process(100)
	check(adventure.pending_rewards.size()==2,"Staying after an ambush cannot farm repeated rewards")
	adventure.show_choices();adventure.choose("vitality")
	check(p.run_upgrades.vitality==1 and p.max_hp>100,"Vitality raises maximum health for the run")
	adventure.show_choices();adventure.choose("tempo")
	check(p.run_upgrades.tempo==1,"Tempo grants a bounded attack-speed upgrade")
	p.set_physics_process(true);run.enabled=false
	await fresh_site()
	# A roof is an independently authored structural piece, like the actual town models.
	var part=fixture();var roof=Geo.box(part.building,Vector3(0,8,0),Vector3(7,.5,5),Geo.mat("534d56"),true);roof.name="Roof"
	for body in roof.find_children("*","StaticBody3D",true,false):body.set_meta("breakable_building",part)
	part.take_hit(70,p.attack_chain.begin("pipe"),part.nearest(p.position+Vector3.UP))
	check(part.damage_stage==1 and not part.damage_meshes.is_empty() and part.damage_meshes[0].material_overlay!=null,"Damage first creates a bounded set of visible cracks")
	part.take_hit(80,p.attack_chain.begin("heavy"),part.nearest(p.position+Vector3.UP))
	check(part.damage_stage==2 and not roof.visible and roof.get_child(0).collision_layer==0,"Severe damage removes the roof and its collision")
	var nodes=part.damage_meshes.size();part.take_hit(1,p.attack_chain.begin("pipe"),part.bounds.get_center())
	check(part.damage_meshes.size()==nodes and BreakableBuilding.crack_materials.size()==2,"Repeated hits reuse damage stages instead of allocating more crack meshes")
	var drops=get_tree().get_nodes_in_group("energy_pickups").size()
	part.take_hit(1000,p.attack_chain.begin("heavy"),part.bounds.get_center())
	check(get_tree().get_nodes_in_group("energy_pickups").size()==drops+1,"Destroying a regular building reveals one combat pickup as well as growth")
	part.destroy();check(get_tree().get_nodes_in_group("energy_pickups").size()==drops+1,"A destroyed building cannot duplicate loot")
	for i in range(5):p.collect_powerup("fire");p.collect_powerup("ice")
	await frames(25)
	check(game.orb_system.active and game.orb_system.fire_bursts==1 and game.orb_system.ice_bursts==1,"Building elemental rewards trigger their completed-set effects in descent mode")
	adventure.complete(7);p.run_upgrades.tempo=5;adventure.show_choices();adventure.choose("tempo")
	check(p.run_upgrades.tempo==5 and p.hp==p.max_hp,"A capped upgrade becomes a heal instead of increasing speed indefinitely")
	adventure.complete(8);adventure.show_choices();await key(KEY_Y);await frames(20)
	check(not game.paused and not adventure.choosing and adventure.completed.is_empty() and adventure.pending_rewards.is_empty() and p.run_upgrades=={"damage":0,"vitality":0,"tempo":0} and p.buildings_broken==0,"Y safely closes the reward menu and resets objectives, upgrades and growth")
	check(get_tree().get_nodes_in_group("energy_pickups").is_empty(),"New runs remove old building rewards")
	print("ADVENTURE_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
