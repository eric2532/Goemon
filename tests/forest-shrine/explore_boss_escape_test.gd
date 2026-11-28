extends "res://tests/forest-shrine/explore_bosses_test.gd"

func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-boss-escape-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 6:await physics_frame
 set_test_seed();game.tuning.invincible=true;game.player.set_auto_attack(false)
 await visit_source(11004,Vector2i(16,11))
 check(setup_walkable(Tour.Regions.Sites.HABARU_FORMATION[0]+Vector2(0,5)),"Escape review starts beside the original waiting boss")
 for i in 6:await physics_frame
 press_f();check(is_instance_valid(game.dialogue),"Actual F starts the original Habaru conversation")
 await drain()
 for i in 20:await physics_frame
 game.model.waves.tick(0.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 var party=game.model.enemies.values().filter(func(e):return e.has("habaru_slot"))
 check(party.size()==10,"Original complete party exists before partial-defeat setup")
 if party.size()!=10:finish();return
 var guard=party.filter(func(e):return not e.get("boss",false))[0]
 await defeat_ids([guard.id]);game.explore_access._process(.2)
 var identity=game.explore_access.scope()+":habaru_slot"
 check(not game.explore_access.encounters[identity].cleared,"One retinue death does not clear the encounter")
 var doors=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",-1))==11003 and link.get("walk_in",false))
 check(not doors.is_empty(),"The original route out of the boss floor remains available")
 if doors.is_empty():finish();return
 await walk_door(doors[0].at)
 check(game.model.falan_floor==11003,"Actual walking leaves the unfinished arena through its original stairs")
 var back=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",-1))==11004 and link.get("walk_in",false))
 check(not back.is_empty(),"The original stairs back remain available")
 if back.is_empty():finish();return
 await walk_door(back[0].at)
 check(game.model.falan_floor==11004,"Actual walking reenters the unfinished boss floor")
 for i in 12:await physics_frame
 game.explore_access._process(.2)
 var record:Dictionary=game.explore_access.encounters.get(identity,{})
 check(not record.get("cleared",false)and not record.has("portal"),"Leaving and reentering an unfinished encounter never awards a victory portal")
 check(not game.exploration_loot.slots.any(func(slot):return slot.active and slot.get("boss",false)),"Leaving an unfinished encounter never awards its weapon chest")
 print("EXPLORE_BOSS_ESCAPE_RESULT checks=",checks," failures=",failures)
 finish()
