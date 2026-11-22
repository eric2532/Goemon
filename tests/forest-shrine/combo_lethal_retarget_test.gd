extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const OUT="res://build/Other Files/Combo Retarget/"
const DT=1.0/60
var driver
var home=Vector3(-120,0,125)
var impacts:Array[int]=[]
var samples:Array[int]=[]

func advance(_delta:float):
 var started=Time.get_ticks_usec()
 game.player._physics_process(DT)
 game.crowd.army.presentation.tick(DT)
 samples.append(Time.get_ticks_usec()-started)

func press():
 var event=InputEventKey.new();event.physical_keycode=KEY_2;event.pressed=true
 game.player._unhandled_input(event)
 event.pressed=false;game.player._input(event)

func bog_farther_search(shared:bool=false):
 var p=game.player;var army=game.army_runtime
 p.select_character(Catalog.Roster.BOG_ID)
 game.reset_character_tuning(Catalog.Roster.KAZI_ID)
 game.reset_character_tuning(p.character_id)
 game.update_character_tuning(p.character_id,"critical_chance",0)
 for skin in [100625,100942]:
  game.select_crossgate_skin(p.character_id,skin)
  check(p.spell_loadout.equip(p.character_id,"surge",Catalog.COMBO if shared else ""),"Bog selects %s 連擊"%("shared" if shared else "original"))
  await frames(2)
  var kit=p.spell_loadout.instances["%d:%s"%[p.character_id,Catalog.COMBO]].controller if shared else p.active_ability
  for blocked in [false,true]:
   fresh();kit.clear_cooldowns();army.clear();army.refresh_kits()
   var origin=home
   p.position=origin;p.velocity=Vector3.ZERO;p.impact_pause=0;game.hit_stop=0
   await driver.advance(20,advance)
   var targets:Array[int]=[]
   for distance in [4,24,60]:
    var point=origin+Vector3.LEFT*distance
    point.y=game.model.surface_height(point.x,point.z)
    var row=game.model.waves.spawn_enemy(0,point)
    row.hp=1;row.max_hp=1;army.import_arrivals();targets.append(row.id)
   army.sync_targets();game.crowd.present_army(army.render_snapshot(),[])
   check(targets.slice(0,2).all(func(id):return not kit.next_combo_hop({},32,army.enemy_target(id)).is_empty()),"Both extended-range targets have valid landings and no solid cover")
   var wall:StaticBody3D
   if blocked:
    wall=StaticBody3D.new()
    var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.35,8,24)
    shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=home+Vector3(-14,2,0)
    await physics_frame;await physics_frame
   impacts.clear();var kills:int=game.kills
   press()
   check(kit.is_attacking() and is_equal_approx(kit.ticket.combo_splash_radius,5.4),"Bog %d preserves his %s slime-sized splash baseline"%[skin,"shared" if shared else "original"])
   var origins:Array[Vector3]=[]
   var seen_strikes=0
   var captured_next=false
   for frame in 300:
    await driver.advance(1,advance)
    if kit.combo_strikes>seen_strikes:
     seen_strikes=kit.combo_strikes;origins.append(p.global_position)
    if not blocked and not captured_next and impacts.size()>=2:
     captured_next=true
     if DisplayServer.get_name()!="headless":
      game.camera_rig.camera.global_position=origin+Vector3(-14,16,30);game.camera_rig.camera.look_at(origin+Vector3(-14,1,0))
      game.forest_ui.sync();await RenderingServer.frame_post_draw
      check(root.get_texture().get_image().save_png(OUT+"bog-%d-%s-extended-contact.png"%[skin,str(shared)])==OK,"Captured Bog's farther second contact")
    if not kit.is_attacking():break
   var expected=1 if blocked else 2
   print("BOG_EXTENDED skin=",skin," shared=",shared," blocked=",blocked," strikes=",kit.combo_strikes," impacts=",impacts," landings=",origins)
   check(impacts.size()==expected and game.kills-kills==expected,"Bog %d %s (%d lethal contacts)"%[skin,"respects cover at extended range" if blocked else "continues to the target twenty metres away",impacts.size()])
   check(impacts.all(func(target):return targets.has(target) and impacts.count(target)==1),"Farther searches never hit a dead target again")
   check(not kit.is_attacking() and kit.combo_cooldown>0 and kit.combo_strikes==expected,"Bog finishes cleanly and retains cooldown")
   check(not army.enemy_target(targets.back()).dead,"The enemy beyond 32 metres survives")
   if not blocked:
    check(origins.size()==2 and origins[0].distance_to(origins[1])>10,"Bog actually blinks farther than the old search range")
   if wall!=null:wall.free();await physics_frame;await physics_frame

