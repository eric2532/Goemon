extends "res://tests/forest-shrine/pet_attack_skills_test.gd"
const DEST="res://build/Other Files/Asset Toolkit/Pet Skill Decisions/"
func first_skill()->Dictionary:
 for event in game.army_runtime.event_log:
  if event.kind=="pet_skill_started":return event
 return {}
func snapshot(name_:String,at:Vector3):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.camera.global_position=at+Vector3(10,12,18)
 game.camera_rig.camera.look_at(at+Vector3(0,1,-4));game.camera_rig.camera.reset_physics_interpolation()
 game.army_runtime.flush_presentation();game.forest_ui.sync()
 await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(DEST+name_+".png")==OK,"Captured "+name_)
func run():
 create_timer(240).timeout.connect(func():printerr("PET_SKILL_SELECTION_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(DEST);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.camera_rig.set_process(false)
 p.select_character(p.RogueRoster.KAZI_ID);fresh();home.y=game.model.surface_height(home.x,home.z)+.05;p.position=home+Vector3.RIGHT*30
 game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;army.refresh_kits();army.record_events=true
 for node in [game,p,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true;game.model.update_vision(home)
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):
  if is_instance_valid(shot.hero) and shot.hero.get("pet_key")!=null:shots.append(shot);shot.set_physics_process(false))
 var loadout=[Pets.Spells.SURE_STRIKE,"kazi/meteor","kazi/qigong"]
 for skin in [0,21,41,61,82]:
  await equip_pack([skin],[loadout])
  var handle:int=army.handles[army.HOUND_ID-skin];var at:Vector3=army.unit_state(handle).position
  var victim=spawn(at-home+Vector3.FORWARD,1)
  army.order_hounds(army.HoundOrder.HOLD)
  var mana:float=army.unit_state(handle).mana
  for tick in 240:
   advance()
   if victim.dead:break
  check(victim.dead and first_skill().is_empty(),"Pet family %d finishes a weak enemy with a real normal hit"%skin)
  check(army.unit_state(handle).mana>=mana-.0001,"Pet family %d saves its MP"%skin)
 await equip_pack([0],[loadout])
 game.set_pet_skill_level(Pets.key(0),"kazi/meteor",5)
 var handle:int=army.handles[army.HOUND_ID];var at:Vector3=army.unit_state(handle).position
 var victims=[spawn(at-home+Vector3.FORWARD*3),spawn(at-home+Vector3(8,0,-5))]
 for victim in victims:army.apply_hit(victim.handle,{"element":"ice","status_seconds":100})
 army.order_hounds(army.HoundOrder.HOLD)
 for tick in 240:
  advance()
  if victims.all(func(victim):return victim.hp<1000000):break
 check(int(first_skill().get("action_index",0))==9,"A trained area spell takes priority when two clear targets fit its victim limit")
 check(victims.all(func(victim):return victim.hp<1000000),"The preferred Meteor really damages both selected enemies")
 check(int(first_skill().get("target_id",0))==victims[0].forest_id,"Area preference keeps the pet's existing primary target")
 await snapshot("meteor-group",at)
 # Reducing the prepared target count immediately removes the group-only preference.
 game.set_pet_skill_level(Pets.key(0),"kazi/meteor",1)
 var caster=army.pet_skills.casters[Pets.key(0)]
 check(is_equal_approx(caster.Skills.effective(caster,"kazi/meteor","count"),1),"Pet skill-level changes refresh the trained target limit")
 await equip_pack([61],[[Pets.Spells.BEE_FLURRY,"kazi/qigong",Pets.Spells.SURE_STRIKE]])
 handle=army.handles[army.HOUND_ID-61];at=army.unit_state(handle).position
 var distant=spawn(at-home+Vector3.FORWARD*12,1)
 army.apply_hit(distant.handle,{"element":"ice","status_seconds":100});army.order_hounds(army.HoundOrder.HOLD)
 for tick in 240:
  advance()
  if not first_skill().is_empty():break
 check(int(first_skill().get("action_index",0))==3,"A distant weak enemy gets a legal ranged attack instead of a melee finisher or blink")
 check(army.unit_state(handle).position.distance_to(at)<.02,"Hold stays planted during the ranged decision")
 await snapshot("ranged-choice",at)
 check(pool.misses==0,"Skill preferences use the existing prepared projectile pool")
 for row in [[KEY_F,army.HoundOrder.HOLD],[KEY_Z,army.HoundOrder.RETURN],[KEY_R,army.HoundOrder.COMBINED],[KEY_R,army.HoundOrder.DEFEND]]:
  var event=InputEventKey.new();event.physical_keycode=row[0];event.pressed=true;game._input(event)
  advance()
  check(army.hound_order==row[1] and army.hound_focus_target==0,"Physical command %s retains its existing order"%OS.get_keycode_string(row[0]))
 game.queue_free();paused=false;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_SKILL_SELECTION_RESULT checks=%d failures=%d"%[checks,failures])
 if not failures and "--full" in OS.get_cmdline_user_args():
  await super.run()
  return
 quit(1 if failures else 0)
