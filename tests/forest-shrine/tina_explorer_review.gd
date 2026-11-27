extends "res://tests/forest-shrine/original_maps_test.gd"
const EVIDENCE="res://build/Other Files/Asset Toolkit/Tina Recovery/Explorer Scenery/"

func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-tina-scenery-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.set_process(false);game.explorer_clock.load_hour(12)
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
 if "--area-polish-review" in OS.get_cmdline_user_args():routes=[[51005,Vector2i(33,40),"polish-tina-blue",11409,Vector2i(36,38)],[4201,Vector2i(18,56),"polish-tina-night",11410,Vector2i(21,54)],[Original.SHALENA_SOUTH,Vector2i(584,307),"polish-green-approach",11403,Vector2i(587,309)],[Original.SHALENA_NORTH,Vector2i(211,157),"polish-snow-sign",11491,Vector2i(214,155)],[Original.SHALENA_NORTH,Vector2i(169,157),"polish-snow-wall",11354,Vector2i(172,157)],[Original.SHALENA_NORTH,Vector2i(196,159),"polish-snow-crate",11466,Vector2i(199,158)],[Original.SHALENA_NORTH,Vector2i(168,145),"polish-snow-house",11411,Vector2i(171,143)]]
 if "--remaining-street-review" in OS.get_cmdline_user_args():routes=[[51005,Vector2i(43,55),"tina-pub",11416,Vector2i(46,55)],[51005,Vector2i(64,51),"tina-bench",11041,Vector2i(67,49)],[51005,Vector2i(45,13),"tina-wooden-crate",11016,Vector2i(48,11)],[51005,Vector2i(77,53),"tina-mushroom-clusters",11099,Vector2i(80,53)],[4201,Vector2i(43,55),"tina-pub-night",11416,Vector2i(46,55)],[Original.SHALENA_SOUTH,Vector2i(578,295),"road-open-bench",10037,Vector2i(580,293)],[Original.SHALENA_NORTH,Vector2i(210,155),"northern-snow-pub",11415,Vector2i(213,153)],[51012,Vector2i(131,52),"university-snow-house",11412,Vector2i(134,50)]]
 if "--round-stone-review" in OS.get_cmdline_user_args():routes=[[51005,Vector2i(33,29),"tina-round-hospital",11414,Vector2i(36,27)],[51005,Vector2i(68,54),"tina-original-graveyard",11051,Vector2i(70,52)],[4201,Vector2i(33,29),"tina-round-hospital-night",11414,Vector2i(36,27)],[Original.SHALENA_SOUTH,Vector2i(574,283),"road-round-hospital",11414,Vector2i(577,281)],[Original.SHALENA_SOUTH,Vector2i(609,308),"road-original-graveyard",11051,Vector2i(611,306)],[Original.SHALENA_NORTH,Vector2i(192,158),"north-snow-hospital",11413,Vector2i(195,156)],[Original.SHALENA_NORTH,Vector2i(212,137),"north-snow-graveyard",11471,Vector2i(215,135)],[Original.SHALENA_NORTH,Vector2i(166,144),"north-small-marker",11474,Vector2i(169,142)]]
 for route in routes:
  if "--boundary-porches-review" in OS.get_cmdline_user_args() or "--area-polish-review" in OS.get_cmdline_user_args() or "--remaining-street-review" in OS.get_cmdline_user_args() or "--round-stone-review" in OS.get_cmdline_user_args():game.explorer_clock.load_hour(0 if route[0]==4201 else 12)
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
 finish()

func visit_source(id:int,cell:Vector2i):
 Tour.travel(game,Original.layout(id),{"arrival":Tour.Indoor.safe_point(id,Original.source_point(id,cell)),"yaw":0.0,"velocity":Vector3.ZERO})
 for i in 6:await physics_frame
 for i in 2:await process_frame
 check(game.model.falan_floor==game.explorer_clock.phase_floor(id),"Existing Explorer loads source area "+str(id))

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
 var folder="res://build/Other Files/Asset Toolkit/Tina Recovery/Area Polish/Explorer/" if "--area-polish-review" in OS.get_cmdline_user_args() else EVIDENCE
 if "--remaining-street-review" in OS.get_cmdline_user_args():folder="res://build/Other Files/Asset Toolkit/Tina Recovery/Remaining Street Polish/Explorer/"
 if "--round-stone-review" in OS.get_cmdline_user_args():folder="res://build/Other Files/Asset Toolkit/Tina Recovery/Round and Stone Polish/Explorer/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+name_+".png")
