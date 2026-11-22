extends "res://tests/forest-shrine/weapon_equipment_test.gd"
## The cosmetic follows real source contacts and never owns damage or targeting.
const WIND_OUT="res://build/Other Files/Asset Toolkit/Cross Gate Melee Wind/"
var wind_rows=[]
var wind_samples=[]
var wind_baseline_samples=[]
var motion_inventory=[]
var capture_label=""

func record_motion(character:int,weapon:String):
 if weapon in ["bow","kunai"]:return
 var visual=game.player.model;var camera=game.camera_rig.camera
 var clips=[]
 for direction in 8:
  var heading=camera.global_basis.x*sin((direction-1)*TAU/8)-camera.global_basis.z*cos((direction-1)*TAU/8);heading.y=0
  var pattern=visual.normal_attack_pattern(heading.normalized())
  var clip:Dictionary=visual.body_clip(5,"5:%d"%direction)
  clips.append({"frames":clip.frames,"duration":pattern.duration,"contacts":pattern.contacts,"wind_source":clip.get("wind_source",""),"wind_motions":clip.get("wind_motions",[])})
 motion_inventory.append({"character":character,"weapon":weapon,"key":visual.motions.get("key",visual.appearance.get("key","")),"source_id":visual.motions.get("source_id",visual.appearance.get("id",0)),"root":visual.gear_route.get("root",visual.native_root),"atlases":visual.atlases.map(func(atlas):return atlas.resource_path),"body_pixels":visual.body_height_pixels,"clips":clips})

func wind_records()->Array:
 return game.crowd.army.presentation.effects.filter(func(effect):return effect.kind=="melee-wind")

func wind_range(multiplier:float):
 var p=game.player
 p.accessory_bonuses.erase("range")
 if multiplier!=1:p.accessory_bonuses.range=multiplier

func wind_attack(direction:Vector3=Vector3.FORWARD):
 var p=game.player;var kit=p.active_ability
 kit.cancel(true);p.attack_chain.reset();game.crowd.army.presentation.clear()
 p.position=home;p.velocity=Vector3.ZERO;p.ai_controlled=true;p.ai_aim=home+direction*100
 kit.start_attack()
 return p.model.normal_attack_pattern().duplicate(true)

