extends SceneTree
## Real imported equipment, tower simulation and committed sword-wave release.
const Actor=preload("res://assets/rogue/scripts/actor.gd")
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
var failures=0
var checks=0
var game
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",message)
func frames(count: int):
	for i in count:await physics_frame
func run():
	for id in preload("res://scripts/rogue_roster.gd").CLASS_IDS:
		var actor=Actor.new();root.add_child(actor);actor.setup(id)
		var original=load("res://assets/models/characters/goemon_cosplay/%s.glb"%id).instantiate();root.add_child(original)
		for key in ["Weapon_Cutlass","Weapon_Pistol"]:
			if not actor.joints.has(key):continue
			var source=original.find_child("Driver_"+key,true,false)
			if source==null:source=original.find_child(key,true,false)
			actor.animate_pose({"grounded":true},0,0,0)
			check(actor.joints[key].node.scale.is_equal_approx(source.scale*1.15),id+" enlarges held "+key+" by 15% without scaling the body")
		check(actor.model.scale.is_equal_approx(Vector3.ONE),id+" keeps original Goemon proportions")
		actor.free();original.free()
	await tower_rules()
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await frames(3)
	game.character_tuning={};game.tuning.invincible=true
	game.tuning.critical_chance=0.0
	game.player.buildings_broken=0;game.player.scale=Vector3.ONE
	game.tuning.pipe_range=3.5
	game.player.model.animate(0,0,true,0,.66,false,1,false);game.player.model.sync_skeleton()
	check(is_equal_approx(game.player.model.pipe.global_basis.get_scale().x,1.15),"Goemon's animated pipe retains the enlarged base scale")
	game.player.attack_heavy=true;game.player.attack_charged=false;game.player.wide_swing=false
	game.player.model.pipe_combo_active=false
	game.player.model.animate(0,Vector2(game.player.velocity.x,game.player.velocity.z).length(),game.player.is_on_floor(),game.player.velocity.y,.53,true,1,false);game.player.model.sync_skeleton()
	check(absf(game.player.melee_strike_reach()-game.player.model.visible_pipe_reach())<.3,"Goemon heavy contact stays inside the visibly enlarged pipe stroke")
	var heavy_tip=game.player.model.pipe.global_transform
	game.player.weapon_slot=1;game.player.combo=1;game.player.attack_duration=1;game.player.attack_left=.53
	game.player.strike()
	check(game.player.model.pipe.global_transform.is_equal_approx(heavy_tip),"Actual Goemon strike preserves its heavy pose while measuring contact")
	game.player.attack_heavy=false
	var coin=game.spawn_gold_coin(game.player.global_position+Vector3.UP*3,Vector3.FORWARD)
	check(is_equal_approx(coin.visual_size,1.15) and is_equal_approx(coin.hit_radius,.345),"Thrown koban size and contact radius both grow by 15%")
	coin.queue_free()
	game.start_wave();game.set_physics_process(false);game.model.waves.spawn_clock=10000
	game.player.set_physics_process(false)
	for id in [3,4,5,7,8,9,11,12]:
		game.player.select_character(id)
		var combat=game.player.active_ability;combat.reset_run();combat.player.pos=game.player.global_position
		combat.aim=combat.player.pos+Vector3.FORWARD*30;combat.attack()
		var a: Dictionary=combat.player.attack;a.time=a.contact
		game.player.model.actor.animate_pose(combat.player,0,0,0)
		var actor=game.player.model.actor;var weapon: Node3D=actor.joints.Weapon_Cutlass.node
		var tip=weapon.to_global(actor.WEAPON_AXES[actor.id]);var origin=game.player.global_position
		var reach=Vector2(tip.x-origin.x,tip.z-origin.z).length()+.12
		check(absf(a.reach-reach)<.02,actor.id+" calculates contact range from the enlarged weapon tip")
		game.model.enemies.clear();game.sync_enemies()
		game.model.waves.spawn_one();var near=game.model.enemies.values().back()
		near.pos=origin+combat.front(a.angle)*(a.reach+.15);near.hp=1000;near.max_hp=1000
		game.model.waves.spawn_one();var far=game.model.enemies.values().back()
		far.pos=origin+combat.front(a.angle)*(a.reach+1.5);far.hp=1000;far.max_hp=1000
		game.model.update_vision(origin);game.sync_enemies()
		if actor.id=="pirate":
			combat.tick(.001,false)
		else:Actions.resolve_attack(combat,a)
		check(near.hp<1000 and far.hp==1000,actor.id+" hits the enemy surface at its weapon edge and rejects targets beyond it")
	game.player.select_character(9)
	var dash_combat=game.player.active_ability;dash_combat.reset_run();dash_combat.player.rollStyle="dash-strike"
	Actions.finish_dash(dash_combat)
	var dash: Dictionary=dash_combat.player.attack;dash.time=dash.contact
	var dash_actor=game.player.model.actor;dash_actor.animate_pose(dash_combat.player,0,0,0)
	var dash_weapon: Node3D=dash_actor.joints.Weapon_Cutlass.node
	var dash_tip=dash_weapon.to_global(dash_actor.WEAPON_AXES["magic-swordsman"])-game.player.global_position
	check(absf(dash.reach-Vector2(dash_tip.x,dash_tip.z).length()-.12)<.03,"Magic Swordsman dash contact follows its enlarged sword instead of a fixed invisible radius")
	await wave_rules()
	await tower_pause_rules()
	game.queue_free();paused=false;await frames(2);await create_timer(.4).timeout
	print("COMBAT_POLISH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func tower_rules():
	var m=load("res://scripts/forest/forest_model.gd").new();m.reset(42)
	var tower=m._make_building("tower",Vector2i(4,4),0)
	m.start_wave();m.waves.spawn_clock=10000
	var worker=m.workers.values()[0];worker.job=tower.id;worker.state="garrison";worker.pos=m.center(tower);worker.timer=0
	for w in m.workers.values():
		if w.id!=worker.id:w.state="wounded"
	m.waves.spawn_one();var target=m.enemies.values()[0];target.pos=worker.pos+Vector3(0,0,30);target.hp=1000;target.max_hp=1000
	m.update_vision(m.hero_position)
	m.workforce.tick(.01,m.hero_position)
	check(target.hp==1000,"Tower launch does not damage a target before its arrow arrives")
	check(m.events.any(func(e):return e.kind=="arrow"),"Staffed tower emits a visible shot")
	m.events.clear();m.workforce.tick(.1,m.hero_position)
	check(target.hp==1000,"Distant target remains unharmed during early arrow travel")
	for i in 20:m.workforce.tick(.03,m.hero_position)
	check(target.hp==982,"A single traveling arrow applies its existing 18 damage once on arrival")
	check(m.events.any(func(e):return e.kind=="arrow_impact" and e.to.distance_to(target.pos+Vector3.UP)<.01),"Tower impact occurs at the real target position")
	worker.timer=0;m.events.clear();m.workforce.tick(.01,m.hero_position)
	target.hp=0;m.workforce.tick(.5,m.hero_position)
	check(m.workforce.arrows.is_empty() and not m.events.any(func(e):return e.kind=="arrow_impact"),"Arrows expire without hitting another enemy when their target dies")
	target.hp=1000;worker.timer=0;m.visible_cells.clear();m.events.clear();m.workforce.tick(.01,m.hero_position)
	check(m.workforce.arrows.is_empty(),"Tower crews never launch at enemies hidden by shared fog")
	m.phase="preparing";m.workforce.recover();m.events.clear()
	for i in 20:m.tick(.1,m.hero_position)
	check(not m.events.any(func(e):return e.kind=="arrow_impact"),"No stale tower impacts cross into preparation")
func wave_rules():
	game.player.select_character(9)
	var combat=game.player.active_ability;combat.reset_run()
	combat.player.pos=game.player.global_position;combat.aim=combat.player.pos+Vector3.FORWARD*30
	combat.action("flintlock")
	check(combat.projectiles.is_empty(),"Purple energy wave waits for the sword's release frame")
	if combat.player.attack==null:
		check(false,"Purple wave has a committed wind-up, slash and follow-through");return
	var a: Dictionary=combat.player.attack
	check(a.style=="energy-wave","Secondary uses the articulated energy slash pose")
	var actor=game.player.model.actor;var weapon: Node3D=actor.joints.Weapon_Cutlass.node
	var tips=[]
	for offset in [-.018,.018]:
		a.time=a.contact+offset;actor.animate_pose(combat.player,0,0,0)
		tips.append(weapon.to_global(actor.WEAPON_AXES[actor.id]))
	a.time=a.contact;actor.animate_pose(combat.player,0,0,0)
	Actions.resolve_attack(combat,a)
	check(combat.projectiles.size()==1,"Sword contact releases exactly one energy wave")
	if combat.projectiles.is_empty():return
	var pr: Dictionary=combat.projectiles[0];var forward: Vector3=pr.vel.normalized()
	var cut: Vector3=tips[1]-tips[0];cut=(cut-forward*cut.dot(forward)).normalized()
	check(absf(pr.mesh.global_basis.x.normalized().dot(cut))>.995,"Energy crescent follows the actual sword-tip slash angle")
	check(pr.mesh.global_basis.z.normalized().dot(forward)>.999,"Slash wave faces its travel direction")
	var bounds=AABB();var first=true
	for child in pr.mesh.get_children():
		if child is MeshInstance3D:
			for i in 8:
				var p=child.transform*child.mesh.get_aabb().get_endpoint(i)
				if first:bounds=AABB(p,Vector3.ZERO);first=false
				else:bounds=bounds.expand(p)
	check(absf(bounds.get_center().y)<.1 and bounds.size.y>1,"The crescent is centered on its hit volume instead of floating above it")
	combat.cancel()
	check(combat.projectiles.is_empty(),"Interrupting the attack clears its energy projectile")
func tower_pause_rules():
	var m=game.model;m.enemies.clear();m.workforce.arrows.clear()
	var tower=m._make_building("tower",Vector2i(6,5),0);m.revision+=1;m.rebuild_navigation()
	for w in m.workers.values():w.state="wounded"
	var w=m.workers.values()[0];w.state="garrison";w.job=tower.id;w.pos=m.center(tower);w.timer=0
	m.waves.spawn_one();var target=m.enemies.values()[0];target.pos=w.pos+Vector3(0,0,25);target.hp=1000;target.max_hp=1000;target.stun=100
	m.update_vision(game.player.position);game.world.sync(0)
	game._physics_process(.01);game.tower_arrows.sync(0)
	check(not m.workforce.arrows.is_empty() and not game.tower_arrows.visuals.is_empty(),"The real Forest game creates a traveling arrow mesh from its simulation event")
	if m.workforce.arrows.is_empty():return
	var arrow: Dictionary=m.workforce.arrows.values()[0];var before: Vector3=arrow.pos
	game.show_pause();game._physics_process(.5);game._process(.5)
	check(arrow.pos==before and target.hp==1000,"Escape pause freezes tower arrow travel and damage")
	game.resume();game._physics_process(.1);game.tower_arrows.sync(.1)
	check(arrow.pos!=before,"Resuming continues the same in-flight tower arrow")
	game.model.phase="preparing";game.model.workforce.recover();game.set_phase_view()
	check(game.tower_arrows.visuals.is_empty() and m.workforce.arrows.is_empty(),"Preparation clears both authoritative arrows and their rendered effects")
