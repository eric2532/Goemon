extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Roster=preload("res://scripts/rogue_roster.gd")
const Gear=preload("res://scripts/forest/equipment.gd")
const OUT="res://build/Other Files/Asset Toolkit/Shin Skin Fix/"
var hit_victims=[]
var samples=[]

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(900).timeout.connect(func():printerr("SHIN_SKIN_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.impact_confirmed.connect(func(victim,_strength,_time):hit_victims.append(victim))
 var p=game.player
 var home=Vector3(-120,0,125);home.y=game.model.surface_height(home.x,home.z)+.05
 game.training_dummy.position=home+Vector3.UP*100
 var army=game.army_runtime
 check(Roster.skin_catalog(Roster.SHIN_ID).size()==25 and Roster.skin_catalog(Roster.SHIN_SPECIAL_ID).size()==23,"Gallery has 25 regular and 23 distinct special skins")
 for character in [Roster.SHIN_ID,Roster.SHIN_SPECIAL_ID]:
  p.select_character(character)
  for id in Roster.skin_catalog(character):
   # Shin 2.0 includes bows; its source-contact fixture is bei_moe_ami_test.gd.
   if character==38 and preload("res://scripts/crossgate_special_skins.gd").CAST_CATALOG[38].has(id):continue
   check(game.save_equipment_loadouts({}, {}, {}, {Roster.skin_setting(character):id}),"Save skin %d"%id)
   var kit=p.active_ability
   var model=p.model
   check(model.body_materials.size()<=model.atlases.size()+model.qi_atlas.size()+1,"Skin %d releases materials from previous appearances"%id)
   check(model.explosion==null,"Skin %d needs only its existing body sprite"%id)
   for stance in model.appearance.get("weapons",[]).size()+1:
    game.select_skin_weapon(character,stance)
    var facings={}
    if character==38 and stance==0:check(Gear.default_weapon(character,game.settings)==model.current_weapon(),"Skin %d has the same native weapon in equipment and combat"%id)
    for direction in 8:
     kit.cancel(true);p.attack_chain.reset();p.set_auto_attack(false)
     p.position=home;p.velocity=Vector3.ZERO;p.impact_pause=0
     p.facing=Vector3.FORWARD;p.combat_aim_left=0
     game.camera_rig.yaw=direction*TAU/8
     game.camera_rig.camera.global_position=home+Vector3.BACK.rotated(Vector3.UP,direction*TAU/8)*14+Vector3.UP*6
     game.camera_rig.camera.look_at(home+Vector3(0,1,-2))
     army.clear();game.model.enemies.clear();army.refresh_kits();game.model.update_vision(home)
     var distance=2.0 if model.motions.weapon=="unarmed" else 6.4 if model.motions.weapon=="polearm" else 4.8
     var at=home+Vector3.FORWARD*distance;at.y=game.model.surface_height(at.x,at.z)
     var row=game.model.waves.spawn_enemy(0,at);row.hp=1000000;row.max_hp=row.hp
     army.import_arrivals();army.sync_targets()
     var target=army.enemy_target(row.id);var before:float=target.hp
     # Lock the target while the camera views the attack from each sprite facing.
     kit.primary_tab_target=weakref(target)
     hit_victims.clear();tap("light_attack")
     kit.primary_tab_target=null
     facings[model.direction()]=true
     check(kit.is_attacking(),"Skin %d stance %d facing %d starts normal attack"%[id,stance,model.direction()])
     var rate:float=p.attack_speed_multiplier()
     kit.tick(maxf(0,kit.shin_contact-.0001)/rate)
     check(target.hp==before,"Skin %d preserves contact windup"%id)
     kit.tick(.0002/rate);model.animate(0,0,true,0,0,false,0,false)
     check(target.hp<before and hit_victims==[target],"Skin %d stance %d facing %d hits native enemy once at %.1f m"%[id,stance,model.direction(),distance])
     if character==Roster.SHIN_SPECIAL_ID and stance==0 and direction==4:await picture("contact-%d"%id)
     kit.tick(kit.duration/rate+.01)
     check(hit_victims==[target] and not kit.is_attacking(),"Skin %d has no duplicate recovery hit"%id)
    check(facings.size()==8,"Skin %d stance %d checks all eight sprite facings"%[id,stance])
   if character==Roster.SHIN_SPECIAL_ID:
    game.select_skin_weapon(character,0)
    # Inspect the full recovered swing in motion and at five rendered poses.
    p.facing=Vector3.FORWARD;model.rotation.y=0
    game.camera_rig.camera.global_position=home+Vector3(-7,5,-9)
    game.camera_rig.camera.look_at(home+Vector3(0,1,-1))
    var motion:Dictionary=model.motions.clips["5:%d"%model.direction()]
    for frame in motion.frames.size():
     model.show_frame(5,"5:%d"%model.direction(),frame)
     if DisplayServer.get_name()!="headless":await create_timer(float(motion.duration)/motion.frames.size()).timeout
     if frame in [0,floori(motion.frames.size()/4.0),floori(motion.frames.size()/2.0),floori(motion.frames.size()*3/4.0),motion.frames.size()-1]:await picture("swing-%d-%02d"%[id,frame])
    model.show_pose(0,0,true)
   await frames()
 # Old saved Classic appearances and their per-skin records remain readable.
 p.select_character(Roster.SHIN_SPECIAL_ID)
 for id in Roster.ShinSkins.HIDDEN_CLASSIC:
  check(not Roster.skin_catalog(Roster.SHIN_SPECIAL_ID).has(id),"Classic %d is hidden from the gallery"%id)
  game.settings.shin_special_skin=id
  game.settings.skin_equipment["38:%d"%id]={"weapon":0}
  game.settings.spell_loadouts=game.settings.spell_loadouts.duplicate(true)
  game.settings.spell_loadouts["38:%d"%id]={"special_5":"kazi/combo"}
  game.save_settings();game.load_settings()
  check(p.model.shin_skin==id and Roster.selected_skin(38,game.settings)==id and game.settings.skin_equipment.has("38:%d"%id) and game.settings.spell_loadouts.get("38:%d"%id,{}).get("special_5")=="kazi/combo","Classic %d retains its saved model and loadout"%id)
  game.show_equipment_hub(true);await frames()
  var picker=game.equipment_hub.portrait_button
  picker.open_gallery();await frames()
  check(picker.choices.item_count==23,"An old Classic save opens the expanded gallery safely")
  picker.gallery.hide();await frames();game.back_from_equipment()
 # Five simultaneous copies of every Special appearance use the native owner.
 for id in Roster.skin_catalog(38):
  if preload("res://scripts/crossgate_special_skins.gd").CAST_CATALOG[38].has(id):continue
  game.select_shin_skin(38,id);game.select_skin_weapon(38,0)
  army.clear();game.model.enemies.clear();army.refresh_kits()
  var dummy=game.training_dummy
  dummy.position=home+Vector3.FORWARD*2;dummy.home=dummy.position
  game.sync_training_dummy();game.model.update_vision(home)
  var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
  hit_victims.clear()
  for i in 5:
   check(mirrors.reinforce(38,home+Vector3((i-2)*.2,0,0)),"Skin %d allocates native ally %d"%[id,i])
   var body=mirrors.bodies[i]
   check(body.model.shin_skin==id and body.model.atlases[0]==p.model.atlases[0],"Skin %d allies share the selected prepared atlas"%id)
   check(body.perform(0,dummy.position),"Skin %d ally %d starts its normal attack"%[id,i])
  for tick in 100:
   for body in mirrors.bodies:body.step(1.0/60,{"position":body.position,"hp":body.max_hp,"yaw":0.0,"pose_velocity":Vector3.ZERO})
  print("SHIN_ALLY_CONTACTS skin=",id," hits=",hit_victims.count(dummy)," active=",mirrors.bodies.map(func(body):return body.has_offensive_action()))
  check(hit_victims.count(dummy)==5 and mirrors.bodies.all(func(body):return not body.has_offensive_action()),"Five simultaneous skin %d allies land one normal hit each"%id)
  mirrors.dispose();await frames(3)
 game.training_dummy.position=home+Vector3.UP*100
 # Repeated native attacks keep the existing warmed resources.
 game.select_shin_skin(38,Roster.ShinSkins.SPECIAL_DEFAULT)
 var kit=p.active_ability
 kit.start_attack();kit.tick(kit.duration/p.attack_speed_multiplier()+.01);await frames()
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 30:
  var start=Time.get_ticks_usec()
  kit.start_attack();kit.tick(kit.duration/p.attack_speed_multiplier()+.01)
  samples.append(Time.get_ticks_usec()-start)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Thirty repeated special attacks retain no additional nodes/resources")
 samples.sort();print("SHIN_ATTACK_DIAGNOSTIC_US p95=",samples[int(samples.size()*.95)]," max=",samples[-1])
 var path=game.settings_path
 game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("SHIN_SKIN_ATTACKS_RESULT checks=%d failures=%d"%[checks,failures])
 quit(1 if failures else 0)