func all_character_farther_search():
 var p=game.player;var army=game.army_runtime
 for id in Catalog.Roster.CROSSGATE:
  p.select_character(id);fresh();army.clear();army.refresh_kits()
  check(p.spell_loadout.equip(id,"surge",Catalog.COMBO),"Fighter %d equips the shared combo"%id)
  await frames(2)
  p.position=home;p.velocity=Vector3.ZERO;p.impact_pause=0;game.hit_stop=0
  if id in [27,29]:p._clear_large_character_spawn()
  await driver.advance(20,advance)
  var origin:Vector3=p.global_position
  var kit=p.active_ability if id==Catalog.Roster.KAZI_ID else p.spell_loadout.instances["%d:%s"%[id,Catalog.COMBO]].controller
  kit.clear_cooldowns()
  var targets:Array[int]=[]
  var reachable=false
  for sector in 8:
   army.clear();army.refresh_kits();targets.clear()
   var direction=Vector3.LEFT.rotated(Vector3.UP,sector*TAU/8)
   for distance in [4,24]:
    var point=origin+direction*distance;point.y=game.model.surface_height(point.x,point.z)
    var row=game.model.waves.spawn_enemy(0,point)
    row.hp=1;row.max_hp=1;army.import_arrivals();targets.append(row.id)
   army.sync_targets()
   var first=kit.next_combo_hop({},32,army.enemy_target(targets[0]))
   if first.is_empty():continue
   p.global_position=first.position
   reachable=not kit.next_combo_hop({},32,army.enemy_target(targets[1])).is_empty()
   p.global_position=origin
   if reachable:break
  check(reachable,"Fighter %d has a safe lane for both hops with his actual body footprint"%id)
  game.crowd.present_army(army.render_snapshot(),[])
  impacts.clear();press()
  check(kit.is_attacking(),"Fighter %d starts with a fresh test cooldown"%id)
  for frame in 650:
   await driver.advance(1,advance)
   if not kit.is_attacking():break
  check(impacts.size()==2 and targets.all(func(target):return impacts.count(target)==1),"Fighter %d retargets across the same 20-metre gap after a kill"%id)
  check(not kit.is_attacking() and kit.combo_cooldown>0,"Fighter %d finishes with cooldown intact"%id)
  print("COMBO_ROSTER_PROGRESS fighter=",id," strikes=",kit.combo_strikes," impacts=",impacts," origin=",origin," velocity=",p.velocity)

func run():
 create_timer(300).timeout.connect(func():printerr("COMBO_RETARGET_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 for node in [game,game.player,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 var p=game.player;var army=game.army_runtime
 home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*100
 game.settings.disable_character_cooldowns=false
 game.impact_confirmed.connect(func(victim,_strength,_duration):impacts.append(victim.forest_id))
 for id in [Catalog.Roster.KAZI_ID,Catalog.Roster.SHIN_ID,Catalog.Roster.BOG_ID,35]:
  p.select_character(id);fresh();army.clear();army.refresh_kits()
  if id==35:check(p.spell_loadout.equip(id,"surge",Catalog.COMBO),"Uru equips shared 連擊")
  # Isolate primary retargeting; splash behavior has its own regression suite.
  game.update_character_tuning(Catalog.Roster.KAZI_ID if id==35 else id,"combo_splash_radius",0)
  game.update_character_tuning(id,"critical_chance",0)
  p.position=home;p.velocity=Vector3.ZERO;p.impact_pause=0;game.hit_stop=0
  await driver.advance(20,advance)
  check(p.is_on_floor(),"Fighter %d starts grounded"%id)
  var targets:Array[int]=[]
  for i in 9:
   var point=home+Vector3(sin(i*TAU/9),0,cos(i*TAU/9))*4
   point.y=game.model.surface_height(point.x,point.z)
   var row=game.model.waves.spawn_enemy(0,point)
   row.hp=1;row.max_hp=1;army.import_arrivals();targets.append(row.id)
  army.sync_targets();game.crowd.present_army(army.render_snapshot(),[])
  impacts.clear();var kills:int=game.kills
  press()
  var kit=p.active_ability if id!=35 else p.spell_loadout.current.controller
  check(kit.is_attacking(),"Fighter %d starts 連擊 through key 2"%id)
  game.camera_rig.camera.global_position=home+Vector3(9,9,15)
  game.camera_rig.camera.look_at(home+Vector3.UP)
  var captured_next=false
  for frame in 650:
   await driver.advance(1,advance)
   if not captured_next and impacts.size()>=2:
    captured_next=true
    check(kit.is_attacking() and kit.combo_strikes>=2,"Fighter %d continues after its first lethal hit"%id)
    if DisplayServer.get_name()!="headless":
     game.forest_ui.sync();await RenderingServer.frame_post_draw
     check(root.get_texture().get_image().save_png(OUT+"fighter-%d-next-target.png"%id)==OK,"Captured fighter %d retargeting"%id)
   if not kit.is_attacking():break
  var count_=7 if id in [Catalog.Roster.SHIN_ID,Catalog.Roster.BOG_ID] else 8
  check(impacts.size()==count_ and impacts.all(func(target):return targets.has(target) and impacts.count(target)==1),"Fighter %d hits %d distinct targets despite every hit killing"%[id,count_])
  check(game.kills-kills==count_,"Fighter %d delivers every native death exactly once"%id)
  check(not kit.is_attacking() and kit.combo_cooldown>0,"Fighter %d ends at its strike limit and keeps cooldown"%id)
  press()
  check(not kit.is_attacking(),"Fighter %d cannot bypass cooldown after kills"%id)
  game.reset_character_tuning(id)
 await bog_farther_search()
 await bog_farther_search(true)
 await all_character_farther_search()
 samples.sort()
 print("COMBO_RETARGET_PLAYER_STEP_US p95=",samples[floori(samples.size()*.95)]," max=",samples.back())
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("COMBO_LETHAL_RETARGET_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
