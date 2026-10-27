extends "res://tests/forest-shrine/dark_lumina_3_controls_test.gd"
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const FX_OUT="res://build/Other Files/Asset Toolkit/Dark Lumina Effects Restoration/"
var fx:Node
var home=Vector3(0,.1,140)
func view(label_:String):
 if not visual:return
 fx.draw_effects();await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(FX_OUT+label_+".png")==OK,"Rendered "+label_)
func run():
 create_timer(180).timeout.connect(func():printerr("LUMINA_EFFECTS_TIMEOUT");quit(1))
 visual=DisplayServer.get_name()!="headless"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FX_OUT))
 var map=preload("res://scripts/forest/forest_map_document.gd").new();map.load_wind_meadow();await setup_fixture(map.data)
 home.y=game.model.surface_height(home.x,home.z)+.1
 game.set_process(false);game.army_runtime.set_physics_process(false)
 game.set_process_input(false);game.set_process_unhandled_input(false)
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false);game.camera_rig.set_process_unhandled_input(false)
 game.tuning.invincible=true;game.model.phase="wave"
 if visual:
  root.title="Goemon · Both Dark Lumina effects"
  root.set_flag(Window.FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var p=game.player;p.select_character(30);fresh();p.position=home
 game.training_dummy.home=home+Vector3(0,0,-14);game.training_dummy.position=game.training_dummy.home
 game.ui.hide();game.forest_ui.hide()
 game.camera_rig.camera.global_position=home+Vector3(32,22,42);game.camera_rig.camera.look_at(home+Vector3(0,3,-8))
 fx=game.crowd.army.presentation
 var pool=Pool.service(game);pool.launched.connect(func(shot):shot.set_physics_process(false))
 for key in ["core_rays","sword_wave"]:
  for surface in Finale.meshes[key].get_surface_count():
   var mat=Finale.meshes[key].surface_get_material(surface)
   check(mat.blend_mode==BaseMaterial3D.BLEND_MODE_ADD and mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"Source additive transparency: "+key)
 var aura_material=Finale.meshes.cast_aura.surface_get_material(0)
 check(aura_material.get_shader_parameter("frames")==4.0 and aura_material.get_shader_parameter("atlas")!=null,"Casting aura retains all four original animated palette phases")
 for key in ["fire","impact","ember"]:check(is_equal_approx(Dark.meshes[key].material.get_shader_parameter("opacity_scale"),1),"DL2 source brightness: "+key)
 for key in ["fire","water","water_fall","sword_cross","sky_spark_0","sky_spark_1","sky_spark_2","sky_spark_3"]:
  check(is_equal_approx(Finale.meshes[key].surface_get_material(0).get_shader_parameter("opacity_scale"),1),"DL3 source brightness: "+key)
 check(Finale.meshes.blast==Dark.meshes.stomp_wave,"Earth reuses actor 0x352's exact recovered mesh, texture and motion shader")
 check(Finale.meshes.wind.surface_get_material(0).shader.code.contains("blend_mix") and Finale.meshes.wind_outer.surface_get_material(0).shader.code.contains("blend_add"),"Wind retains its solid textured core and source additive outer layer")
 check(fx.projectile_batches["skullpion-ball"].multimesh.mesh.material.get_shader_parameter("opacity_scale")==null,"Unrelated Skullpion sprites retain the unchanged shader default")
 for key in ["cast_aura","core_rays"]:
  fx.clear();fx.add_effect("finale-"+key,home+Vector3.UP*3,2,1);await view(key)
 fx.clear();fx.finale_cue(home,2,Vector3.FORWARD,p.active_ability.get_instance_id())
 var aura=fx.effects.filter(func(e):return e.kind=="finale-cast_aura")[0]
 check(is_equal_approx(Finale.meshes.cast_aura.get_aabb().size.x,8.1) and is_equal_approx(Finale.meshes.cast_aura.get_aabb().size.y,10.8),"Aura uses the original actor's 3/4/3 scale")
 p.position+=Vector3.RIGHT*5;p.facing=Vector3.RIGHT;fx.draw_effects()
 var anchor=p.position+Basis(Vector3.UP,-PI/2)*Vector3(0,64,-40)*.018*Finale.SCALE
 # The headless Dummy renderer returns identity for MultiMesh transform readback.
 if visual:check(fx.batches["finale-cast_aura"].multimesh.get_instance_transform(0).origin.is_equal_approx(anchor),"Aura follows the actual caster's movement and facing")
 for phase in 4:
  aura.age=phase/30.0;await view("aura-phase-%d"%phase)
 fx.tick(8.0/30)
 check(not fx.effects.any(func(e):return e.kind=="finale-cast_aura"),"Aura retires after the original eight source ticks")
 p.position=home;p.facing=Vector3.FORWARD
 # Real contacts must retain each release's silhouette, including on pooled reuse.
 for cross in [false,true,false]:
  fx.clear();contacts.clear()
  var shot=pool.launch(p,preload("res://scripts/dark_lumina_3_projectile.gd"),"finale0",{"kind":0,"cross_slash":cross,"position":home+Vector3(0,.075,-4.5),"velocity":Vector3.FORWARD*Finale.SHOT_SPEED[0],"damage":1.0,"attack_ticket":p.attack_chain.begin("sword")})
  check(shot.visual.multimesh.mesh==(Finale.meshes.sword_cross if cross else Finale.meshes.sword_wave),"Launch uses the correct silhouette after reuse")
  await view("energy-before-"+str(cross))
  for i in 30:
   shot._physics_process(1.0/60)
   if not shot.pool_live:break
  check(not shot.pool_live and contacts.size()==1,"Energy release hits a real enemy exactly once")
  check(fx.effects.any(func(e):return e.kind==("finale-sword_cross" if cross else "finale-sword_wave")),"Contact retains the incoming energy shape")
  check(not fx.effects.any(func(e):return e.kind==("finale-sword_wave" if cross else "finale-sword_cross")),"Contact never substitutes the other release's mesh")
  if not cross:
   var wave=fx.effects.filter(func(e):return e.kind=="finale-sword_wave")[0]
   check(is_equal_approx(wave.position.y,shot.position.y) and is_equal_approx(wave.scale,1),"Enemy contact retains the ground wave's height and size")
  await view("energy-impact-"+str(cross));fx.tick(1)
 for cross in [false,true]:
  fx.clear();fx.present([{"kind":"projectile_impact","unit_kind":18,"source_id":999,"position":home,"direction":Vector3.FORWARD,"action_index":0,"source_tick":1 if cross else 0}])
  check(fx.effects.any(func(e):return e.kind==("finale-sword_cross" if cross else "finale-sword_wave")),"Native impact event retains the same release silhouette")
 fx.clear();fx.finale_cue(home,15)
 var waves=fx.effects.filter(func(e):return e.kind=="finale-blast")
 check(waves.size()==1 and is_zero_approx(waves[0].age),"Each Earth damage cue emits exactly one flame wave")
 fx.tick(.2);await view("earth-original-wave")
 fx.clear();fx.finale_cue(home,30)
 fx.tick(.71);fx.draw_effects()
 check(fx.batches["finale-burst"].multimesh.visible_instance_count==8,"Defeat emits the original eight radial burst planes")
 await view("core-burst")
 fx.tick(4);check(fx.effects.is_empty(),"All core/burst layers expire")
 p.select_character(29);p.position=home;fx.clear();p.active_ability.die()
 check(fx.effects.filter(func(e):return e.kind in ["dark-shock_dome","dark-shock_ring"]).size()==2,"Playable DL2 defeat schedules both recovered energy meshes")
 fx.tick(140.0/30+.3);await view("dl2-defeat-energy");fx.tick(4)
 check(fx.effects.is_empty(),"Delayed DL2 defeat layers expire")
 fx.clear();fx.present([{"kind":"death","unit_kind":17,"target_id":999,"position":home,"direction":Vector3.FORWARD,"team":1}])
 check(fx.effects.filter(func(e):return e.kind in ["dark-shock_dome","dark-shock_ring"]).size()==2,"Native DL2 defeat uses the same recovered energy layers")
 fx.tick(10);fx.clear()
 var nodes=fx.get_child_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 4:
  for i in 12:
   var at=home+Vector3((i%4-1.5)*24,0,-floori(i/4.0)*24)
   fx.dark_cue(at,8);fx.dark_cue(at,9);fx.dark_cue(at,15);fx.finale_cue(at,15);fx.finale_cue(at,30)
  fx.tick(.71)
  check(fx.batches["finale-burst"].multimesh.visible_instance_count==96,"Twelve simultaneous defeats retain all eight source burst planes")
  check(fx.batches["dark-stomp_wave"].multimesh.visible_instance_count==24,"Simultaneous DL2 stomps retain both waves")
  check(fx.batches["finale-blast"].multimesh.visible_instance_count==12,"Twelve simultaneous Earth cues each present one damaging wave")
  if repeat==0:await view("simultaneous-effects")
  fx.tick(10)
 check(fx.effects.is_empty() and fx.get_child_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated simultaneous effects retire without prepared-node or resource growth")
 var result={"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"visual":visual,"presentation_nodes":nodes,"note":"Focused rendered correctness/resource checks, not a full-battle FPS benchmark"}
 FileAccess.open(FX_OUT+("rendered" if visual else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("LUMINA_EFFECTS_RESULT ",JSON.stringify(result))
 game.queue_free();await frames(4);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
