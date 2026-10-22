extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
## A remote army must not fit every hull for each swing or pulse. Real raiders
## retain their posed geometry, visibility, damage and authoritative model HP.
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
class CountedRaider extends "res://scripts/forest/forest_raider.gd":
	var contact_queries=0
	func combat_contact_point(point: Vector3)->Vector3:
		contact_queries+=1
		return super.combat_contact_point(point)
var crowd: Array=[]
var config_path="user://combat-snapshot-%d.cfg"%OS.get_process_id()
func counted_target(offset: Vector3,variant: int=0):
	var id=10000+game.model.enemies.size()
	var position=ORIGIN+offset
	var data={"id":id,"variant":variant,"pos":position,"hp":10000.0,"max_hp":10000.0,"velocity":Vector3.ZERO,"stun":100.0,"attack":false,"clock":0.0,"facing":0.0,"action":"walk","action_left":0.0,"attack_progress":0.0,"walk_phase":0.0}
	game.model.enemies[id]=data
	var actor=CountedRaider.new();actor.game=game;actor.forest_id=id;actor.variant=variant;actor.swarm=true;actor.position=position
	game.add_child(actor);actor.set_physics_process(false);game.actors[id]=actor;game.enemies.append(actor);crowd.append(actor)
	game.model.visible_cells[game.model.cell_of(position)]=true
	return actor
func reset_counts():
	for actor in crowd:actor.contact_queries=0
func queries()->int:
	var total=0
	for actor in crowd:total+=actor.contact_queries
	return total
func reset_health():
	for actor in crowd:
		actor.hp=10000.0;game.model.enemies[actor.forest_id].hp=10000.0
