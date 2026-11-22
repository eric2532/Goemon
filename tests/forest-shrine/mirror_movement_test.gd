extends "res://tests/forest-shrine/crossgate_blast_coverage_test.gd"
const EVIDENCE="res://build/Other Files/Asset Toolkit/Mirror Movement/"
var mirrors
var steps=0
func tick_army(dt:float):
 var army=game.army_runtime
 if army.begin_integration(dt,true):army.finish_integration()
 else:army.integration_tick(dt)
 steps+=1
func picture(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 game.camera_rig.camera.global_position=home+Vector3(12,20,25)
 game.camera_rig.camera.look_at(home)
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(EVIDENCE+name_+".png")==OK,"Captured "+name_)
func run():
 create_timer(600).timeout.connect(func():printerr("MIRROR_MOVEMENT_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(EVIDENCE)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime
 game.set_process(false);army.set_process(false);army.set_physics_process(false)
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 game.training_dummy.position=home+Vector3.DOWN*1000
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.world_height(home.x,home.z)+.05
 game.model.update_vision(home/game.model.falan_scale)
 for id in p.RogueRoster.CROSSGATE:
  p.select_character(id);fresh();p.position=home;p.velocity=Vector3.ZERO
  check(p.spell_loadout.equip(id,"special_4",Skills.Catalog.BEE_FLURRY),"Fighter %d equips Bee Flurry"%id)
  check(Skills.set_level(p,"blademaster/mirror-image",30 if id==34 else 1),"Fighter %d prepares the requested copy count"%id)
  check(p.spell_loadout.equip(id,"special_5","blademaster/mirror-image"),"Fighter %d equips Mirror Image"%id)
  await driver.advance(3,func(dt):p._physics_process(dt))
  mirrors=p.spell_loadout.instances["%d:blademaster/mirror-image"%id].controller.mirrors
  check(mirrors.bodies.all(func(body):return body.spell_loadout.instances["%d:%s"%[id,Skills.Catalog.BEE_FLURRY]].source_model.combo_glow!=null),"Every copy prepares its borrowed charge visual")
  if not mirrors.bodies.all(func(body):return body.spell_loadout.instances["%d:%s"%[id,Skills.Catalog.BEE_FLURRY]].source_model.combo_glow!=null):
   game.queue_free();paused=false;await frames();DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1);return
  var pooled_bodies=mirrors.bodies.duplicate()
  for cycle in (3 if id==34 else 1):
   army.clear();game.model.enemies.clear();army.refresh_kits()
   p.position=home
   check(mirrors.cast(),"Repeated native mirror summon %d"%cycle)
   if id==34:check(mirrors.handles.size()==9,"Kaz runs all nine maximum-level copies")
   var handles=mirrors.handles.duplicate()
   await driver.advance(12,tick_army)
   var enemy=spawn(Vector3.ZERO)
   army.apply_hit(enemy.handle,{"element":"ice","status_seconds":100.0})
   check(game.forest_enemy_visible(enemy),"The target is visible to copied skills")
   for body in mirrors.bodies.slice(0,mirrors.handles.size()):
    var index=body.actions.map(func(slot):return slot[1]).find("special_4")
    check(index>=2,"Copy retains equipped Bee Flurry")
    body.ai_target=enemy
    check(body.is_on_floor(),"Copy settles on actual ground before its charge")
    check(body.perform(index,enemy.position+Vector3.UP) and body.spell_loadout.current!=null and body.spell_loadout.current.controller.clip=="6","Copy begins its actual borrowed charge")
   await driver.advance(90,tick_army)
   check(mirrors.bodies.slice(0,mirrors.handles.size()).all(func(body):return body.spell_loadout.instances["%d:%s"%[id,Skills.Catalog.BEE_FLURRY]].controller.clip!="6"),"Every borrowed charge advances to its strikes")
   if id==34:await picture("kaz-copy-combat-%d"%cycle)
   army.despawn(enemy.handle);army.sync_compatibility()
   await driver.advance(150,tick_army)
   check(mirrors.bodies.slice(0,handles.size()).all(func(body):return not body.has_offensive_action()),"All copies release their attack state after the target disappears")
   var starts=mirrors.bodies.slice(0,handles.size()).map(func(body):return body.position)
   p.position=home+Vector3.RIGHT*30
   await driver.advance(120,tick_army)
   check(mirrors.handles==handles and handles.all(func(handle):return army.valid(handle)),"The original copies survive the combat and follow checks")
   for i in handles.size():
    check(mirrors.bodies[i].position.distance_to(p.position)<starts[i].distance_to(p.position)-3,"Copy %d resumes following after combat"%i)
   if id==34:await picture("kaz-copy-follow-%d"%cycle)
   mirrors.clear()
   check(handles.all(func(handle):return not army.valid(handle)),"Retirement removes every native lease")
  check(mirrors.bodies==pooled_bodies,"Fighter %d reuses its prepared copy bodies"%id)
  army.clear();game.model.enemies.clear();army.refresh_kits();p.position=home
  for cycle in 2:
   check(mirrors.cast(),"Fighter %d can summon after retirement"%id)
   await driver.advance(12,tick_army)
   var enemy=spawn(Vector3.ZERO)
   army.apply_hit(enemy.handle,{"element":"ice","status_seconds":100.0})
   for body in mirrors.bodies.slice(0,mirrors.handles.size()):
    body.ai_target=enemy
    var index=body.actions.map(func(slot):return slot[1]).find("special_4")
    body.perform(index,enemy.position+Vector3.UP)
   check(mirrors.bodies.slice(0,mirrors.handles.size()).all(func(body):return body.spell_loadout.current!=null),"Charges are active before interruption")
   mirrors.clear()
   check(mirrors.bodies.all(func(body):return not body.leased and body.spell_loadout.current==null and not body.has_offensive_action()),"Fighter %d clears interrupted charge state"%id)
   army.despawn(enemy.handle);army.sync_compatibility()
  print("MIRROR_CHARACTER_RESULT id=%d checks=%d failures=%d"%[id,checks,failures])
 check(army.worker_jobs>0,"Regression exercises the normal native worker")
 game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MIRROR_MOVEMENT_RESULT checks=%d failures=%d steps=%d"%[checks,failures,steps]);quit(1 if failures else 0)
