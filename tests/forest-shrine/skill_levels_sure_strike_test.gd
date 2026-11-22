extends "res://tests/forest-shrine/crossgate_blast_coverage_test.gd"
const Evidence="res://build/Other Files/Skill Levels/Sure Strike/"
var caption:Label

func picture(filename:String,text:String):
 if DisplayServer.get_name()=="headless":return
 caption.text=text
 game.forest_ui.sync();game.forest_ui.hide();game.army_runtime.flush_presentation();game.crowd.army.presentation.draw_effects()
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(Evidence+filename+".png")==OK,"Rendered "+filename)

func run():
 create_timer(120).timeout.connect(func():printerr("SURE_STRIKE_LEVEL_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(Evidence)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime;var fx=game.crowd.army.presentation
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.camera_rig.set_process(false)
 for node in [game,p,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*1000
 var overlay=CanvasLayer.new();root.add_child(overlay);caption=Label.new();caption.position=Vector2(32,28);caption.add_theme_font_size_override("font_size",24);caption.add_theme_color_override("font_shadow_color",Color.BLACK);caption.add_theme_constant_override("shadow_offset_x",2);caption.add_theme_constant_override("shadow_offset_y",2);overlay.add_child(caption)
 p.select_character(37);fresh();p.model.select_stance(1);game.update_character_tuning(37,"critical_chance",0)
 p.position=home;p.velocity=Vector3.ZERO
 await driver.advance(20,advance)
 game.camera_rig.camera.global_position=home+Vector3(20,14,22);game.camera_rig.camera.look_at(home+Vector3(0,2,-4))
 for level_ in [1,10,19,30]:
  army.clear();game.model.enemies.clear();army.refresh_kits();fx.effects.clear();p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
  var target=spawn(Vector3(0,0,-3.5));var hp=target.hp
  army.native.set_pose(target.handle,target.global_position,0);army.sync_targets()
  await driver.advance(3,advance)
  p.active_ability.cancel(true);p.active_ability.clear_cooldowns();p.attack_chain.reset()
  Skills.set_level(p,"shin/sure-strike",level_)
  p.active_ability.start_shin_area_cast()
  var size=1.0+.01*(level_-1)
  check(is_equal_approx(p.active_ability.ticket.skill_size,size) and is_equal_approx(p.active_ability.ticket.skill_hit_area,size),"Sure Strike Lv%d impact and physical area still grow by 1%% of the starting size"%level_)
  var glow=p.model.combo_glow
  var cell=glow.texture.get_size()/Vector2(glow.hframes,glow.vframes)
  check(is_equal_approx(maxf(cell.x,cell.y)*glow.pixel_size*glow.global_basis.get_scale().x,Skills.BASE_DIAMETER*[91.0,168.0,272.0,357.0,357.0][Skills.Levels.shine_tier(level_)]/357.0),"Charge uses its separate shine tier")
  await driver.advance(12,advance)
  await picture("level-%02d-charge"%level_,"乾坤  Lv %d  |  %.2f× damage  |  original shine tier %d"%[level_,1+.1*level_,Skills.Levels.shine_tier(level_)+1])
  for i in 120:
   await driver.advance(1,advance)
   if target.hp<hp:break
  var damage=hp-target.hp
  check(is_equal_approx(damage,250.0*(1+.1*level_)),"Sure Strike Lv%d actual native contact deals %.0f damage"%[level_,damage])
  var bursts=fx.effects.filter(func(effect):return effect.kind=="shin_sure_strike")
  check(bursts.size()==1,"One confirmed hit has one pooled body-centred impact")
  for burst in bursts:burst.age=.5
  await picture("level-%02d-impact"%level_,"乾坤  Lv %d  |  %.0f actual damage  |  %.2f× impact size"%[level_,damage,size])
  await driver.advance(80,advance)
  hp=target.hp;p.active_ability.clear_cooldowns();p.attack_chain.reset()
  target.position=home+Vector3(80,0,-3.5);army.native.set_pose(target.handle,target.position,0);army.sync_targets()
  p.facing=Vector3.BACK;p.active_ability.start_shin_area_cast();await driver.advance(130,advance)
  check(target.hp==hp,"A missed cast adds no explosion damage")
 var snapshot=p.attack_chain.begin("shin_sure_strike").duplicate(true)
 Skills.set_level(p,"shin/sure-strike",1)
 check(snapshot.skill_level==30 and snapshot.skill_rules.damage==4.0,"A released level-30 cast retains its damage and size snapshot")
 print("SURE_STRIKE_LEVEL_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();overlay.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
