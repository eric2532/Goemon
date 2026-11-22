extends "res://tests/forest-shrine/original_maps_test.gd"
const EVIDENCE="res://build/Other Files/Asset Toolkit/Tina Recovery/NPC Quests/"
var npcs

func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-tina-npcs-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.set_process(false);game.explorer_clock.load_hour(12)
 npcs=game.explorer_npcs;npcs.load_state({})
 if "--area-review" in OS.get_cmdline_user_args() or "--scenery-review" in OS.get_cmdline_user_args() or "--harbor-review" in OS.get_cmdline_user_args() or "--street-review" in OS.get_cmdline_user_args() or "--water-review" in OS.get_cmdline_user_args() or "--winter-review" in OS.get_cmdline_user_args() or "--pub-review" in OS.get_cmdline_user_args() or "--snow-buildings-review" in OS.get_cmdline_user_args() or "--round-buildings-review" in OS.get_cmdline_user_args() or "--bay-walls-review" in OS.get_cmdline_user_args() or "--boundary-porches-review" in OS.get_cmdline_user_args():
  var routes=[[51005,Vector2i(43,55),"tina-buildings"],[32181,Vector2i(94,66),"linked-area-entry"],[32193,Vector2i(33,39),"crystal-mine"]]
  if "--scenery-review" in OS.get_cmdline_user_args():routes=[[51005,Vector2i(43,55),"tina-detail-plaza"],[51005,Vector2i(38,33),"tina-detail-hospital"],[Original.SHALENA_SOUTH,Vector2i(584,307),"tina-detail-approach"]]
  if "--harbor-review" in OS.get_cmdline_user_args():routes=[[51005,Vector2i(54,70),"tina-harbor",11500,Vector2i(57,75)],[51005,Vector2i(28,61),"tina-tree-sign",11499,Vector2i(30,62)],[51005,Vector2i(52,40),"tina-sale-sign",11497,Vector2i(54,40)]]
  if "--street-review" in OS.get_cmdline_user_args():routes=[[51005,Vector2i(49,57),"tina-ruin-walls",11338,Vector2i(52,59)],[51005,Vector2i(48,60),"tina-small-box",10055,Vector2i(50,60)],[51005,Vector2i(52,56),"tina-barrel-stack",10033,Vector2i(54,57)]]
  if "--water-review" in OS.get_cmdline_user_args():routes=[[51005,Vector2i(41,77),"tina-hollow-logs",11482,Vector2i(42,77)],[Original.SHALENA_SOUTH,Vector2i(581,331),"road-hollow-logs",11482,Vector2i(583,331)]]
  if "--winter-review" in OS.get_cmdline_user_args():routes=[[51005,Vector2i(32,24),"winter-snowman",11465,Vector2i(34,23)],[51005,Vector2i(42,77),"winter-campfire",11484,Vector2i(44,77)],[Original.SHALENA_SOUTH,Vector2i(280,247),"winter-road-stack",11461,Vector2i(282,245)]]
  if "--pub-review" in OS.get_cmdline_user_args():routes=[[51005,Vector2i(43,55),"pub-details",11416,Vector2i(46,55)]]
  if "--snow-buildings-review" in OS.get_cmdline_user_args():routes=[[Original.SHALENA_NORTH,Vector2i(168,145),"snow-house-details",11411,Vector2i(171,143)],[Original.SHALENA_NORTH,Vector2i(210,155),"snow-pub-details",11415,Vector2i(213,153)]]
  if "--round-buildings-review" in OS.get_cmdline_user_args():routes=[[51005,Vector2i(34,28),"round-tina-hospital",11414,Vector2i(36,27)],[Original.SHALENA_NORTH,Vector2i(177,145),"round-snow-bay",11408,Vector2i(180,143)],[Original.SHALENA_NORTH,Vector2i(192,158),"round-snow-hospital",11413,Vector2i(195,156)],[Original.SHALENA_SOUTH,Vector2i(237,453),"round-road-post",11402,Vector2i(239,451)]]
  if "--bay-walls-review" in OS.get_cmdline_user_args():routes=[[51005,Vector2i(27,63),"bay-green-walls",11407,Vector2i(30,61)],[Original.SHALENA_NORTH,Vector2i(177,145),"bay-snow-walls",11408,Vector2i(180,143)],[Original.SHALENA_SOUTH,Vector2i(568,317),"bay-road-walls",11407,Vector2i(571,315)]]
  if "--boundary-porches-review" in OS.get_cmdline_user_args():routes=[[51005,Vector2i(33,40),"porch-blue-day",11409,Vector2i(36,38)],[4201,Vector2i(18,56),"porch-blue-night",11410,Vector2i(21,54)],[51005,Vector2i(62,51),"stockade-village",11140,Vector2i(65,48)],[51005,Vector2i(35,33),"carved-village-pillar",11314,Vector2i(38,31)],[Original.SHALENA_SOUTH,Vector2i(603,305),"stockade-road",11145,Vector2i(608,302)]]
  for route in routes:
   if "--boundary-porches-review" in OS.get_cmdline_user_args():game.explorer_clock.load_hour(0 if route[0]==4201 else 12)
   await visit_source(route[0],route[1])
   game.camera_rig.reset_follow()
   if route[2]=="tina-detail-approach":
    var g:Dictionary=Original.Art.data().graphics["11403"]
    var mesh=Original.Forms.mesh(11403,"building",g,Original.Art.solid_texture(int(g.page)))
    var at=game.model.world_point(Original.source_point(Original.SHALENA_SOUTH,Vector2i(587,309)))+mesh.get_aabb().get_center()*game.model.falan_scale
    game.camera_rig.set_process(false)
    game.camera_rig.camera.global_position=at+Vector3(-1,1,1).normalized()*mesh.get_aabb().size.length()*game.model.falan_scale*1.7
    game.camera_rig.camera.look_at(at)
   if route.size()>3:
    var g:Dictionary=Original.Art.data().graphics[str(route[3])]
    var mesh=Original.Forms.mesh(route[3],Original.Forms.kind(route[3],false,g),g,Original.Art.solid_texture(int(g.page)))
    var at=game.model.world_point(Original.source_point(route[0],route[4]))+mesh.get_aabb().get_center()*game.model.falan_scale
    game.camera_rig.set_process(false)
    game.camera_rig.camera.global_position=at+Vector3(-1,1.3,1).normalized()*maxf(12,mesh.get_aabb().size.length()*game.model.falan_scale*1.3)
    game.camera_rig.camera.look_at(at)
   if DisplayServer.get_name()!="headless":await snap(route[2])
  npcs.item_bag()
  if DisplayServer.get_name()!="headless":await snap("quest-travel")
  npcs.choose("cancel");finish();return
 check(npcs.data.npcs.size()==66,"All 66 source NPC records are retained")
 for record in npcs.data.npcs:
  check(record.source_row[1]==record.name and int(record.source_row[8])==int(record.floor),"Native NPC name and room "+str(record.id))
 check(npcs.data.scripts.size()==40,"All forty required source event scripts are retained")
 await visit_source(51005,Vector2i(47,35))
 npcs.update_left=0;npcs._process(.2)
 check(not npcs.nearest.is_empty() and int(npcs.nearest.record.id)==61021,"Normal proximity finds the source villager")
 var press=InputEventKey.new();press.physical_keycode=KEY_F;press.pressed=true;game._input(press)
 check(is_instance_valid(game.dialogue),"The actual F control opens the shared source conversation")
 await drain();npcs.talk_bags.clear()
 var bag={}
 for i in 3:
  await speak(61021)
  if is_instance_valid(game.dialogue):bag[game.dialogue.pages[0].text]=true
  await drain()
 check(bag.size()==3,"Village rumours draw from a bag without repeats")
 if DisplayServer.get_name()!="headless":
  await speak(61021);await snap("villager-dialogue");await drain()
 game.explorer_clock.load_hour(0)
 await visit_source(4230,Vector2i(22,13));await speak(6347);await drain()
 check(game.model.falan_floor==14018,"Night-pub dialogue sends the player to the original pirate jail")
 await speak(2059)
 check(is_instance_valid(game.dialogue) and game.dialogue.pages.back().get("options",[]).size()==4,"The prisoner exposes all three original information choices")
 npcs.choose("select[1]_100");await reveal()
 check(game.dialogue.pages[0].text.contains("海贼"),"Prisoner explains the source pirate possession story")
 npcs.choose("cancel")
 await speak(6348);await drain()
 check(npcs.count_item(18469)==1,"Guard gives the original shackles")
 check(npcs.state.durability.get("18469")==15,"Shackles retain source maximum durability")
 npcs.state.equipped=18469;npcs.state.durability["18469"]=4
 await speak(6348);await drain()
 check(is_instance_valid(game.dialogue) and game.dialogue.pages[0].text.contains("要扁他"),"Worn shackles reach the source yes/no branch")
 npcs.choose("no");await drain()
 check(npcs.state.durability.get("18469")==15 and npcs.count_item(18465)==0,"Declining replaces shackles without giving a disguise")
 npcs.state.equipped=18469;npcs.state.durability["18469"]=4
 await speak(6348);await drain();npcs.choose("yes");await drain()
 check(game.model.falan_floor==14019 and npcs.count_item(18465)==1 and npcs.count_item(18469)==0,"Accepting takes the native headband and escapes to B5")
 npcs.state.equipped=18465
 await speak(6349);await drain();check(npcs.count_item(18466)==1,"B5 guard gives source Brown wine")
 await cross(14020);await speak(6350);await drain()
 check(npcs.count_item(18466)==0 and npcs.count_item(18467)==1,"B4 exchanges the correct source wine")
 await cross(14021);await speak(6351);await drain()
 check(npcs.count_item(18467)==0 and npcs.count_item(18468)==1,"B3 gives the original handwritten note")
 await cross(14022)
 await speak(6352);await drain()
 var expected=Original.source_point(14022,Vector2i(12,2))*game.model.falan_scale
 check(Vector2(game.player.position.x,game.player.position.z).distance_to(expected)<4,"Ivory trap keeps its original transfer endpoint")
 await cross(14023);await speak(6374);await drain()
 check(game.model.falan_floor==14024 and npcs.count_item(18468)==0,"The disguise and note open the captain's room")
 await speak(81003)
 for i in 8:await physics_frame
 check(npcs.battle_ids.size()==1,"Missing captain formation uses one exact source actor as a documented adaptation")
 for id in npcs.battle_ids.keys():game.model.damage_enemy(id,10000000)
 for i in 12:await physics_frame
 check(game.model.falan_floor==14036 and int(npcs.state.done.get("81003",0))==1,"Only native captain death completes the encounter and transfers to its source result room")
 await speak(6375);await drain();npcs.choose("yes");await drain()
 check(game.model.falan_floor in [14037,14038],"The wizard leads into either source reward room")
 await visit_source(Original.SHALENA_SOUTH,Vector2i(576,268));await speak(1102730);await drain()
 npcs.choose("yes");await drain()
 check(npcs.count_item(41176)==1,"Sister supplies the original starter item")
 npcs.item_bag()
 check(game.dialogue.pages.back().options.any(func(c):return c[0]=="travel:32181"),"Explorer offers entry to the linked quest area")
 npcs.choose("travel:32181")
 for i in 8:await physics_frame
 check(game.model.falan_floor==32181,"The previously unavailable area is enterable")
 check(Original.Art.data().maps[Original.path_for(32181)].artwork_approximation,"Missing source paint stays explicitly marked as approximation")
 if DisplayServer.get_name()!="headless":await snap("linked-area-entry")
 await speak(1102732);await drain();npcs.choose("yes");await drain()
 check(npcs.count_item(41176)==0 and npcs.count_item(41177)==1,"Brother exchanges the starter item for the original crystal map")
 check(not is_instance_valid(game.dialogue),"Linked source NPC interaction closes normally")
 npcs.item_bag();npcs.choose("travel:32193")
 for i in 8:await physics_frame
 check(game.model.falan_floor==32193 and npcs.mine_ids.size()>0,"The mine is enterable and uses native source creatures")
 for id in npcs.mine_ids.keys():game.model.damage_enemy(id,10000000)
 for i in 8:await physics_frame
 check(npcs.count_item(41173)>=10,"Crystal drops make the linked quest playable in real-time")
 await speak(1102731);await drain()
 check(npcs.count_item(41177)==0 and npcs.count_item(41173)>=0,"The mine keeper consumes its source map and ten crystals")
 await speak(1102733);await drain()
 check(npcs.battle_ids.size()==4,"The guardian uses all four original flower encounter members")
 for id in npcs.battle_ids.keys():game.model.damage_enemy(id,10000000)
 for i in 12:await physics_frame
 check(game.model.falan_floor==32194,"The guardian's native death opens the source result room")
 await speak(1102734);await drain()
 check(game.model.falan_floor==32181 and npcs.count_item(41175)==1,"The guardian gives the source ancient document and return transfer")
 await speak(1102732);await drain()
 check(npcs.count_item(41175)==0 and npcs.count_item(41174)==1,"Brother exchanges the ancient document for the source letter")
 npcs.item_bag();npcs.choose("travel:4200")
 for i in 8:await physics_frame
 await visit_source(Original.SHALENA_SOUTH,Vector2i(576,268));await speak(1102730);await drain()
 check(Original.source_id(game.model.falan_floor) in [4200,4201] and npcs.count_item(41174)==0 and npcs.count_item(41178)==1,"Sister receives the letter, awards the crystal seed and returns to Tina")
 check(npcs.persist(),"Quest inventory saves through the existing atomic preferences writer")
 var stored=npcs.state.duplicate(true);npcs.load_state({});game.load_settings()
 check(npcs.state.items==stored.items and npcs.state.done==stored.done,"Quest items and progress survive reload")
 var before=npcs.state.duplicate(true)
 check(not npcs.kill_item(41178,999) and npcs.state==before,"Rejected item consumption is lossless")
 if DisplayServer.get_name()!="headless":await snap("tina-return")
 finish()