func contact_case(character:int,weapon:String,multiplier:float,direction:int):
 var p=game.player;var fx=game.crowd.army.presentation
 wind_range(multiplier)
 var heading=Vector3.FORWARD.rotated(Vector3.UP,direction*PI/4)
 var pattern=wind_attack(heading);var kit=p.active_ability
 var rate=p.attack_speed_multiplier()
 if weapon in ["bow","kunai"]:
  kit.tick(float(pattern.duration)/rate+.001)
  check(wind_records().is_empty(),"Ranged attacks do not display a melee wind area")
  return
 var contact:float=pattern.contacts[0]
 if contact>.001:kit.tick((contact-.001)/rate)
 check(wind_records().is_empty(),"Wind waits for the original melee contact")
 var camera=game.camera_rig.camera
 var clip:Dictionary=p.model.body_clip(5,"5:%d"%p.model.direction())
 check(weapon=="unarmed" or not clip.get("wind_motions",[]).is_empty(),"The selected weapon has a reviewed source motion")
 var record:Dictionary={}
 for index in pattern.contacts.size():
  kit.tick((float(pattern.contacts[index])+.001-kit.elapsed)/rate)
  var records=wind_records()
  check(records.size()==index+1,"Each original contact emits one bounded wind record")
  if records.is_empty():return
  record=records.back()
  var expected:String=p.model.melee_wind_motion(index)
  check(record.motion==expected,"Wind follows the reviewed contact sequence %d/%s/%d"%[character,weapon,index])
  if record.style in [3,8]:
   check(record.cut==(1 if expected in ["arc_up","up"] else -1),"Slash follows the reviewed rising or falling contact")
   check(record.style==(8 if weapon=="axe" else 3),"Axe uses the heavier approved crescent")
   check((record.pose.origin-record.position).dot(heading)<=p.model.standing_height()*.25+.005,"The slash remains rooted near the weapon when reach grows")
   var projected=sqrt(maxf(0.0,1.0-record.padding*record.padding))
   var direction_=record.pose.basis.x.normalized()*projected+record.pose.basis.z.normalized()*record.padding
   var front:Vector3=record.pose*Vector3(projected,0,record.pose.basis.x.length()*record.padding)
   check(direction_.dot(heading)>.999 and absf((front-record.position).dot(heading)-p.melee_strike_reach())<.005,"The slash outer edge follows the world attack direction and real reach")
  elif record.style in [5,7,9]:
   check(record.style==(5 if weapon=="unarmed" or expected=="push" else 7 if expected=="thrust" else 9),"Staff pounces, blunt chops and punches retain their approved shapes")
   check(record.pose.basis.x.length()>.1,"The blunt gust retains a visible rounded width")
   var start=.25 if record.style==7 else .10
   var cap=.62/2.2 if record.style==7 else .18
   var speed=2.0 if record.style==7 else 1.9
   for phase in [0.0,.25,.60,1.0]:
    var travel=minf(phase*speed,1.0)
    var crest=(lerpf(start,.95,travel)+cap+.30)*2.0/1.65-1.0
    var front:Vector3
    if record.style==9:
     front=record.pose*Vector3(0,crest-travel*2.0*(.95-start)/1.65,travel)
    else:
     var depth_direction:float=record.arc*2.0-1.0
     var screen_direction=sqrt(maxf(0.0,1.0-depth_direction*depth_direction))
     front=record.pose*Vector3(0,crest+travel*(record.padding*screen_direction-2.0*(.95-start)/1.65),travel*record.padding*record.pose.basis.y.length()*depth_direction)
     check(absf(front.y-record.position.y-p.model.standing_height()*.45)<.005,"The forward gust stays at weapon height throughout travel")
    check(absf((front-record.position).dot(heading)-p.melee_strike_reach()*travel)<.005,"The rounded leading front reaches the actual hit boundary without overshooting")
   if record.style==9:
    check(signf(record.pose.basis.y.normalized().dot(camera.global_basis.y))==(1.0 if expected=="up" else -1.0),"Blunt staff wind follows the actual upward or downward swing")
   else:check(record.pose.basis.z.normalized().dot(camera.global_basis.z)>.999,"The rounded gust remains readable from the sprite's camera")
  elif expected=="puff":
   check(record.style==1,"Unknown future source poses retain the neutral fallback")
  elif record.style==0:
   var projected=sqrt(maxf(0.0,1.0-record.padding*record.padding))
   var direction_=record.pose.basis.y.normalized()*projected+record.pose.basis.z.normalized()*record.padding
   var front:Vector3=record.pose*Vector3(0,projected,record.pose.basis.y.length()*record.padding)
   check(expected in ["thrust","release"] and direction_.dot(heading)>.999,"Reviewed thrusts and releases have a straight source-textured stroke")
   check(absf((front-record.position).dot(heading)-p.melee_strike_reach())<.005,"The piercing stroke extends to the actual hit boundary")
  else:
   var front:Vector3=record.pose*Vector3(0,1,0)
   check(record.style==2 and record.pose.basis.y.normalized().dot(heading)>.999,"Only reviewed side sweeps and spins use a horizontal slash")
   check(absf((front-record.position).dot(heading)-p.melee_strike_reach())<.005,"The side slash clearly extends to the actual hit boundary")
 check(p.active_ability.wind_contact==pattern.contacts.size(),"Contact motion indices reset with each new attack")
 fx.draw_effects()
 var batch:MultiMeshInstance3D=fx.batches["melee-wind"]
 check(batch.multimesh.visible_instance_count==wind_records().size(),"Each contact uses the existing batched presentation")
 wind_rows.append({"character":character,"weapon":weapon,"range":multiplier,"facing":direction,"style":record.style,"motion":record.motion,"source":clip.get("wind_source",""),"width":record.pose.basis.x.length()*2})
 kit.cancel(true)

