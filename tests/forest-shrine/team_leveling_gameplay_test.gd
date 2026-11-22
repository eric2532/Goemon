extends SceneTree
const OUT="res://build/Other Files/Team Leveling/Pet Cards/"
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
	var index=maxi(0,p.offer.find(id));p.offer[index]=id;p.offer_rarities[index]=rarity
	game.team_upgrade_picker.refresh()
	var started=Time.get_ticks_usec()
	check(game.choose_team_upgrade(id,p.choice_level()),"Choose "+id)
	if rarity==4:legendary_choice_ms.append((Time.get_ticks_usec()-started)/1000.0)
func legendary_offer():
	var p=game.model.team_progression;p.award_kills(p.kills_required());game._process(0)
	p.offer.assign(["legendary_goemon","legendary_musashi","legendary_illidan"]);p.offer_rarities.fill(4);game.team_upgrade_picker.refresh()
func legendary_rewards():
	var p=game.model.team_progression;var h=game.explorer_helpers;var m=game.model
	m.gold=0;m.starting_food=0
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
	var choice=p.choice_level()
	check(not game.choose_team_upgrade("legendary_dragoons",choice),"A retired company card cannot be chosen")
	choose("legendary_goemon",4)
	check(h.legendary_heroes.bodies.any(func(body):return body.leased and body.character_id==1),"The named hero reward still summons Goemon")
	check(not game.choose_team_upgrade("legendary_goemon",choice),"A stale legendary choice cannot summon twice")
	check(h.active_units().is_empty() and m.gold==0,"The card summons a hero without charging ryo or granting a company")
func pet_reward():
	var army=game.army_runtime;var p=game.model.team_progression
	var origin=Vector3(-150,0,127)
	origin.y=game.model.surface_height(origin.x,origin.z)
	game.player.position=origin
	army.integration_tick(1.0/60)
	army.queue_hounds()
	army.import_hounds()
	var id:int=army.HOUND_ID
	var existing:int=army.handles.get(id,0)
	check(existing!=0,"A guard hound is alive before picking the pet card")
	if existing==0:return
	army.apply_hit(existing,{"amount":400.0})
	p.award_kills(p.kills_required());game._process(0)
	p.offer.assign(["pet_health","pet_damage","pet_speed"]);p.offer_rarities.assign([0,0,0]);game.team_upgrade_picker.refresh()
	await capture("Pet upgrade cards")
	choose("pet_health")
	var upgraded:Dictionary=army.unit_state(existing)
	check(is_equal_approx(upgraded.max_hp,3000*p.multiplier("pet_health")) and is_equal_approx(upgraded.max_hp-upgraded.hp,400),"Choosing Pet Health immediately upgrades a wounded guard")
	var already_alive=army.handles.duplicate()
	var arrivals:Array=[]
	for tick in 10:
		army.import_hounds()
		arrivals=army.handles.keys().filter(func(key):return key<=id and not already_alive.has(key))
		if not arrivals.is_empty():break
	check(not arrivals.is_empty() and arrivals.all(func(key):return is_equal_approx(army.unit_state(army.handles[key]).max_hp,upgraded.max_hp)),"Later summons inherit the chosen Pet Health ranks")
	for i in army.Roles.HOUND_COLORS:
		var handle:int=army.handles.get(id-i,0)
		if handle!=0:army.despawn(handle)
	army.pending_hounds.clear()

