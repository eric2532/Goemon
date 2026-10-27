extends SceneTree
const OUT="res://build/Other Files/Team Leveling/"
var game
var checks=0
var failures=0
var legendary_choice_ms=[]
var legendary_frame_ms=[]
var cfg="user://team-leveling-test-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func frames(n:int=3):
	for i in n:await process_frame
func capture(label_:String):
	if DisplayServer.get_name()=="headless":return
	await frames(4);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Capture "+label_)
func choose(id:String,rarity:int=0):
	var p=game.model.team_progression
	var index=["Tower","Worker","Character"].find(p.CARDS[id].category);p.offer[index]=id;p.offer_rarities[index]=rarity
	game.team_upgrade_picker.refresh()
	var started=Time.get_ticks_usec()
	check(game.choose_team_upgrade(id,p.choice_level()),"Choose "+id)
	if rarity==4:legendary_choice_ms.append((Time.get_ticks_usec()-started)/1000.0)
func legendary_offer():
	var p=game.model.team_progression;p.award_kills(p.kills_required());game._process(0)
	p.offer.assign(["legendary_tower","legendary_workers","legendary_mercenaries"]);p.offer_rarities.fill(4);game.team_upgrade_picker.refresh()
func legendary_rewards():
	var p=game.model.team_progression;var h=game.explorer_helpers;var m=game.model
	var initial_workers=m.workers.size();m.gold=0;m.starting_food=0
	legendary_offer();await create_timer(.3).timeout
	var picker=game.team_upgrade_picker
	for button in picker.buttons:
		check(button.find_child("Rarity",true,false).text=="LEGENDARY","Legendary uses a distinct badge without misleading 5× bonus text")
		check(button.get_node("Shine").offset_left<0 and button.get_node("Shine").material.get_shader_parameter("rarity")==4.0,"Legendary has a larger rainbow halo")
		for label_ in ["Rarity","Title","Description","Rank"]:
			check(button.get_global_rect().encloses(button.find_child(label_,true,false).get_global_rect()),"Legendary text fits: "+label_)
	await capture("04-legendary-cards")
	var previous_frame=Time.get_ticks_usec()
	for frame in 60:
		await process_frame
		var now=Time.get_ticks_usec();legendary_frame_ms.append((now-previous_frame)/1000.0);previous_frame=now
	legendary_frame_ms.sort()
	if DisplayServer.get_name()!="headless":
		var pixels=root.get_texture().get_image().get_data();await create_timer(.6).timeout;await RenderingServer.frame_post_draw
		check(pixels!=root.get_texture().get_image().get_data() and paused,"Legendary rainbow and bright shine animate while paused")
		root.size=Vector2i(960,640);await frames(8);await capture("04-legendary-small-window")
		root.size=Vector2i(1280,800);await frames(8)
	var choice=p.choice_level();var key=InputEventKey.new();key.physical_keycode=KEY_2;key.pressed=true;game._input(key)
	check(m.workers.size()==initial_workers+10 and m.gold==0,"Legendary keyboard choice grants exactly ten free workers during battle")
	check(not game.choose_team_upgrade("legendary_workers",choice) and m.workers.size()==initial_workers+10,"A stale worker selection cannot grant twice")
	legendary_offer();choose("legendary_workers",4)
	check(m.workers.size()==initial_workers+20 and m.gold==0,"A later worker card grants ten more, independent of food")
	legendary_offer();var old_multiplier=p.multiplier("tower_damage");choose("legendary_tower",4)
	check(is_equal_approx(p.multiplier("tower_damage"),old_multiplier*5),"Legendary tower choice multiplies existing damage upgrades")
	legendary_offer();choose("legendary_tower",4)
	check(is_equal_approx(p.multiplier("tower_damage"),old_multiplier*25),"Repeated legendary tower choices multiply again")
	var previous=h.active_units().size();legendary_offer();choice=p.choice_level()
	var explored=m.explored.duplicate();m.explored.clear();var state=p.rng.state
	check(not game.choose_team_upgrade("legendary_mercenaries",choice) and p.pending()==1 and h.active_units().size()==previous and p.rng.state==state,"Blocked castle preserves the legendary choice, recruits and random state")
	m.explored=explored
	check(game.choose_team_upgrade("legendary_mercenaries",choice),"Unblocked legendary reward can be retried")
	check(h.active_units().size()==previous+5 and m.gold==0,"Legendary grants five free random mercenaries during battle")
	check(not game.choose_team_upgrade("legendary_mercenaries",choice) and h.active_units().size()==previous+5,"A stale mercenary selection cannot grant twice")
	legendary_offer();choose("legendary_mercenaries",4)
	var units=h.active_units();var kinds={};var separated=true
	for i in units.size():
		var unit=units[i];kinds[unit.slot]=true
		check(game.army_runtime.valid(unit.handle) and unit.hp==h.HEALTH[unit.slot] and unit.state=="acting","Reward recruit uses the native army lifecycle and original stats")
		check(unit.position.distance_to(m.center(m.shrine()))<44,"Reward recruit arrives near the castle")
		for j in i:
			if unit.position.distance_to(units[j].position)<1.4:separated=false
	check(units.size()==previous+10 and kinds.size()>1 and separated,"Repeated rewards produce separated random mercenaries")
	check(not h.request(0) and not m.workforce.recruit(),"Ordinary paid recruitment still requires preparation")
	var point=units[0].position+Vector3(.5,0,.5);var runtime=game.army_runtime
	var target=runtime.spawn(900010,0,0,point,1000000,.4)
	m.enemies[900010]={"id":900010,"hp":1000000.0,"max_hp":1000000.0,"pos":point,"variant":0}
	runtime.apply_hit(target,{"element":"ice","status_seconds":30.0})
	check(runtime.valid(target),"Legendary combat probe starts with a living target")
	runtime.record_events=true;runtime.event_log.clear()
	for frame in 180:
		runtime.integration_tick(1.0/60);await process_frame
	var actor_ids=units.map(func(unit):return unit.gate_id)
	var hits=runtime.event_log.filter(func(event):return event.kind=="damage" and event.target_id==900010 and event.source_id in actor_ids and event.amount>0)
	print("LEGENDARY_COMBAT hits=",hits.size()," target_alive=",runtime.valid(target)," active_recruits=",h.active_units().size())
	check(not hits.is_empty() and h.active_units().size()==previous+10,"All reward mercenaries remain native allies while engaging real combat")
	runtime.record_events=false;runtime.event_log.clear()
	game.world.sync(0);await frames(5)
	await capture("05-legendary-reinforcements")
