extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Loot=preload("res://scripts/forest/exploration_loot.gd")
const OUT="res://build/Other Files/Asset Toolkit/Jello Glow/Shape Border/"

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Capture "+stem)

func run():
 create_timer(180,true,false,true).timeout.connect(func():printerr("JELLO_GLOW_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 cfg="/tmp/crossgate-jello-glow-%d.cfg"%OS.get_process_id()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var loot=game.exploration_loot;loot.set_process(false)
 var p=game.player;p.select_character(37);p.refresh_max_health();p.hp=p.max_hp
 p.position=Vector3(-120,game.model.world_height(-120,125)+.05,125)
 game.model.update_vision(p.position);game.tuning.invincible=true
 game.camera_rig.camera.global_position=p.position+Vector3(4,4,8)
 game.camera_rig.camera.look_at(p.position+Vector3.UP*1.5)
 var aura=p.aura;aura.set_process(false)
 var gold=Geo.mat("fff0a3",0,2);var original=gold.albedo_color
 var kinds=[Loot.RED_JELLY,Loot.BLUE_JELLY,Loot.GREEN_JELLY]
 var colors=[Color("ff2448"),Color("2488ff"),Color("38ff65")]
 for i in 3:
  p.clear_food_buffs();loot.clear()
  loot.spawn_food(kinds[i],p.position+Vector3.RIGHT*3)
  loot._process(.1)
  check(not aura.visible,"Glow waits for the actual food to finish its pickup flight")
  loot._process(Loot.CONSUME_TIME);aura._process(.2)
  check(aura.visible and aura.current_tint==colors[i],"Consumed jello lights the player with its matching color")
  check(not aura.light.visible and not aura.energy_shell.visible,"Jello has no cylinder or ground-casting light")
  check(aura.rays.size()==14 and aura.ray_material.emission==colors[i],"The fourteen floating lights retain the matching color")
  check(p.model.food_glow_tint==colors[i],"The controlled character silhouette receives the matching border color")
  await capture(["red","blue","green"][i])
  if i==0:
   for action in [1,5]:
    p.model.show_pose(action,.13,false)
    if DisplayServer.get_name()!="headless":
     check(p.model.sprite.get_instance_shader_parameter("food_glow")==colors[i],"Pose changes retain the player's instance outline")
    await capture("red-pose-%d"%action)
   p.model.jump_count=1;p.model.jump_age=.01;p.jumps_used=1
   p.model.show_jump_pose(false,4.0)
   await capture("red-jump")
   p.model.reset_jump_pose();p.jumps_used=0
   p.model.show_pose(0,0,true)
  var before:Vector3=aura.global_position;p.position+=Vector3.RIGHT
  check(aura.global_position==before+Vector3.RIGHT,"The glow follows actual character movement")
  p.tick_food_buffs(299)
  check(aura.visible,"Glow persists while its five-minute bonus remains")
  p.tick_food_buffs(1)
  check(not aura.visible and aura.current_tint==Color.TRANSPARENT and p.model.food_glow_tint==Color.TRANSPARENT,"Expiry clears the outline and floating lights")
 check(gold.albedo_color==original and gold.emission==original and aura.ray_material!=gold,"Player glow never mutates the shared Geo material")
 for kind in kinds:loot.eat(kind)
 for i in 3:
  aura.clock=i*1.5;aura._process(0)
  check(aura.current_tint==colors[i],"Simultaneous jellos retain each distinct color in the cycle")
 p.food_buffs.jelly_magic=.1;p.tick_food_buffs(.1)
 check(aura.food_colors==[colors[0],colors[2]],"Only the expired color leaves the active cycle")
 var clock:float=aura.clock
 game.paused=true;aura._process(1);game.paused=false
 check(aura.clock==clock,"Pause freezes glow animation and its color cycle")
 game.transitioning=true;aura._process(1);game.transitioning=false
 check(aura.clock==clock,"Travel freezes glow animation")
 for fighter in [p.RogueRoster.KAZI_ID,38,37]:
  p.select_character(fighter);aura._process(0)
  check(p.aura==aura and aura.visible and aura.food_colors.size()==2 and p.model.food_glow_tint==aura.current_tint,"Character changes retain the correct silhouette outline and floating lights")
 p.surge_left=2;aura._process(0)
 check(aura.current_tint==Color.TRANSPARENT and aura.energy_shell.visible and aura.light.visible and p.model.food_glow_tint==Color.TRANSPARENT,"Golden Surge alone retains its original full aura")
 p.end_surge();aura._process(0)
 check(aura.visible and aura.current_tint.a==1,"Food glow resumes when Surge ends")
 p.hp=0;aura._process(.1)
 check(not aura.visible and p.model.food_glow_tint==Color.TRANSPARENT,"Death removes the outline without discarding food bonuses")
 p.hp=p.max_hp;p.tick_food_buffs(0);aura._process(0)
 check(aura.visible,"Living player resumes a retained food glow")
 # Returning to an old model after expiry must not restore a stale border.
 p.clear_food_buffs();p.select_character(p.RogueRoster.KAZI_ID);aura._process(0)
 check(p.model.food_glow_tint==Color.TRANSPARENT,"A previously glowing hidden character returns without a stale outline")
 p.select_character(37)
 for kind in kinds:loot.eat(kind)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 100:
  p.clear_food_buffs()
  for kind in kinds:loot.eat(kind)
  aura._process(.02)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated three-color use retains prepared nodes and resources")
 p.clear_food_buffs()
 check(not aura.visible and aura.food_colors.is_empty(),"New-run food cleanup removes the whole glow")
 var path=game.settings_path;game.queue_free();current_scene=null;paused=false;await frames(4)
 if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("JELLO_GLOW_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