func defeat_enemy(id:int,ticket:Dictionary={}):
	var point=game.player.position+Vector3(0,0,-12)
	game.army_runtime.spawn(id,0,0,point,10,.4)
	game.model.enemies[id]={"id":id,"hp":10.0,"max_hp":10.0,"pos":point,"variant":0}
	var actor=game.army_runtime.enemy_target(id)
	actor.take_hit(1000,Vector3.FORWARD,false,ticket)
	game.army_runtime.dispatch_events()
	actor.take_hit(1000,Vector3.FORWARD,false,ticket)
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	create_timer(180).timeout.connect(func():printerr("TEAM_GAMEPLAY_TIMEOUT");quit(1))
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg
	root.add_child(game);current_scene=game;await frames(8)
	check(not game.settings.forest_level_up_cards,"Level-up cards stay off for normal play")
	game.settings.forest_level_up_cards=true;game.model.team_progression.cards_enabled=true
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	# The fixture sends its own keys directly; desktop input must not spend its offers.
	root.gui_disable_input=true;game.set_process_input(false);game.set_process_unhandled_input(false)
	game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
	game.tuning.invincible=true;game.music.stop();root.title="Goemon Team Leveling Verification"
	var p=game.model.team_progression;var hero=game.player
	var saved_balance=game.core_balance.duplicate(true);var saved_character=game.character_tuning.duplicate(true)
	check(hero.team_progression==p,"Player uses the model's run progression")
	check(game.forest_ui.team_level_label.text=="1","Team level appears in the character hub")
	p.award_kills(9);game.forest_ui.sync();await frames(3)
	var xp=game.forest_ui.team_xp_bar
	check(is_equal_approx(xp.value,9.0/16) and xp.is_visible_in_tree() and xp.get_global_rect().encloses(game.forest_ui.hero_portrait.get_global_rect()),"Visible XP semicircle shows partial progress around the character portrait")
	check(xp.texture_progress==game.forest_ui.skin.texture("xp_fill"),"Team XP uses the requested purple fill")
	await capture("01-team-hud");p.reset()
	check(game.model.workers.is_empty() and game.world.worker_nodes.is_empty(),"The opening settlement has zero workers")
	var gold=game.model.gold
	game.recruit_worker()
	check(game.model.workers.size()==1 and game.model.gold==gold-50,"Paid recruitment adds the first worker")
	game.start_wave();game.model.waves.spawn_clock=100000
	p.award_kills(13)
	defeat_enemy(900001)
	defeat_enemy(900002,{"tower":true})
	hero.hp=0;defeat_enemy(900003,{"allied":true})
	check(p.total_kills==16 and p.level==2 and hero.progression.level==1,"Player, tower and ally kills credit character XP once, even while hero is dead")
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
	p.offer.assign(["pet_health","pet_speed","character_damage"]);p.offer_rarities.assign([1,2,3]);game.team_upgrade_picker.refresh()
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
	check(picker.buttons[0].find_child("Description",true,false).text.contains("60%") and picker.buttons[1].find_child("Description",true,false).text.contains("60%") and picker.buttons[2].find_child("Description",true,false).text.contains("120%"),"Silver, gold and diamond descriptions show stronger multiplied bonuses")
	check(picker.buttons[2].find_child("Rank",true,false).text=="RANK 0 → 4\nTEAM TOTAL ×1.00 → ×2.20","Rank and total preview include the diamond bonus")
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
	check(is_equal_approx(hero.damage_multiplier(),base_damage*2.2) and is_equal_approx(hero.base_attack_speed_multiplier(),base_speed),"Diamond damage selection applies its 120% shared bonus")
	check(not game.choose_team_upgrade(old_id,old_level),"Old selection cannot apply twice")
	p.award_kills(80);game._process(0)
	check(p.pending()==2,"Two earned levels queue two choices")
	p.offer_rarities.fill(0);game.team_upgrade_picker.refresh()
	check(game.team_upgrade_picker.buttons.all(func(button):return not button.get_node("Shine").visible),"Normal cards have no leftover rare shine")
	await capture("02-normal-team-cards")
	choose("character_speed");check(game.paused and is_instance_valid(game.team_upgrade_picker),"First queued choice keeps the world paused")
	choose("pet_speed",3)
	check(is_equal_approx(p.multiplier("pet_speed"),1.8),"Diamond pet speed reaches the live model")
	check(not game.paused and p.pending()==0,"Final queued choice resumes exactly once")
	for id in [1,13,30,31,32]:
		hero.select_character(id);hero.attack_chain.reset()
		var upgraded_damage=hero.damage_multiplier();var upgraded_speed=hero.base_attack_speed_multiplier()
		hero.team_progression=null;var plain_damage=hero.damage_multiplier();var plain_speed=hero.base_attack_speed_multiplier();hero.team_progression=p
		check(is_equal_approx(upgraded_damage,plain_damage*2.2*p.stat_damage_multiplier()) and is_equal_approx(upgraded_speed,plain_speed*1.2*p.stat_attack_multiplier()),"Character switch preserves team damage and cadence: %d"%id)
	hero.select_character(31)
	var mirrors=hero.active_ability.mirrors
	check(mirrors.cast(),"Five pooled mirrors spawn through the real skill")
	check(mirrors.bodies.all(func(body):return body.team_progression==p and is_equal_approx(body.damage_multiplier(),hero.damage_multiplier()/p.stat_damage_multiplier())),"All five mirrors inherit team damage")
	p.ranks.character_damage=5
	check(mirrors.bodies.all(func(body):return is_equal_approx(body.damage_multiplier(),hero.damage_multiplier()/p.stat_damage_multiplier())),"Already summoned mirrors receive later upgrades")
	p.ranks.character_damage=4;mirrors.clear()
	game.model.phase="preparing";game.set_phase_view();check(p.level==4 and p.ranks.size()==3,"Wave transitions preserve team progression")
	game.start_wave();game.model.waves.spawn_clock=100000
	await frames(10)
	var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var durations=[]
	for i in 5:
		p.award_kills(p.kills_required());game._process(0)
		var began=Time.get_ticks_usec();choose(["pet_damage","pet_speed","pet_health","character_damage","character_speed"][i],i%4);durations.append((Time.get_ticks_usec()-began)/1000.0)
		await frames(4)
	check(get_node_count()<=nodes,"Repeated card choices release their UI nodes")
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated upgrades retain no additional resources")
	var retained_nodes=get_node_count()-nodes;var retained_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
	check(game.core_balance==saved_balance and game.character_tuning==saved_character,"Run choices leave saved balance untouched")
	game.forest_ui.sync();await capture("03-upgraded-team-hud")
	await pet_reward()
	await legendary_rewards()
	var layout=game.active_forest_map();game.preview_forest_map(layout,false)
	check(game.model.team_progression.level==1 and game.model.team_progression.ranks.is_empty() and game.model.team_progression.pending()==0 and hero.team_progression==game.model.team_progression,"Starting a fresh map resets bonuses, XP and queued choices")
	check(hero.progression.level==1 and hero.team_progression.multiplier("character_damage")==1,"Fresh run retains no personal or shared level bonus")
	check(game.model.workers.is_empty() and game.explorer_helpers.active_units().is_empty() and game.model.team_progression.multiplier("pet_health")==1,"Fresh map starts at zero workers and clears legendary recruits and pet ranks")
	await cards_setting(layout)
	var report={"checks":checks,"failures":failures,"choice_ms":durations,"shine_frame_p95_ms":shine_frames[56],"shine_frame_max_ms":shine_frames[-1],"legendary_choice_ms":legendary_choice_ms,"legendary_frame_p95_ms":legendary_frame_ms[56],"legendary_frame_max_ms":legendary_frame_ms[-1],"retained_nodes":retained_nodes,"retained_resources":retained_resources,"renderer":DisplayServer.get_name()}
	var file=FileAccess.open(OUT+("headless" if DisplayServer.get_name()=="headless" else "desktop")+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	game.queue_free();current_scene=null;paused=false;await frames(5)
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("TEAM_LEVELING_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func cards_setting(layout:Dictionary):
	game.start_wave();game.model.waves.spawn_clock=100000
	var p=game.model.team_progression
	game.show_pause();game.show_settings(true)
	var toggle:CheckButton=game.menu.find_child("ForestLevelUpCardsToggle",true,false)
	check(toggle!=null and toggle.button_pressed,"Pause settings reflect cards explicitly enabled for this fixture")
	if toggle==null:return
	p.ranks.character_damage=2;p.award_kills(p.kills_required())
	toggle.button_pressed=false
	check(p.pending()==0 and p.offer.is_empty() and p.offer_rarities.is_empty(),"Switching cards off discards queued choices")
	game.resume()
	var rng_state=p.rng.state
	game.award_team_kill(p.kills_required()*10);game._process(0)
	check(p.level==3 and p.ranks.character_damage==2 and p.rng.state==rng_state,"Cards off preserves XP and earned ranks without rolling offers")
	check(not game.paused and not paused and not is_instance_valid(game.team_upgrade_picker),"A level-up with cards off keeps the wave running")
	game.load_settings();game.preview_forest_map(layout,false)
	p=game.model.team_progression
	check(not game.settings.forest_level_up_cards and not p.cards_enabled,"The setting persists after reload and applies to fresh maps")
	game.start_wave();game.model.waves.spawn_clock=100000
	game.award_team_kill(p.kills_required()*10);game._process(0)
	game.show_pause();game.show_settings(true)
	toggle=game.menu.find_child("ForestLevelUpCardsToggle",true,false)
	check(toggle!=null and not toggle.button_pressed,"The settings menu shows the saved off state")
	if toggle==null:return
	await capture("06-level-up-cards-off")
	toggle.button_pressed=true;game.resume();game._process(0)
	check(not paused and p.pending()==0,"Re-enabling cards leaves skipped levels behind")
	game.award_team_kill(p.kills_required()*10);game._process(0)
	check(paused and p.pending()==1 and is_instance_valid(game.team_upgrade_picker),"The next level opens the usual card picker again")