func width_growth_case():
 var p=game.player;var normal_width=0.0
 for multiplier in [1.0,3.0,6.0]:
  wind_range(multiplier)
  var pattern=wind_attack()
  p.active_ability.tick((float(pattern.contacts[0])+.001)/p.attack_speed_multiplier())
  var record:Dictionary=wind_records()[0]
  var width:float=record.pose.basis.y.length() if record.style in [3,8] else record.pose.basis.x.length()
  if multiplier==1:normal_width=width
  else:
   check(width>=normal_width-.005,"Increasing range does not make the wind narrower than its normal attack")
   check(width/normal_width<(2.0 if multiplier==3 else 2.5),"Increased range extends forward without a proportionally wide effect")
 p.active_ability.cancel(true)

func damage_case():
 var p=game.player;var kit=p.active_ability;var army=game.army_runtime;var fx=game.crowd.army.presentation
 army.clear();game.model.enemies.clear();army.refresh_kits()
 wind_range(2)
 var reach=p.melee_strike_reach()
 var near=spawn(Vector3.FORWARD*(reach-.10))
 var far=spawn(Vector3.FORWARD*(reach+8))
 var hp:float=near.hp;var outside:float=far.hp
 var pattern=wind_attack();var rate=p.attack_speed_multiplier()
 if float(pattern.contacts[0])>.001:kit.tick((float(pattern.contacts[0])-.001)/rate)
 check(near.hp==hp,"The wind adds no damage before source contact")
 kit.tick((float(pattern.duration)-kit.elapsed+.001)/rate)
 var expected=Skills.basic_damage(pattern)*pattern.contacts.size()*p.damage_multiplier()
 check(is_equal_approx(hp-near.hp,expected) and far.hp==outside,"Visual wind preserves exact contact damage and misses outside reach")
 var after:float=near.hp
 fx.tick(1)
 check(wind_records().is_empty() and near.hp==after,"Fading wind never applies a later hit")
 army.clear();game.model.enemies.clear();army.refresh_kits()

func wind_picture(character:int,weapon:String,multiplier:float,heading:Vector3=Vector3.FORWARD):
 if DisplayServer.get_name()=="headless":return
 var p=game.player;var fx=game.crowd.army.presentation
 wind_range(multiplier)
 var height:float=p.model.standing_height()
 var focus=home+Vector3.FORWARD*height*.5
 var framing=1.0
 var reach:float=p.melee_strike_reach()
 focus=home+heading*reach*.40
 framing=maxf(1.0,reach/(height*2.0))
 game.camera_rig.camera.global_position=focus+Vector3(height*2.4,height*2.0,height*3.6)*framing
 game.camera_rig.camera.look_at(focus+Vector3.UP*height*.45)
 var pattern=wind_attack(heading);var kit=p.active_ability;var rate=p.attack_speed_multiplier()
 var times=[]
 for contact in pattern.contacts:
  for tail in [.035,.080,.150]:times.append(float(contact)/rate+tail)
 times.sort()
 var board=Image.create(1280*3,800*ceili(times.size()/3.0),false,Image.FORMAT_RGBA8)
 var clock_=0.0
 for i in times.size():
  while clock_<times[i]-.00001:
   var step=minf(DT,times[i]-clock_)
   kit.tick(step);p.model.animate(step,0,true,0,0,false,0,false);fx.tick(step);clock_+=step
  fx.draw_effects()
  await frames(2);await RenderingServer.frame_post_draw
  var shot=root.get_texture().get_image();shot.convert(Image.FORMAT_RGBA8)
  if i==1:shot.save_png(WIND_OUT+capture_label+"swing-%d-%s-x%d.png"%[character,weapon,int(multiplier)])
  board.blit_rect(shot,Rect2i(0,0,1280,800),Vector2i((i%3)*1280,(i/3)*800))
 check(board.save_png(WIND_OUT+capture_label+"sequence-%d-%s-x%d.png"%[character,weapon,int(multiplier)])==OK,"Captured the wind and original attack in motion")
 kit.cancel(true);fx.clear()