func visit_source(id:int,cell:Vector2i):
 Tour.travel(game,Original.layout(id),{"arrival":Tour.Indoor.safe_point(id,Original.source_point(id,cell)),"yaw":0.0,"velocity":Vector3.ZERO})
 for i in 6:await physics_frame
 for i in 2:await process_frame
 check(game.model.falan_floor==game.explorer_clock.phase_floor(id),"Existing Explorer loads source area "+str(id))

func speak(id:int):
 var found=npcs.actors.filter(func(e):return int(e.record.id)==id)
 check(not found.is_empty(),"Original NPC is present "+str(id))
 if found.is_empty():return
 npcs.nearest=found[0]
 if is_instance_valid(game.dialogue):npcs.choose("cancel")
 check(npcs.interact(),"NPC accepts its normal interaction "+str(id))
 await process_frame

func reveal():
 if not is_instance_valid(game.dialogue):return
 game.dialogue.revealed=game.dialogue.body.get_total_character_count();game.dialogue._process(0)
 await process_frame

func drain():
 for i in 40:
  if not is_instance_valid(game.dialogue):break
  await reveal()
  if game.dialogue.options.visible:break
  var key=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true;game.dialogue.handle_input(key)
  key=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=false
  if is_instance_valid(game.dialogue):game.dialogue.handle_input(key)
  await process_frame
 for i in 6:await physics_frame

func snap(name_:String):
 DisplayServer.window_move_to_foreground()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(EVIDENCE+name_+".png")
