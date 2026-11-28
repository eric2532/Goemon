extends "res://tests/forest-shrine/chest_swords_test.gd"
func _initialize():
 create_timer(120).timeout.connect(func():quit(1))
 run.call_deferred()
func run():
 check(Gear.test_all_weapons,"Startup testing flag enables all collectible weapons")
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 for node in [game,game.player,game.camera_rig,game.army_runtime]:node.set_process(false);node.set_physics_process(false)
 var p=game.player;p.select_character(37)
 game.settings.chest_swords=[];game.settings.sword_upgrades={}
 var shin_weapons=Gear.CHEST_SWORDS+Gear.CHEST_AXES
 check(shin_weapons.all(func(id):return Gear.can_equip(Gear.character_key(37),id,game.settings)),"All nine swords and axes are usable immediately on a compatible fighter")
 for id in shin_weapons:
  equip_sword(id)
  check(p.accessory_bonuses.attack==Gear.ITEMS[id].effects.attack,"Uncollected test weapon applies its real stats: "+id)
 check(game.settings.chest_swords.is_empty() and game.settings.sword_upgrades.is_empty(),"Testing access preserves actual discoveries and upgrade ranks")
 game.load_settings()
 check(game.settings.chest_swords.is_empty() and Gear.can_equip(Gear.character_key(37),"weapon:AX024",game.settings),"Reload preserves testing access without saving fake discoveries")
 game.show_equipment_hub(true);await frames(3)
 check(shin_weapons.all(func(id):return id in game.equipment_hub.available_items()),"Equipment displays all nine collectible swords and axes for Shin at startup")
 check(Gear.can_equip(Gear.character_key(43),"weapon:BW033",game.settings),"The uncollected BW033 is immediately available to Lancelot with the testing flag")
 game.back_from_equipment();game.paused=false;paused=false
 Gear.test_all_weapons=false
 check(not Gear.can_equip(Gear.character_key(37),"weapon:AX024",game.settings),"Removing testing flag restores ordinary collection locks")
 print("STARTUP_WEAPONS_RESULT checks=%d failures=%d"%[checks,failures])
 game.music.stop();game.queue_free();paused=false;await frames(4);DirAccess.remove_absolute(cfg)
 quit(1 if failures else 0)
