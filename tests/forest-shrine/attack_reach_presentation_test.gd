extends SceneTree
const AttackRange=preload("res://scripts/forest/player_attack_range.gd")
var game
var checks=0
var failures=0
var cfg="user://attack-reach-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func frames(count=3):
 for i in count:await process_frame
func tune(id:int,reach:float):
 game.character_tuning[game.CharacterBalance.key_for(id)]={"melee_reach":reach}
func run():
 create_timer(180).timeout.connect(func():printerr("ATTACK_REACH_TIMEOUT");quit(1))
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 for node in [game,game.player,game.camera_rig,game.army_runtime]:node.set_process(false);node.set_physics_process(false)
 game.music.stop();game.camera_focused=false;game._sync_camera_mouse()
 var hero=game.player;hero.position=Vector3(0,2,75);game.model.hero_position=hero.position
 var indicator=AttackRange.new();var base=indicator.radius(hero)
 check(base>1 and base<20,"Goemon circle measures the authored basic swing envelope")
 tune(1,4);var expanded=indicator.radius(hero);print("ATTACK_RANGE_RADII base=",base," expanded=",expanded)
 check(expanded>base*2.5,"Circle follows increased reach without using the compact rendered pipe")
 hero.model.pipe_visual_scale=1.15*4;hero.combo=1;hero.attack_duration=hero.OriginalGoemon.duration(1);hero.attack_left=hero.attack_duration-.12
 hero.model.animate(.016,0,true,0,hero.attack_left/hero.attack_duration,false,1,false);hero.model.sync_skeleton()
 var full=hero.model.pipe_pose(0x68,.12,hero.model.pipe_visual_scale)
 check(full.basis.x.length()/hero.model.pipe.basis.x.length()>2.9,"Goemon keeps full contact scale and caps only the displayed pipe")
 hero.model.animate(.016,0,true,0,hero.attack_left/hero.attack_duration,false,1,false);hero.model.sync_skeleton()
 check(hero.model.reach_trail.samples.size()>0,"Extended pipe uses the prepared wave ribbon")
 hero.cancel_charge();hero.model.animate(.3,0,true,0,0,false,0,false);hero.model.sync_skeleton()
 check(hero.model.reach_trail.samples.is_empty(),"Pipe wave clears after the attack")
 game.world.sync(0)
 var ground=game.world.kai_materials.filter(func(m):return m.shader==preload("res://scripts/forest/wind_meadow_ground.gdshader"))[0]
 check(is_equal_approx(ground.get_shader_parameter("attack_radius"),expanded),"Actual terrain material receives the current range")
 check(game.world.attack_materials.size()==2 and game.world.attack_materials.all(func(m):return is_equal_approx(m.get_shader_parameter("attack_radius"),expanded)),"Stone stairs share the terrain outline without changing other stone materials")
 check(ground.get_shader_parameter("attack_center")==Vector2(0,75),"Outline follows the player on the ground")
 game.model.phase="preparing";game.world.sync(0)
 check(ground.get_shader_parameter("attack_radius")==0.0,"Preparation hides the combat circle")
 game.model.phase="wave"
 for id in [3,4,5,7,8,9,11,12]:
  hero.select_character(id);tune(id,1);var normal=indicator.radius(hero)
  tune(id,4);var extended=indicator.radius(hero)
  var c=hero.active_ability
  if id==3:c.attack()
  else:c.begin_cast("primary");c.Actions.begin_primary(c)
  var a=c.player.attack
  check(normal>0 and extended>normal*2,"Fighter %d circle follows full primary reach"%id)
  check(a!=null and a.reach>normal*2,"Fighter %d keeps its contact reach"%id)
  a.time=a.contact;c._animate(0,0)
  var shown=c.visual_actor.joints.Weapon_Cutlass.node.global_basis.get_scale().length()
  var pose=c.player.duplicate();pose.meleeVisualScale=a.meleeVisualScale;pose.uncappedWeapon=true
  c.visual_actor.animate_pose(pose,0,c.time,0)
  var uncapped=c.visual_actor.joints.Weapon_Cutlass.node.global_basis.get_scale().length()
  check(uncapped>shown*2,"Fighter %d weapon stays compact at fourfold reach"%id)
  c._animate(.016,0);a.time+=.02;c._animate(.016,0)
  if c._uses_blade_brush(a):check(float(a.get("bladeWaveScale",0))>2,"Fighter %d extends its existing painted wave"%id)
  c.cancel()
 for id in [13,15,16,17,28,29,31,32,33]:
  hero.select_character(id);tune(id,1);var normal=indicator.radius(hero);tune(id,4)
  check(normal>0 and indicator.radius(hero)>normal*1.5,"Recovered fighter %d circle follows its controller reach"%id)
 hero.select_character(10)
 check(indicator.radius(hero)==0,"Ranged attacks do not display a misleading melee circle")
 hero.select_character(1);tune(1,4);hero.hp=0;game.world.sync(0)
 check(ground.get_shader_parameter("attack_radius")==0.0,"Defeat hides the outline")
 hero.hp=hero.max_hp;game.world.sync(0)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var timings=[]
 for i in 600:
  hero.position.x=i*.01;game.model.hero_position=hero.position
  var before=Time.get_ticks_usec();game.world.sync(.016);timings.append(Time.get_ticks_usec()-before)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Moving circle reuses terrain nodes and materials")
 timings.sort();print("ATTACK_RANGE_WORLD_SYNC_US p95=",timings[int(timings.size()*.95)]," max=",timings.back())
 await allied_reuse()
 if DisplayServer.get_name()!="headless":
  hero.hp=hero.max_hp;hero.position=Vector3(0,game.model.surface_height(0,75)+.15,75);game.model.hero_position=hero.position
  tune(1,1);hero.model.pipe_visual_scale=1.15;hero.model.animate(0,0,true,0,0,false,0,false);hero.model.sync_skeleton();game.world.sync(0)
  game.camera_rig.camera.global_position=hero.position+Vector3(8,12,18);game.camera_rig.camera.look_at(hero.position+Vector3.UP)
  game.camera_rig.camera.current=true;await frames();await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Attack Reach/ground-circle.png")==OK,"Capture faint terrain circle on supported ground")
  tune(1,4);hero.model.pipe_visual_scale=1.15*4;hero.combo=1;hero.attack_duration=hero.OriginalGoemon.duration(1)
  for at in [.10,.12,.14]:
   hero.attack_left=hero.attack_duration-at;hero.model.animate(.02,0,true,0,hero.attack_left/hero.attack_duration,false,1,false);hero.model.sync_skeleton()
  game.world.sync(0);game.camera_rig.camera.global_position=hero.position+Vector3(18,28,38);game.camera_rig.camera.look_at(hero.position+Vector3.UP)
  await frames();await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Attack Reach/reach-wave.png")==OK,"Capture compact pipe and extended wave")
 game.queue_free();await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("ATTACK_REACH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func allied_reuse():
 var allies=[]
 for id in [1,16,17,5,7]:
  tune(id,4)
  check(game.explorer_helpers.legendary_heroes.reinforce(id,Vector3(80+id,game.model.surface_height(80+id,75)+.15,75)),"Native ally %d joins the simultaneous presentation check"%id)
  var body=game.explorer_helpers.legendary_heroes.bodies.back();body.set_physics_process(false);body.model.set_process(false)
  if body.active_ability!=null:body.active_ability.set_process(false)
  allies.append(body)
 var node_count=0;var resource_count=0;var timings=[]
 game.forest_ui.set_process(false)
 for cycle in 10:
  for body in allies:
   if body.is_rogue_character():body.active_ability.begin_cast("primary");body.active_ability.Actions.begin_primary(body.active_ability)
   else:
    body.attack_duration=.4;body.attack_left=.3;body.combo=1
    if body.character_id==1:body.model.pipe_visual_scale=1.15*4
    else:body.active_ability.mode="primary";body.active_ability.action_id=0x68
  for frame in 18:
   var before=Time.get_ticks_usec()
   for body in allies:
    if body.is_rogue_character():
     var c=body.active_ability
     c.player.attack.time=minf(c.player.attack.duration,frame/60.0);c._animate(1.0/60,0)
    else:
     body.attack_left=maxf(.001,.4-frame/60.0)
     if body.character_id!=1:body.active_ability.elapsed=frame/60.0
     body.model.animate(1.0/60,0,true,0,body.attack_left/.4,false,1,false);body.model.sync_skeleton()
   timings.append(Time.get_ticks_usec()-before)
  for body in allies:
   body.cancel_charge()
   if body.is_rogue_character():body.active_ability.cancel();body.active_ability.fx.tick(.5)
   else:
    if body.character_id!=1:body.active_ability.mode=""
    body.model.animate(.5,0,true,0,0,false,0,false);body.model.sync_skeleton()
    var trails=[body.model.reach_trail] if body.character_id==1 else body.model.reach_trails
    check(trails.all(func(t):return t.samples.is_empty() and t.mesh==null),"Native ally %d releases its wave samples"%body.character_id)
  await frames(3)
  if cycle==4:node_count=get_node_count();resource_count=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  elif cycle>4:
   print("ATTACK_RANGE_REUSE cycle=",cycle," node_delta=",get_node_count()-node_count," resource_delta=",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resource_count)
   check(get_node_count()==node_count,"Simultaneous repeated waves retain no effect nodes")
 var trails=[]
 for body in allies:
  if body.character_id==1:trails.append(body.model.reach_trail)
  elif body.character_id in [16,17]:trails.append_array(body.model.reach_trails)
 var material_ids=trails.map(func(t):return t.material_override.get_instance_id())
 var before_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for cycle in 200:
  for trail in trails:
   trail.advance(.016,PackedVector3Array([Vector3.ZERO,Vector3(8,2,cycle%3)]),true,false)
   trail.advance(.016,PackedVector3Array([Vector3.ZERO,Vector3(7,2,cycle%3+1)]),true,false)
   trail.flush_mesh()
   trail.advance(.5,PackedVector3Array(),false,false)
 check(trails.all(func(t):return t.mesh==null and t.samples.is_empty()) and trails.map(func(t):return t.material_override.get_instance_id())==material_ids,"Eight hundred reused waves clear geometry and retain their prepared materials")
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==before_resources,"Isolated repeated wave owners retain no resources")
 timings.sort();print("ATTACK_RANGE_ALLY_PRESENTATION_US p95=",timings[int(timings.size()*.95)]," max=",timings.back())
