extends "res://tests/forest-shrine/explore_access_test.gd"

func _initialize():
 create_timer(600).timeout.connect(func():printerr("EXPLORE_NPC_TIMEOUT");quit(1));run.call_deferred()

func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-npc-access-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 6:await physics_frame
 game.tuning.invincible=true;game.player.set_auto_attack(false)
 var report=[]
 var floors=[1121,1112,1101]
 if "--wind"in OS.get_cmdline_user_args():floors=[15569]
 for id in floors:
  Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Tour.Indoor.safe_point(id,Vector2.ZERO),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 8:await physics_frame
  game.army_runtime.refresh_navigation(0)
  game.explorer_npcs.map_signature=[];game.explorer_npcs._process(.2)
  game.explore_access.map_token=[];game.explore_access._process(.2)
  var entries=game.explorer_npcs.actors.duplicate()
  for entry in entries:
   var before=failures;var original:Vector3=entry.node.global_position
   var interaction:Vector3=entry.get("interaction_point",original);var chosen=Vector3.INF;var approach=Vector3.INF
   for radius in[1.,1.8,2.4,3.2,4.3]:
    if entry.has("interaction_point") and radius>2.5:continue
    for direction in 16:
     var offset=Vector2.from_angle(direction*TAU/16.)*radius
     var at=Vector2(interaction.x,interaction.z)/game.model.falan_scale+offset
     var point=game.model.world_point(at,.15)
     if not game.explore_access.body_clear(point) or not game.army_runtime.native.can_reach_ally(game.player.position,point,.55*game.model.falan_scale):continue
     if not game._ryo_clear_path(point+Vector3.UP*2.5,interaction+Vector3.UP*2.5):continue
     game.player.position=point;game.model.hero_position=point;game.camera_rig.yaw=atan2(point.x-interaction.x,point.z-interaction.z)
     game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
     if game.explorer_npcs.nearest.get("record",{}).get("id","")!=entry.record.id:continue
     for side in 16:
      var start_at=at+Vector2.from_angle(side*TAU/16.)*2.
      var start=game.model.world_point(start_at,.15)
      if not game.explore_access.body_clear(start):continue
      if not game._ryo_clear_path(start+Vector3.UP*1.2,point+Vector3.UP*1.2):continue
      if not game.army_runtime.native.can_reach_ally(start,point,.55*game.model.falan_scale):continue
      chosen=point;approach=start;break
     if approach.is_finite():break
    if approach.is_finite():break
   check(approach.is_finite(),"Walkable player-side conversation approach: "+entry.record.name)
   if approach.is_finite():
    game.player.position=approach;game.model.hero_position=approach;game.player.reset_physics_interpolation()
    await walk_toward(Vector2(chosen.x,chosen.z)/game.model.falan_scale,120)
    game.camera_rig.yaw=atan2(game.player.position.x-interaction.x,game.player.position.z-interaction.z)
    game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
    check(game.explorer_npcs.nearest.get("record",{}).get("id","")==entry.record.id and game.explorer_npcs.hint.visible,"Actual walk shows the correct NPC prompt")
    if "--wind"in OS.get_cmdline_user_args():await access_capture("npc-wind-prompt")
    press_f()
    if is_instance_valid(game.dialogue) and game.dialogue.speaker=="Cross Gate" and game.dialogue.pages[0].options.any(func(o):return o[0]=="talk"):game.dialogue.chosen.emit("talk")
    if is_instance_valid(game.dialogue) and game.dialogue.pages[0].options.any(func(o):return o[0]=="source"):game.dialogue.chosen.emit("source")
    check(is_instance_valid(game.dialogue) and game.dialogue.speaker==entry.record.name,"Actual F starts the conversation from the player side")
    if "--wind"in OS.get_cmdline_user_args() and is_instance_valid(game.dialogue):
     check(not game.dialogue.body.text.is_empty() and not game.dialogue.body.text.begins_with("\n"),"Recovered source dialogue fits the shared conversation box without legacy blank-line padding")
     game.dialogue.revealed=game.dialogue.body.get_total_character_count();game.dialogue._process(0)
     await access_capture("npc-wind-conversation")
    if is_instance_valid(game.dialogue):game.close_boss_dialogue()
    check(entry.node.global_position==original,"Interaction station preserves original NPC placement")
    if "--wind"in OS.get_cmdline_user_args():
     var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
     var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(4,8,.3);shape.shape=box;wall.add_child(shape);game.add_child(wall)
     wall.global_position=(game.player.position+interaction)*.5+Vector3.UP*4.;wall.rotation.y=atan2(interaction.x-game.player.position.x,interaction.z-game.player.position.z)
     await physics_frame
     game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
     check(game.explorer_npcs.nearest.get("record",{}).get("id","")!=entry.record.id,"An unrelated physical wall blocks the repaired interaction station")
     wall.free();await physics_frame
     game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
     check(game.explorer_npcs.nearest.get("record",{}).get("id","")==entry.record.id,"Removing the obstruction restores the same local NPC prompt")
    await access_capture("npc-%d-%s"%[id,entry.record.id.validate_filename()])
   report.append({"map":id,"npc":entry.record.id,"name":entry.record.name,"original":str(original),"interaction":str(interaction),"proxy":entry.has("interaction_point"),"passed":before==failures})
   var file=FileAccess.open(ACCESS_OUT+("npc-wind-"if "--wind"in OS.get_cmdline_user_args()else"npc-")+("headless"if DisplayServer.get_name()=="headless"else"rendered")+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"npcs":report,"checks":checks,"failures":failures},"  "));file.close()
 print("EXPLORE_NPC_RESULT checks=",checks," failures=",failures)
 finish()
