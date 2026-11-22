extends "res://tests/forest-shrine/team_leveling_gameplay_test.gd"
## Named rewards, free category slots and player-only reach through the real picker.
const Roster=preload("res://scripts/rogue_roster.gd")
var output="res://build/Other Files/Team Leveling/Free Draft/"
var reach_times=[]
func capture(label_:String):
	if DisplayServer.get_name()=="headless":return
	await frames(4);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+label_+".png")==OK,"Capture "+label_)
func present(ids:Array,rarities:Array):
	var p=game.model.team_progression
	p.award_kills(p.kills_required());game._process(0)
	p.offer.assign(ids);p.offer_rarities.assign(rarities);game.team_upgrade_picker.refresh()
func layout_check():
	for button in game.team_upgrade_picker.buttons:
		for label_ in ["Category","Title","Description","Rank"]:
			check(button.get_global_rect().encloses(button.find_child(label_,true,false).get_global_rect()),"Named card text fits: "+label_)
func run():
	create_timer(240).timeout.connect(func():printerr("TEAM_CATALOG_TIMEOUT");quit(1))
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg
	root.add_child(game);current_scene=game;await frames(8)
	game.settings.forest_level_up_cards=true;game.model.team_progression.cards_enabled=true
	game.start_wave();game.model.waves.spawn_clock=100000
	for node in [game,game.player,game.camera_rig,game.army_runtime,game.explorer_helpers]:node.set_process(false);node.set_physics_process(false)
	root.gui_disable_input=true;game.set_process_input(false);game.set_process_unhandled_input(false)
	game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
	game.camera_rig.set_process_unhandled_input(false);game.music.stop();root.title="Goemon · Free card choices"
	var p=game.model.team_progression;var hero=game.player;var helpers=game.explorer_helpers
	var indicator=preload("res://scripts/forest/player_attack_range.gd").new()
	var base=hero.melee_reach_setting();var old_circle=indicator.radius(hero)
	present(["character_damage","player_range","character_speed"],[0,0,0])
	await frames(5);layout_check();await capture("all-character-cards")
	check(game.team_upgrade_picker.buttons.all(func(button):return button.find_child("Category",true,false).text.ends_with("CHARACTER")),"Every slot can show a Character card")
	check(game.team_upgrade_picker.buttons[1].find_child("Rank",true,false).text=="RANK 0 → 1\nPLAYER TOTAL ×1.00 → ×1.25","Reach preview states player-only bonus")
	choose("player_range")
	check(is_equal_approx(hero.melee_reach_setting(),base*1.25) and indicator.radius(hero)>old_circle,"Normal range card expands actual melee setting and cached ground outline")
	present(["player_range","pet_speed","pet_health"],[3,0,0]);choose("player_range",3)
	check(is_equal_approx(hero.melee_reach_setting(),base*2.25),"Diamond reach adds four ranks to the normal rank")
	for character in [1,5,7,8,11,13,15,16,17,28,29,31,32,33]:
		hero.select_character(character);hero.attack_chain.reset()
		var expanded=hero.melee_reach_setting();var radius=indicator.radius(hero)
		p.ranks.player_range=0;var plain=hero.melee_reach_setting();var plain_radius=indicator.radius(hero);p.ranks.player_range=5
		check(is_equal_approx(expanded,plain*2.25) and radius>plain_radius,"Switching fighter %d preserves player reach and refreshes outline"%character)
	hero.select_character(31);hero.cancel_charge();hero.position=Vector3(0,game.model.surface_height(0,75)+.15,75);hero.facing=Vector3.FORWARD
	game.model.hero_position=hero.position;game.model.update_vision(hero.position)
	var combat=hero.active_ability;var plain_reach=combat.Kit.MELEE_REACH*hero.contact_size_multiplier()*hero.combat_tuning("melee_reach")
	var point=hero.position+hero.facing*(plain_reach*1.6);point.y=game.model.surface_height(point.x,point.z)
	var row=game.model.waves.spawn_enemy(0,point);row.hp=100000;row.max_hp=row.hp;game.army_runtime.import_arrivals()
	var enemy=game.army_runtime.enemy_target(row.id)
	p.ranks.player_range=0;combat.ticket=hero.attack_chain.begin("warcraft_attack","range-baseline");combat.strike(false)
	var hp=enemy.hp;check(hp==100000,"Enemy beyond baseline reach is not hit")
	p.ranks.player_range=5;combat.ticket=hero.attack_chain.begin("warcraft_attack","range-upgraded");combat.strike(false)
	check(enemy.hp<hp,"The range card reaches the same real native enemy without moving")
	game.army_runtime.despawn(game.army_runtime.handles[row.id]);game.model.enemies.erase(row.id)
	var mirrors=combat.mirrors;check(mirrors.cast(),"Normal five-copy skill works after player reach upgrades")
	check(mirrors.bodies.all(func(body):return is_equal_approx(body.melee_reach_setting(),hero.melee_reach_setting()/2.25)),"Player range does not apply to any of the five summoned copies")
	mirrors.clear()
	game.model.gold=0;game.model.starting_food=0
	for id in p.CARDS:
		var card=p.CARDS[id]
		if not card.has("hero"):continue
		present(["legendary_goemon","legendary_musashi","legendary_illidan"],[4,4,4])
		choose(id,4)
		var body=helpers.legendary_heroes.bodies.back()
		check(body.character_id==card.hero and body.leased,"Card summons exactly "+card.title)
		check(is_equal_approx(body.melee_reach_setting(),body.combat_tuning("melee_reach")),"Named hero keeps its own reach")
	check(p.CARDS.values().all(func(card):return not card.has("mercenary")),"The popup catalog excludes mercenary companies")
	present(["legendary_goemon","legendary_musashi","legendary_illidan"],[4,4,4])
	await frames(5);layout_check();await capture("named-heroes")
	for i in 3:
		var id=p.offer[i];check(game.team_upgrade_picker.buttons[i].find_child("Icon",true,false).texture==Roster.selection_portrait(p.CARDS[id].hero),"Hero card shows its named portrait in slot %d"%i)
	root.size=Vector2i(960,640);await frames(5);layout_check();await capture("named-heroes-small")
	root.size=Vector2i(1280,800);choose("legendary_goemon",4)
	await frames(5)
	var nodes=get_node_count()
	for rank in [0,5]:
		p.ranks.player_range=rank;indicator.radius(hero)
		var samples=[]
		for i in 240:
			var began=Time.get_ticks_usec();indicator.radius(hero);hero.melee_reach_setting();samples.append((Time.get_ticks_usec()-began)/1000.0)
		samples.sort();reach_times.append({"rank":rank,"p95_ms":samples[228],"max_ms":samples[-1]})
	var layout=game.active_forest_map();game.preview_forest_map(layout,false)
	check(game.model.team_progression.ranks.is_empty() and game.model.team_progression.multiplier("player_range")==1.0,"Fresh run removes player reach and named rewards")
	var report={"checks":checks,"failures":failures,"reach_query":reach_times,"node_delta":get_node_count()-nodes,"renderer":DisplayServer.get_name()}
	FileAccess.open(output+("catalog-headless" if DisplayServer.get_name()=="headless" else "catalog-desktop")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.queue_free();current_scene=null;paused=false;await frames(5)
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("TEAM_CATALOG_RESULT ",JSON.stringify(report));quit(1 if failures else 0)