func native_reuse():
 var p=game.player;var fx=game.crowd.army.presentation
 wind_range(1)
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 5:check(mirrors.reinforce(p.character_id,home+Vector3.RIGHT*(i-2)*5),"Wind uses the existing native ally lifecycle")
 var nodes=0;var resources=0
 var peak=0
 var directions={}
 for cycle in 48:
  fx.effect_capacity=0 if cycle<24 else fx.MAX_EFFECTS
  fx.clear()
  for body in mirrors.bodies:
   body.active_ability.cancel(true);body.attack_chain.reset();body.ai_aim=body.position+Vector3.FORWARD*20;body.active_ability.start_attack()
  var lead:Hero=mirrors.bodies[0]
  var ticks=ceili((float(lead.model.normal_attack_pattern().duration)/lead.attack_speed_multiplier()+maxf(.28,fx.PUNCH_WIND_LIFE)+.02)/DT)
  for tick in ticks:
   var started=Time.get_ticks_usec()
   for body in mirrors.bodies:
    body.active_ability.tick(DT);body.model.animate(DT,0,true,0,0,false,0,false)
   fx.tick(DT)
   var elapsed_ms=(Time.get_ticks_usec()-started)/1000.0
   peak=maxi(peak,wind_records().size())
   for effect in wind_records():
    if effect.style==3:directions[effect.cut]=true
   if cycle>=26:wind_samples.append(elapsed_ms)
   elif cycle>=2 and cycle<24:wind_baseline_samples.append(elapsed_ms)
  if cycle==1:
   await frames(3);nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 await frames(3)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated simultaneous native swings retain no warmed nodes or resources")
 check(peak>=5,"All five native copies display their actual simultaneous melee contacts")
 if p.model.fighter.strike=="cuts" and p.model.normal_attack_pattern().contacts.size()>1:
  check(directions.has(1) and directions.has(-1),"Native paired sword copies render both rising and falling strokes")
 check(wind_records().is_empty(),"All native wind effects retire through the existing effect owner")
 fx.effect_capacity=0
 var body=mirrors.bodies[0];body.active_ability.cancel(true);body.active_ability.start_attack()
 body.active_ability.tick(float(body.model.normal_attack_pattern().duration)/body.attack_speed_multiplier()+.01)
 check(wind_records().is_empty() and not body.active_ability.is_attacking(),"A full cosmetic pool cannot interrupt or extend combat")
 fx.effect_capacity=fx.MAX_EFFECTS;mirrors.dispose();await frames(3)

func setup_wind():
 var presets=ConfigFile.new()
 check(presets.load("res://export_presets.cfg")==OK,"Export presets remain readable")
 for section in presets.get_sections():
  if section.begins_with("preset.") and not section.ends_with(".options"):
   check(str(presets.get_value(section,"include_filter","")).contains("assets/characters/crossgate/weapons/wind-motion-cues.json"),"Every export includes the reviewed skin motion table")
 create_timer(1800).timeout.connect(func():printerr("MELEE_WIND_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(WIND_OUT);root.size=Vector2i(1280,800);root.gui_disable_input=true
 if DisplayServer.get_name()!="headless":
  root.mode=Window.MODE_WINDOWED;root.set_flag(Window.FLAG_ALWAYS_ON_TOP,true);root.grab_focus()
 cfg="user://crossgate-melee-wind-%d.cfg"%OS.get_process_id()
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 for node in [game,game.player,game.camera_rig]:node.set_process_input(false);node.set_process_unhandled_input(false)
 game.settings.forest_pet_loadout=[];game.settings.gear_loadouts={};game.settings.disable_character_cooldowns=false
 game.begin_arena();game.choose_rogue_character(34);await frames(3);game.equipment_hub.enter_map();await frames(3)
 game.clear_menu();game.forest_ui.hide();game.playing=true;game.paused=false;paused=false
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;game.model.update_vision(home);game.army_runtime.refresh_kits()
 if is_instance_valid(game.training_dummy):game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):shot.set_physics_process(false);shot.retire())

