extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Experience Feedback/"
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")

func popups()->Array:
 return game.crowd.army.presentation.labels.filter(func(label):return label.visible and label.text.ends_with(" EXP"))

func enemy(at:Vector3,reward:int)->int:
 var row=game.model.waves.spawn_enemy(Roles.SLIME,at);row.xp_reward_tenths=reward
 game.army_runtime.import_arrivals()
 return game.army_runtime.handles[row.id]

func run():
 create_timer(180).timeout.connect(func():printerr("EXPERIENCE_FEEDBACK_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.player.select_character(game.player.RogueRoster.KAZI_ID)
 game.training_dummy.hide();game.training_dummy.collision_layer=0
 var home=Vector3(-150,game.model.surface_height(-150,127),127)
 game.player.position=home;game.model.update_vision(home)
 game.camera_rig.camera.position=home+Vector3(5,6,12)
 game.camera_rig.camera.look_at(home+Vector3.UP*2)
 game.camera_focused=false;game._sync_camera_mouse()
 var army=game.army_runtime;var fx=game.crowd.army.presentation;var xp=game.model.team_progression
 xp.reset();xp.cards_enabled=false
 fx.clear();army.flush_presentation();fx.clear()
 var at=home+Vector3(2,0,-2)
 var foe=enemy(at,12)
 army.apply_hit(foe,{"amount":100000.0,"source_id":0})
 army.flush_presentation()
 check(is_equal_approx(xp.experience(),1.2),"A native enemy death retains its exact fractional XP reward")
 var shown=popups()
 check(shown.size()==1 and shown[0].text=="+1 EXP","One native death shows one whole-number EXP receipt without changing fractional credit")
 if not shown.is_empty():
  var label:Label3D=shown[0]
  check(label.modulate==Color("ce8cff") and label.font==fx.BATTLE_TEXT_FONT and label.outline_size==5,"EXP uses readable purple battle text and a dark outline")
  check(label.position.is_equal_approx(at+Vector3.UP*4),"EXP appears above the defeated enemy's native position")
  var camera:Camera3D=game.camera_rig.camera
  var damage_labels=fx.labels.filter(func(other):return other.visible and not other.text.ends_with(" EXP"))
  check(damage_labels.all(func(other):return absf(camera.unproject_position(other.position).y-camera.unproject_position(label.position).y)>24),"EXP is visibly separated from the final damage number")
  var start=label.position
  fx.tick(.1);check(label.position.y>start.y,"EXP floats upward")
  game.paused=true;fx.tick(.3)
  check(label.visible and is_equal_approx(fx.label_ages[fx.labels.find(label)],.55),"Pause holds the EXP animation")
  game.paused=false
 if DisplayServer.get_name()!="headless":
  await frames(3);await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(OUT+"purple-exp.png")==OK,"Capture purple EXP at the actual enemy death")
 var count_before=popups().size()
 check(not army.apply_hit(foe,{"amount":100000.0}).accepted,"A stale enemy cannot die twice")
 army.flush_presentation()
 check(popups().size()==count_before and is_equal_approx(xp.experience(),1.2),"Duplicate hits add neither XP nor feedback")
 fx.tick(.5)
 check(popups().size()==1 and shown[0].modulate.a<1,"EXP fades before expiry")
 fx.tick(.1);check(popups().is_empty(),"Expired EXP returns its label to the pool")
 var reused=fx.label_damage(at,8)
 check(reused!=null and reused.font==fx.DAMAGE_FONT and reused.modulate==Color.WHITE and reused.outline_size==0,"Reused EXP slots reset to ordinary damage styling")
 fx.clear()
 check(fx.label_experience(at,10).text=="+1 EXP" and fx.label_experience(at,500).text=="+50 EXP","Whole and boss-sized rewards have no trailing decimal")
 check(fx.label_experience(at,14).text=="+1 EXP" and fx.label_experience(at,16).text=="+2 EXP","Fractional rewards round to the nearest whole number for display")
 check(fx.label_experience(at,0)==null and fx.label_experience(at,-10)==null,"Nonpositive rewards show no EXP")
 fx.clear()
 game.settings.forest_pet_loadout=[Pets.key(0)];army.reconcile_pet_loadout();army.queue_hounds()
 for i in 60:
  army.integration_tick(1.0/60)
  if army.pending_hounds.is_empty():break
 army.flush_presentation();fx.clear()
 foe=enemy(at,10)
 army.apply_hit(foe,{"amount":100000.0,"source_id":army.HOUND_ID})
 army.flush_presentation()
 check(popups().size()==1 and popups()[0].text=="+1 EXP" and is_equal_approx(xp.experience(),2.2),"Pet kills share the same single EXP popup and character reward")
 check(is_equal_approx(xp.pet_experience[Pets.key(0)].experience(),1.0),"Pet attribution remains unchanged")
 fx.clear()
 var nodes=fx.get_child_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 seed(4831);var expected=randf();seed(4831)
 for repeat in 20:
  for i in 200:fx.label_experience(at,10+i)
  check(fx.counts().labels==fx.MAX_LABELS,"Simultaneous XP stays within the existing label budget")
  fx.tick(.7)
 check(randf()==expected,"EXP cosmetics never consume combat RNG")
 check(fx.get_child_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated EXP reuses prepared nodes and resources")
 check(popups().is_empty(),"Repeated EXP completely expires")
 game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("EXPERIENCE_FEEDBACK_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
