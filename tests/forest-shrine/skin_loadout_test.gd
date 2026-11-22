extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Roster=Catalog.Roster
const OUT="res://build/Other Files/Skin Loadouts/"
const MIRROR="blademaster/mirror-image"
func choose_skin(character:int,id:int):
 if character==Roster.KAZI_ID:game.select_kaz_skin(id)
 elif Roster.is_shin(character):game.select_shin_skin(character,id)
 else:game.select_crossgate_skin(character,id)
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)
func run():
 create_timer(180).timeout.connect(func():printerr("SKIN_LOADOUT_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player;var loadout=p.spell_loadout
 var home=Vector3(-120,0,125);home.y=game.model.surface_height(home.x,home.z)+.05
 p.position=home;game.model.update_vision(home);game.settings.disable_character_cooldowns=false
 game.settings.spell_loadouts={};game.settings.skin_equipment={}
 game.settings.spell_loadouts={34:{"special_5":"kazi/fire"}}
 check(loadout.spell_for(34,"special_5")=="kazi/fire","Legacy numeric fighter keys remain readable")
 game.settings.spell_loadouts={}
 check(Catalog.valid_loadouts({"37:100050":{"equip":"kazi/fire"},"37:106707":{"equip":"kazi/fire"},"37:100050:1":{},"bad":{},"34:102488":{}})=={"37:100050":{"equip":"kazi/fire"},"34:102488":{}},"Skin save keys validate fighter membership and preserve explicit native loadouts")
 for character in Roster.selection_ids():
  var skins=Roster.skin_catalog(character)
  if skins.is_empty():continue
  var first:int=skins.keys()[0];var second:int=skins.keys()[1]
  game.settings.spell_loadouts[str(character)]={"special_5":"kazi/fire","special_4":"edo/beam"}
  choose_skin(character,first);p.select_character(character)
  var visual=p.model;var controller=p.active_ability
  check(loadout.spell_for(character,"special_5")=="kazi/fire","Skin %d inherits existing fighter skills"%first)
  check(loadout.equip(character,"special_5","kazi/ice"),"Skin %d accepts an existing skill"%first)
  choose_skin(character,second)
  check(loadout.spell_for(character,"special_5")=="kazi/fire","Unedited skin %d keeps the legacy setup"%second)
  check(loadout.equip(character,"special_5",Catalog.COMBO),"Skin %d saves its own skill"%second)
  choose_skin(character,first)
  check(loadout.spell_for(character,"special_5")=="kazi/ice" and loadout.numbered_slots[4][0]==Catalog.all()["kazi/ice"].name,"Returning to skin %d restores its skill and hotbar"%first)
  check(p.model==visual and p.active_ability==controller,"Skin swaps reuse the existing character and controller")
  check(game.settings.spell_loadouts[str(character)].special_5=="kazi/fire" and game.settings.spell_loadouts[str(character)].special_4=="edo/beam","Legacy settings and retired assignments remain intact")
  loadout.equip(character,"special_5","")
  check(loadout.spell_for(character,"special_5")==Catalog.defaults(character).get("special_5",""),"Restoring a skin's original skill does not re-inherit its legacy override")
  choose_skin(character,second)
  check(loadout.spell_for(character,"special_5")==Catalog.COMBO,"Restoring another skin does not change this one")
 var a=100050;var b:int=Roster.skin_catalog(Roster.SHIN_ID).keys()[1]
 choose_skin(Roster.SHIN_ID,a);p.select_character(Roster.SHIN_ID)
 check(game.skin_weapon_choices(Roster.SHIN_ID)==["Unarmed","Sword","Polearm"],"Shin offers exactly the three recovered animation sets")
 game.select_skin_weapon(Roster.SHIN_ID,2)
 check(p.model.motions.weapon=="polearm" and loadout.numbered_slots[0].is_empty(),"Polearm restores its matching weapon animation without adding skills")
 choose_skin(Roster.SHIN_ID,b);game.select_skin_weapon(Roster.SHIN_ID,1)
 choose_skin(Roster.SHIN_ID,a)
 check(p.model.shin_weapon_index==2 and p.model.motions.weapon=="polearm","Each Shin skin restores its saved weapon")
 p.active_ability.swap_weapon()
 check(p.model.shin_weapon_index==0 and game.skin_equipment(Roster.SHIN_ID).weapon==0,"Cycling saves the current skin's unarmed stance")
 choose_skin(Roster.SHIN_ID,b);choose_skin(Roster.SHIN_ID,a)
 check(p.model.motions.weapon=="unarmed","Saved unarmed stance survives a skin round trip")
 choose_skin(Roster.SHIN_SPECIAL_ID,Roster.ShinSkins.SPECIAL_DEFAULT)
 var before=game.settings.skin_equipment.duplicate(true)
 check(game.skin_weapon_choices(Roster.SHIN_SPECIAL_ID)==["Original weapon"],"A fixed special skin exposes only its recovered weapon")
 game.select_skin_weapon(Roster.SHIN_SPECIAL_ID,2)
 check(game.settings.skin_equipment==before,"Unsupported weapon assignments are rejected")
 var saizo_a=Roster.SaizoSkins.DEFAULT;var saizo_b=106052
 choose_skin(Roster.SAIZO_ID,saizo_a);p.select_character(Roster.SAIZO_ID)
 game.select_maze_primary(true,Roster.SAIZO_ID);game.select_skin_weapon(Roster.SAIZO_ID,2)
 choose_skin(Roster.SAIZO_ID,saizo_b);game.select_maze_primary(false,Roster.SAIZO_ID)
 choose_skin(Roster.SAIZO_ID,saizo_a)
 check(p.model.maze_weapon==2 and p.model.primary_throwing_weapon==1,"Saizo restores both the skin's Fist stance and Kunai-first order")
 p.active_ability.swap_weapon()
 check(p.model.maze_weapon==1 and game.skin_equipment(Roster.SAIZO_ID).weapon==1,"Saizo's weapon cycle saves the selected weapon")
 choose_skin(Roster.SAIZO_ID,saizo_b)
 check(p.model.maze_weapon==0 and p.model.primary_throwing_weapon==0,"Saizo's other skin retains Katana-first order")
 game.settings.skin_equipment["39:999999"]={"weapon":1}
 game.settings.skin_equipment["38:106707"]={"weapon":"2","primary_kunai":"yes"}
 game.save_settings();game.settings.skin_equipment={};game.settings.spell_loadouts={};game.load_settings()
 check(not game.settings.skin_equipment.has("39:999999") and not game.settings.skin_equipment.has("38:106707"),"Reload rejects unknown skin IDs and malformed weapon settings")
 choose_skin(Roster.SAIZO_ID,saizo_a)
 check(p.model.maze_weapon==1 and p.model.primary_throwing_weapon==1,"Weapon and order survive a settings reload")
 choose_skin(Roster.SAIZO_ID,saizo_b)
 check(loadout.spell_for(Roster.SAIZO_ID,"special_5")==Catalog.COMBO,"Each skin's skill set survives reload")
 # A shared cooldown belongs to the fighter/skill, so swapping skins cannot reset it.
 loadout.equip(Roster.SAIZO_ID,"special_5",Catalog.COMBO)
 var instance=loadout.instances["39:"+Catalog.COMBO]
 instance.controller.combo_cooldown=4.5
 choose_skin(Roster.SAIZO_ID,saizo_a);loadout.equip(Roster.SAIZO_ID,"special_5",Catalog.COMBO)
 check(is_equal_approx(loadout.cooldown_for("special_5"),4.5),"Shared cooldown survives a skin unequip/re-equip")
 loadout.clear_cooldowns();game.close_rogue_roster();game.paused=false;p.combat_hold_left=0
 instance=loadout.instances["39:"+Catalog.COMBO]
 p.position=home;p.velocity=Vector3.ZERO
 game.training_dummy.position=home+Vector3.FORWARD*4;game.training_dummy.home=game.training_dummy.position
 game.model.update_vision(home);await physics_frame
 p.smoke_mode=true;p.smoke_move=Vector2.ZERO;p.facing=Vector3.FORWARD
 for i in 60:p._physics_process(1.0/60)
 check(p.is_on_floor(),"The cast fixture is grounded on the actual arena")
 loadout.number_input(5,true);loadout.number_input(5,false)
 check(loadout.current!=null and loadout.current.controller.is_attacking(),"Saved skin skill starts through its numbered key")
 var hits=contacts.size()
 choose_skin(Roster.SAIZO_ID,saizo_b)
 check(loadout.current==null and loadout.held_numbers.is_empty() and not instance.controller.is_attacking(),"Skin changes cancel the old cast and held inputs")
 for i in 120:p._physics_process(1.0/60)
 check(contacts.size()==hits,"The canceled skin's attack cannot deliver a late hit")
 # The existing native mirror owner uses the equipped weapon and skills for all five copies.
 p.position=home;p.velocity=Vector3.ZERO
 loadout.equip(Roster.SAIZO_ID,"surge","kazi/ice");game.select_skin_weapon(Roster.SAIZO_ID,1)
 check(preload("res://scripts/spells/skill_balance.gd").set_level(p,MIRROR,10),"Level ten prepares the five-copy skin regression")
 check(loadout.equip(Roster.SAIZO_ID,"sky_strike",MIRROR),"Explicitly equip Mirror Image before testing the selected skin's copies")
 var mirrors=loadout.instances["39:"+MIRROR].controller.mirrors
 check(mirrors.cast(),"Existing native owner summons the skin's five copies")
 check(mirrors.bodies.size()==5 and mirrors.bodies.all(func(body):return body.model.variant_skin==saizo_b and body.model.maze_weapon==1 and body.spell_loadout.spell_for(39,"surge")=="kazi/ice"),"All five pooled copies use the current skin, weapon and skill set")
 var cast_count=0
 for body in mirrors.bodies:
  var index=body.actions.find([Catalog.all()["kazi/ice"].name,"surge"])
  if body.perform(index,game.training_dummy.global_position):cast_count+=1
 check(cast_count==5,"All five native copies can cast the skin's equipped skill simultaneously")
 for i in 12:game.army_runtime.integration_tick(1.0/60);mirrors.tick(1.0/60)
 game.camera_rig.camera.global_position=home+Vector3(10,10,20);game.camera_rig.camera.look_at(home+Vector3.UP*2)
 await capture("skin-companions-casting")
 mirrors.clear()
 game.show_rogue_roster();await frames()
 game.menu.find_child("SpellEquipmentButton",true,false).pressed.emit();await frames()
 var menu=game.menu.find_child("SpellEquipment",true,false)
 check(menu.skin_picker.visible and menu.skin_picker.selected_id==saizo_b and menu.active_weapon.item_count==3,"Loadout exposes the image picker and compatible weapons")
 menu.skin_picker.select_skin(saizo_a);await frames()
 check(menu.active_weapon.selected==1 and menu.skin_picker.selected_id==saizo_a,"Changing the skin inside Loadout restores its controls")
 menu.active_weapon.item_selected.emit(2);await frames()
 check(p.model.maze_weapon==2 and game.skin_equipment(39).weapon==2,"The visible weapon control saves and equips the current skin")
 await capture("saizo-skin-loadout")
 menu.fighter.select(menu.fighter.get_item_index(Roster.SHIN_ID));menu.fighter.item_selected.emit(menu.fighter.selected);await frames()
 menu.active_weapon.item_selected.emit(2);await frames()
 check(p.character_id==Roster.SAIZO_ID and game.skin_equipment(Roster.SHIN_ID).weapon==2,"Editing another skin's weapon does not change the active fighter")
 menu.active_weapon.get_popup().popup();await capture("shin-recovered-weapons");menu.active_weapon.get_popup().hide()
 menu.skin_picker.open_gallery();await frames();await capture("loadout-skin-pictures");menu.skin_picker.gallery.hide();await frames()
 menu.fighter.select(menu.fighter.get_item_index(Roster.SAIZO_ID));menu.fighter.item_selected.emit(menu.fighter.selected);await frames()
 root.size=Vector2i(960,600);await frames(5)
 check(root.get_visible_rect().encloses(menu.get_global_rect()),"Loadout and its footer fit after resizing the window")
 await capture("saizo-small-window")
 menu.queue_free();await frames()
 var roster_skin=game.menu.find_child("SaizoSkin",true,false)
 check(roster_skin.selected_id==saizo_a,"Closing Loadout refreshes the character gallery's skin")
 game.close_rogue_roster();await frames()
 choose_skin(Roster.SAIZO_ID,saizo_b);choose_skin(Roster.SAIZO_ID,saizo_a);await frames(5)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var times=[]
 for i in 12:
  var started=Time.get_ticks_usec();choose_skin(Roster.SAIZO_ID,saizo_b if i%2==0 else saizo_a);times.append((Time.get_ticks_usec()-started)/1000.0);await frames(3)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources+2,"Repeated switching retains no extra nodes or resources after warmup")
 times.sort();print("SKIN_SWITCH_SETUP_MS p95=%.3f max=%.3f"%[times[10],times[11]])
 var expected_skin=game.settings.saizo_skin;var expected_weapon=p.model.maze_weapon
 var expected_skill=loadout.spell_for(Roster.SAIZO_ID,"special_5")
 game.queue_free();paused=false;await frames(5)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);await frames(5)
 game.player.select_character(Roster.SAIZO_ID)
 check(game.player.model.variant_skin==expected_skin and game.player.model.maze_weapon==expected_weapon,"A new game instance initializes the saved skin and weapon")
 check(game.player.spell_loadout.spell_for(Roster.SAIZO_ID,"special_5")==expected_skill,"A new game instance restores the skin's saved skills")
 game.queue_free();paused=false;await frames(5)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SKIN_LOADOUT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