func run():
	var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
	await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.tuning.critical_chance=0.0
	await fresh()
	var near=counted_target(Vector3(0,0,-1.3))
	var side=counted_target(Vector3(2,0,-.2))
	var offset_area=counted_target(Vector3(14,0,-4))
	for i in 240:counted_target(Vector3(80+(i%30)*2,0,-35-floori(i/30.0)*3),3)
	var combat=game.player.active_ability
	reset_counts()
	var all_targets: Array=combat.living()
	check(all_targets.size()==243 and queries()==243,"Unbounded living retains every visible living target and its fitted snapshot")
	game.player.select_character(10)
	var ranger=game.player.active_ability;ranger.reset_run();ranger.player.pos=game.player.position
	ranger.aim=ORIGIN+Vector3.FORWARD*20;ranger.attack();Actions.resolve_attack(ranger,ranger.player.attack)
	reset_counts();ranger._begin_projectile_queries()
	check(queries()==0,"A live Ranger arrow prepares bounds without fitting and discarding 243 hull contacts (%d)"%queries())
	ranger.resolve_projectile_segment(ranger.projectiles[0],ORIGIN+Vector3.UP,ORIGIN+Vector3(0,1,-4))
	ranger._end_projectile_queries()
	check(near.hp==9933 and side.hp==10000,"The actual Ranger arrow retains 67 damage and narrow off-path exclusion (near=%s, side=%s, damage=%s)"%[near.hp,side.hp,ranger.projectiles[0].damage])
	ranger.cancel();reset_health();game.player.attack_chain.reset();game.player.select_character(11)
	combat=game.player.active_ability;combat.reset_run();combat.player.pos=game.player.position
	combat.aim=ORIGIN+Vector3.FORWARD*20;combat.attack()
	combat.player.attack.angle=PI
	reset_counts();Actions.resolve_attack(combat,combat.player.attack)
	check(near.hp==9981 and side.hp==10000 and offset_area.hp==10000,"Native primary retains its 19 damage and rejects a nearby off-angle raider")
	check(queries()<=6,"A native primary fits only nearby candidate hulls, not 240 remote raiders (%d)"%queries())
	reset_health();reset_counts()
	var hits=Actions.area(combat,ORIGIN,3,27,"flintlock",false,Color.WHITE,"slam",1.0)
	check(hits==2 and near.hp==9973 and side.hp==9973 and offset_area.hp==10000,"Native area retains both nearby contacts and exact damage")
	check(queries()<=6,"An area fits only nearby candidate hulls (%d)"%queries())
	reset_health();reset_counts()
	hits=Actions.area(combat,ORIGIN+Vector3(14,0,0),2,31,"flintlock",false,Color.WHITE,"slam",3.0)
	check(hits==1 and offset_area.hp==9969 and near.hp==10000,"Area broadphase uses the actual displaced center and already scaled six-metre radius")
	check(queries()<=3,"A displaced scaled area excludes remote and hero-adjacent hulls (%d)"%queries())
	reset_health();game.model.visible_cells.erase(game.model.cell_of(near.global_position));reset_counts()
	Actions.area(combat,ORIGIN,3,27,"flintlock",false,Color.WHITE,"slam",1.0)
	check(near.hp==10000,"Bounded snapshots preserve current fog exclusion")
	game.model.visible_cells[game.model.cell_of(near.global_position)]=true
	await fresh(8);crowd.clear()
	var giant=counted_target(Vector3(-4.65,0,5),2)
	var boss=counted_target(Vector3(0,0,-5.0),4)
	for i in 240:counted_target(Vector3(80+(i%30)*2,0,-35-floori(i/30.0)*3),3)
	combat=game.player.active_ability
	reset_counts()
	hits=Actions.area(combat,ORIGIN,3,29,"flintlock",false,Color.WHITE,"slam",1.0)
	check(hits==2 and giant.hp==9971 and boss.hp==9971,"Area reaches actual giant foot and boss face despite roots beyond its radius")
	check(queries()<=6,"Large fitted bounds retain nearby surfaces without fitting the remote army (%d)"%queries())
	reset_health();reset_counts()
	var sweep={"angle":PI,"reach":2.0,"arc":PI,"damage":37,"weapon":"flintlock","ticket":combat.current_ticket()}
	Actions.resolve_dragoon_sweep(combat,sweep,0)
	check(giant.hp==9963 and boss.hp==9963,"Dragoon sweep retains exact surface damage for giant and boss")
	check(queries()<=6,"Dragoon sweep skips remote fitted hulls (%d)"%queries())
	reset_health();reset_counts()
	Actions.lance_impact(combat,{"ticket":combat.current_ticket(),"rangeScale":1.0})
	check(giant.hp==9936 and boss.hp==9936 and combat.player.pulses.size()==2,"Lance landing retains its first 64 damage pulse and two delayed pulses")
	check(queries()<=6,"Lance landing area excludes the remote army (%d)"%queries())
	check(crowd.slice(2).all(func(actor):return actor.hp==10000),"All remote enemies remain unharmed")
	await fresh(8);crowd.clear();combat=game.player.active_ability
	var legacy=Ninja.new();legacy.game=game;legacy.swarm=true;legacy.position=ORIGIN+Vector3(0,0,-2.25)
	game.add_child(legacy);legacy.set_physics_process(false);legacy.hp=10000;legacy.max_hp=10000;game.enemies.append(legacy)
	game.model.visible_cells[game.model.cell_of(legacy.position)]=true
	var primary={"angle":PI,"reach":2.0,"arc":.6,"damage":37,"weapon":"cutlass","style":"thrust","index":0,"color":Color.WHITE,"stop":.045,"weaponContact":true}
	combat.player.attack=primary;Actions.resolve_attack(combat,primary)
	check(legacy.hp==9963,"Legacy root snapshots preserve weapon contact through the real body-radius allowance")
	boss=counted_target(Vector3(0,0,-5.6),4);boss.boss=true
	Actions.area(combat,ORIGIN+Vector3.UP*2.4,2,23,"flintlock",false,Color.WHITE,"slam",1.0)
	check(boss.hp==9977,"Area broadphase retains the legacy warden allowance beyond its nominal radius")
	game.music.stop();game.sound_library.cancel()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer2D","AudioStreamPlayer3D"]:
		for voice in game.find_children("*",kind,true,false):voice.stop();voice.stream=null
	await create_timer(.2).timeout
	game.queue_free();paused=false;await frames(3);await create_timer(.35).timeout
	if FileAccess.file_exists(config_path):DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("FOREST_COMBAT_SNAPSHOT_BROADPHASE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