func defeat_enemy(id:int,ticket:Dictionary={}):
	var point=game.player.position+Vector3(0,0,-12)
	game.army_runtime.spawn(id,0,0,point,10,.4)
	game.model.enemies[id]={"id":id,"hp":10.0,"max_hp":10.0,"pos":point,"variant":0}
	var actor=game.army_runtime.enemy_target(id)
	actor.take_hit(1000,Vector3.FORWARD,false,ticket)
	game.army_runtime.dispatch_events()
	actor.take_hit(1000,Vector3.FORWARD,false,ticket)
func run():
	create_timer(180).timeout.connect(func():printerr("TEAM_GAMEPLAY_TIMEOUT");quit(1))
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg
	root.add_child(game);current_scene=game;await frames(8)
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	# The fixture sends its own keys directly; desktop input must not spend its offers.
	root.gui_disable_input=true;game.set_process_input(false);game.set_process_unhandled_input(false)
	game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
	game.tuning.invincible=true;game.music.stop();root.title="Goemon Team Leveling Verification"
	var p=game.model.team_progression;var hero=game.player
	var saved_balance=game.core_balance.duplicate(true);var saved_character=game.character_tuning.duplicate(true)
	check(hero.team_progression==p,"Player uses the model's run progression")
	check(game.forest_ui.team_level_label.text.contains("TEAM LV 1"),"Team level appears beside castle health")
	p.award_kills(9);game.forest_ui.sync();await frames(3)
	var xp=game.forest_ui.team_xp_bar;var health=game.forest_ui.shrine_health_bar
	check(xp.get_global_rect().position.y>=health.get_global_rect().end.y and is_equal_approx(xp.value,.45),"Separate XP bar sits below castle health and shows partial progress")
	check(xp.get_theme_stylebox("fill").bg_color==Color("edc35c"),"Team XP uses the requested gold fill")
	await capture("01-team-hud");p.reset()
	game.start_wave();game.model.waves.spawn_clock=100000
	p.award_kills(17)
	defeat_enemy(900001)
	defeat_enemy(900002,{"tower":true})
	hero.hp=0;defeat_enemy(900003,{"allied":true})
	check(p.total_kills==20 and p.level==2 and hero.progression.level==1,"Player, tower and ally kills count once, even while hero is dead; old personal levels stay neutral")
	hero.hp=hero.max_hp
	game._process(0)
	check(game.paused and paused and is_instance_valid(game.team_upgrade_picker) and game.team_upgrade_picker.buttons.size()==3,"A level pauses the game and opens exactly three cards")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Level choice releases the combat cursor")
	var before=p.total_kills;game.award_team_kill();game.resume();game.show_pause()
	check(p.total_kills==before and is_instance_valid(game.team_upgrade_picker) and game.paused,"Pause and resume cannot bypass a pending choice or earn XP")
	var clock_before=game.model.waves.spawn_clock;var worker_before=game.model.workers.values()[0].pos
	game._process(1.0);game._physics_process(1.0)
	check(game.model.waves.spawn_clock==clock_before and game.model.workers.values()[0].pos==worker_before,"Team choice freezes wave and workforce time")
	var old_id=p.offer[0];var old_level=p.choice_level()
	var base_damage=hero.damage_multiplier();var base_speed=hero.base_attack_speed_multiplier()
	p.offer.assign(["tower_defense","worker_repair","character_damage"]);p.offer_rarities.assign([1,2,3]);game.team_upgrade_picker.refresh()
	game.team_upgrade_picker.refresh()
	check(p.offer_rarities==[1,2,3],"Refreshing the popup preserves each card's independent rarity")
	await create_timer(.3).timeout
	var picker=game.team_upgrade_picker
	print("TEAM_CARD_LAYOUT viewport=",root.size," overlay=",picker.size," panel=",picker.panel.size," position=",picker.panel.position)
	for button in picker.buttons:
		check(picker.get_global_rect().encloses(button.get_global_rect()),"Each entire card fits inside the viewport")
		check(button.find_child("Icon",true,false).texture!=null,"Each category has a prepared icon")
		for label_ in ["Category","Rarity","Title","Description","Rank"]:
			check(button.get_global_rect().encloses(button.find_child(label_,true,false).get_global_rect()),"Card text fits: "+label_)
		check(button.get_node("Shine").visible,"Rare cards have a visible shine")
	check(picker.buttons[0].find_child("Description",true,false).text.contains("40%") and picker.buttons[1].find_child("Description",true,false).text.contains("75%") and picker.buttons[2].find_child("Description",true,false).text.contains("60%"),"Silver, gold and diamond descriptions show multiplied bonuses")
	check(picker.buttons[2].find_child("Rank",true,false).text=="RANK 0 → 4","Rank preview includes the diamond bonus")
	check(picker.heading.get_global_rect().position.y>=0,"Level heading fits inside the viewport")
	await capture("02-three-team-cards")
	var shine_frames=[];var last_frame=Time.get_ticks_usec()
	for frame in 60:
		await process_frame
		var now=Time.get_ticks_usec();shine_frames.append((now-last_frame)/1000.0);last_frame=now
	shine_frames.sort()
	if DisplayServer.get_name()!="headless":
		var before_shine=root.get_texture().get_image().get_region(Rect2i(picker.buttons[1].get_global_rect())).get_data()
		await create_timer(.6).timeout;await RenderingServer.frame_post_draw
		var after_shine=root.get_texture().get_image().get_region(Rect2i(picker.buttons[1].get_global_rect())).get_data()
		check(before_shine!=after_shine and paused,"Shiny effects animate while combat is paused")
		await capture("02-rarity-shimmer")
		root.size=Vector2i(960,640);await frames(8)
		for button in picker.buttons:check(picker.get_global_rect().encloses(button.get_global_rect()),"Cards fit a smaller window")
		await capture("02-cards-small-window")
		root.size=Vector2i(1280,800);await frames(8)
	var key=InputEventKey.new();key.physical_keycode=KEY_3;key.pressed=true;game._input(key)
	check(p.ranks.get("character_damage",0)==4,"Keyboard 3 selects the diamond Character card")
	check(not is_instance_valid(game.team_upgrade_picker) and not game.paused and not paused,"Last choice restores battle state")
	check(is_equal_approx(hero.damage_multiplier(),base_damage*1.6) and is_equal_approx(hero.base_attack_speed_multiplier(),base_speed),"Diamond damage selection applies only its 60% shared bonus")
	check(not game.choose_team_upgrade(old_id,old_level),"Old selection cannot apply twice")
	p.award_kills(70);game._process(0)
	check(p.pending()==2,"Two earned levels queue two choices")
	p.offer_rarities.fill(0);game.team_upgrade_picker.refresh()
	check(game.team_upgrade_picker.buttons.all(func(button):return not button.get_node("Shine").visible),"Normal cards have no leftover rare shine")
	await capture("02-normal-team-cards")
	choose("character_speed");check(game.paused and is_instance_valid(game.team_upgrade_picker),"First queued choice keeps the world paused")
	choose("worker_revive",3)
	check(p.revival_seconds()==3,"Diamond worker revival reaches the live model")
	check(not game.paused and p.pending()==0,"Final queued choice resumes exactly once")
	for id in [1,13,30,31,32]:
		hero.select_character(id);hero.attack_chain.reset()
		var upgraded_damage=hero.damage_multiplier();var upgraded_speed=hero.base_attack_speed_multiplier()
		hero.team_progression=null;var plain_damage=hero.damage_multiplier();var plain_speed=hero.base_attack_speed_multiplier();hero.team_progression=p
		check(is_equal_approx(upgraded_damage,plain_damage*1.6) and is_equal_approx(upgraded_speed,plain_speed*1.1),"Character switch preserves team damage and cadence: %d"%id)
	hero.select_character(31)
	var mirrors=hero.active_ability.mirrors
	check(mirrors.cast(),"Five pooled mirrors spawn through the real skill")
	check(mirrors.bodies.all(func(body):return body.team_progression==p and is_equal_approx(body.damage_multiplier(),hero.damage_multiplier())),"All five mirrors inherit team damage")
	p.ranks.character_damage=5
	check(mirrors.bodies.all(func(body):return is_equal_approx(body.damage_multiplier(),hero.damage_multiplier())),"Already summoned mirrors receive later upgrades")
	p.ranks.character_damage=4;mirrors.clear()
	game.model.phase="preparing";game.set_phase_view();check(p.level==4 and p.ranks.size()==3,"Wave transitions preserve team progression")
	game.start_wave();game.model.waves.spawn_clock=100000
	await frames(10)
	var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var durations=[]
	for i in 5:
		p.award_kills(p.kills_required());game._process(0)
		var began=Time.get_ticks_usec();choose(["tower_damage","worker_speed","worker_repair","character_damage","character_speed"][i],i%4);durations.append((Time.get_ticks_usec()-began)/1000.0)
		await frames(4)
	check(get_node_count()<=nodes,"Repeated card choices release their UI nodes")
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated upgrades retain no additional resources")
	var retained_nodes=get_node_count()-nodes;var retained_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
	check(game.core_balance==saved_balance and game.character_tuning==saved_character,"Run choices leave saved balance untouched")
	game.forest_ui.sync();await capture("03-upgraded-team-hud")
	var initial_workers=game.model.workers.size()
	await legendary_rewards()
	var layout=game.active_forest_map();game.preview_forest_map(layout,false)
	check(game.model.team_progression.level==1 and game.model.team_progression.ranks.is_empty() and game.model.team_progression.pending()==0 and hero.team_progression==game.model.team_progression,"Starting a fresh map resets bonuses, XP and queued choices")
	check(hero.progression.level==1 and hero.team_progression.multiplier("character_damage")==1,"Fresh run retains no personal or shared level bonus")
	check(game.model.workers.size()==initial_workers and game.explorer_helpers.active_units().is_empty() and game.model.team_progression.multiplier("tower_damage")==1,"Fresh map clears legendary recruits and fivefold tower stacks")
	var report={"checks":checks,"failures":failures,"choice_ms":durations,"shine_frame_p95_ms":shine_frames[56],"shine_frame_max_ms":shine_frames[-1],"legendary_choice_ms":legendary_choice_ms,"legendary_frame_p95_ms":legendary_frame_ms[56],"legendary_frame_max_ms":legendary_frame_ms[-1],"retained_nodes":retained_nodes,"retained_resources":retained_resources,"renderer":DisplayServer.get_name()}
	var file=FileAccess.open(OUT+("headless" if DisplayServer.get_name()=="headless" else "desktop")+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	game.queue_free();current_scene=null;paused=false;await frames(5)
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("TEAM_LEVELING_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