func run():
 await setup_wind()
 var p=game.player;var fx=game.crowd.army.presentation
 for character in Gear.Roster.CROSSGATE:
  p.ai_controlled=false
  p.select_character(character);game.update_character_tuning(character,"critical_chance",0)
  if character==Gear.Roster.MAZE_ID:choose_skin(character,0)
  for weapon in Gear.allowed(character,game.settings):
   p.ai_controlled=false
   equip_weapon(character,weapon)
   check(p.model.current_weapon()==weapon,"The fixture uses the actual selected weapon")
   record_motion(character,weapon)
   for multiplier in [1.0,2.0,6.0]:
    for direction in 8:contact_case(character,weapon,multiplier,direction)
   if weapon not in ["bow","kunai"]:
    width_growth_case();damage_case();await wind_picture(character,weapon,1)
 var unknown_clip:Dictionary=p.model.body_clip(5,"5:%d"%p.model.direction())
 var reviewed_motion:Array=unknown_clip.wind_motions
 unknown_clip.wind_motions=[]
 check(p.model.melee_wind_motion(0)=="puff","Unreviewed source poses use a neutral accent instead of a guessed slash")
 unknown_clip.wind_motions=reviewed_motion
 p.ai_controlled=false;p.select_character(34)
 for multiplier in [1.0,2.0,6.0]:await wind_picture(34,"sword",multiplier)
 p.ai_controlled=false;choose_skin(34,109890);await wind_picture(34,"rose-sword",2)
 await native_reuse()
 for motion_case in [[35,"sword"],[43,"axe"],[40,"staff"],[46,"sword"]]:
  p.ai_controlled=false;p.select_character(motion_case[0]);equip_weapon(p.character_id,motion_case[1]);await native_reuse()
 p.ai_controlled=false;p.select_character(Gear.Roster.SHIN_ID)
 for weapon in ["sword","polearm","unarmed","axe","staff"]:
  p.ai_controlled=false
  equip_weapon(p.character_id,weapon)
  for multiplier in [1.0,6.0]:await wind_picture(p.character_id,weapon,multiplier)
 for weapon in ["sword","unarmed","staff"]:
  p.ai_controlled=false;equip_weapon(p.character_id,weapon);await native_reuse()
 var sample=fx.add_effect("melee-wind",home,1,1)
 sample.pose=Transform3D.IDENTITY;sample.padding=.1;sample.arc=0;sample.style=0
 var age:float=sample.age;game.paused=true;fx.tick(.1)
 check(sample.age==age,"Pause freezes the wind with the existing combat presentation")
 game.paused=false;fx.clear();fx.draw_effects()
 check(fx.batches["melee-wind"].multimesh.visible_instance_count==0,"Clear removes every visible wind instance")
 var metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
 var report={"checks":checks,"failures":failures,"renderer":DisplayServer.get_name(),"contacts":wind_rows,"isolated_five_copy_step_ms":metrics.summary(wind_samples),"isolated_five_copy_without_wind_ms":metrics.summary(wind_baseline_samples)}
 FileAccess.open(WIND_OUT+("headless" if DisplayServer.get_name()=="headless" else "desktop")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 FileAccess.open(WIND_OUT+"motion-inventory.json",FileAccess.WRITE).store_string(JSON.stringify(motion_inventory))
 print("MELEE_WIND_RESULT checks=%d failures=%d cases=%d step_ms=%s"%[checks,failures,wind_rows.size(),report.isolated_five_copy_step_ms])
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
