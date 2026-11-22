extends "res://tests/forest-shrine/pet_defense_test.gd"
const FORMATION_OUT="res://build/Other Files/Asset Toolkit/Pet Formation/"
const POSTS=[Vector3(-7,0,3.5),Vector3(7,0,3.5),Vector3(0,0,-7),Vector3(-7,0,-3.5),Vector3(7,0,-3.5)]
func run():
 create_timer(180).timeout.connect(func():quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FORMATION_OUT))
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.player.select_character(preload("res://scripts/rogue_roster.gd").KAZI_ID)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 game.player.position=Vector3(-120,0,125);game.player.position.y=game.model.surface_height(-120,125)
 game.player.velocity=Vector3.ZERO
 game.player.facing=Vector3.FORWARD
 game.player.hp=100000;game.player.max_hp=100000
 var army=game.army_runtime
 var skins=[41,0,81,21,61]
 game.settings.forest_pet_loadout=Pets.sanitized(skins.map(func(s):return Pets.key(s)))
 army.queue_hounds()
 for i in 120:army.integration_tick(1.0/60);army.flush_presentation()
 var pets:Array[int]=[]
 for skin in skins:
  if army.handles.has(army.HOUND_ID-skin):pets.append(army.handles[army.HOUND_ID-skin])
 check(pets.size()==5,"Five mixed pets arrive")
 if pets.size()!=5:quit(1);return
 check(army.hound_order==army.HoundOrder.DEFEND and army.hound_order_serial==0,"Fresh summons use default defense without requiring Z")
 for i in pets.size():
  var expected:Vector3=game.player.position+Vector3(POSTS[i].x,0,-POSTS[i].z)
  var actual:Vector3=army.unit_state(pets[i]).position
  check(Vector2(actual.x-expected.x,actual.z-expected.z).length()<1.5,"Summoned party slot %d uses its default formation post"%[i+1])
 for cycle in 3:
  var forward=Vector3.FORWARD if cycle==0 else Vector3.RIGHT
  game.player.facing=forward
  if cycle==2:game.player.position.x+=12
  var serial:int=army.hound_order_serial
  pet_key(KEY_Z);pet_key(KEY_Z,false)
  check(army.hound_order==army.HoundOrder.RETURN and army.hound_order_serial==serial+1,"Z recalls the five-slot formation, cycle %d"%cycle)
  var max_step=0.0
  for tick in 720:
   var before=pets.map(func(h):return army.unit_state(h).position)
   army.integration_tick(1.0/60);army.flush_presentation()
   for i in pets.size():max_step=maxf(max_step,army.unit_state(pets[i]).position.distance_to(before[i]))
   if tick%12==0:game.crowd.present_army(army.render_snapshot(),[]);await frames(1)
  check(max_step<1.1,"Pets run back without teleporting, cycle %d"%cycle)
  var right=Vector3(-forward.z,0,forward.x)
  for i in pets.size():
   var expected:Vector3=game.player.position+right*POSTS[i].x+forward*POSTS[i].z
   var actual:Vector3=army.unit_state(pets[i]).position
   print("FORMATION_SLOT cycle=",cycle," slot=",i+1," expected=",expected," actual=",actual)
   check(Vector2(actual.x-expected.x,actual.z-expected.z).length()<1.5,"Party slot %d reaches its approved post, cycle %d"%[i+1,cycle])
  if cycle==0:
   var camera=game.camera_rig.camera
   camera.global_position=game.player.position+Vector3(0,34,22);camera.look_at(game.player.position)
   game.player.model.rotation.y=0
   game.crowd.present_army(army.render_snapshot(),[]);game.forest_ui.sync()
   if DisplayServer.get_name()!="headless":
    await frames(3);await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(FORMATION_OUT+"z-five-pet-formation.png")==OK,"Captured actual recalled formation")
 army.order_hounds(army.HoundOrder.ATTACK)
 check(army.recall_hounds(),"The hunted party can be dismissed")
 army.queue_hounds();army.import_hounds();army.import_hounds()
 check(army.hound_order==army.HoundOrder.DEFEND,"Resummoning defaults to formation defense after hunting")
 pets.clear()
 for i in skins.size():
  var handle:int=army.handles.get(army.HOUND_ID-skins[i],0)
  check(handle!=0,"Resummoned slot %d arrives"%[i+1])
  if handle==0:quit(1);return
  pets.append(handle)
  var expected:Vector3=game.player.position+Vector3(POSTS[i].z,0,POSTS[i].x)
  var actual:Vector3=army.unit_state(handle).position
  check(Vector2(actual.x-expected.x,actual.z-expected.z).length()<.1,"Resummoned slot %d appears directly at its default post"%[i+1])
 await verify_hold_position(army,pets)
 game.queue_free();current_scene=null;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_FORMATION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
