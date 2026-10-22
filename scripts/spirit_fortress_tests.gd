extends SceneTree
## Run with --script res://scripts/spirit_fortress_tests.gd after asset import.
var game
var checks=0
var failures=0

func _initialize():
 run.call_deferred()

func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+label)
 else:print("PASS: ",label)

func frames(count: int):
 for i in range(count):await physics_frame

func run():
 game=load("res://scenes/main.tscn").instantiate()
 game.smoke_test=true
 root.add_child(game)
 game.smoke_test=true;game.tuning.freeze_ai=true;game.tuning.invincible=true
 game.start_mode("defense");await frames(5)
 var fx=game.world.get_node_or_null("SpiritFortressEffects")
 check(fx!=null,"Spirit Fortress effects are visible in the playable Fire Siege world")
 if fx==null:await finish();return
 check(game.world.cannon_sites.size()==12 and game.world.mine_sites.size()==4 and game.encounters.money==10,"Effects preserve all twelve tower sites, four mines and starting funds")
 check(game.world.lanes[1][0]==Vector3(0,0,110) and game.world.base_position==Vector3(0,0,220) and game.world.lanes[1][-1]==game.world.base_position,"Effects preserve the enemy route and shrine destination")
 check(fx.find_children("*","CollisionObject3D",true,false).is_empty(),"Decorative effects add no collision to combat or construction")
 game.settings.quality=1;game.apply_quality()
 check(fx.visible and fx.particles.all(func(p):return p.emitting),"Medium quality enables petals and spirit motes")
 check(fx.lights.size()<=5 and fx.lights.all(func(l):return l.visible and not l.shadow_enabled),"Medium quality caps accent lights and their shadow cost")
 var environment=game.world.find_children("*","WorldEnvironment",true,false)[0].environment
 check(environment.glow_enabled and environment.fog_enabled,"Emission bloom and distance haze are enabled")
 check(fx.water_material.shader!=null and not fx.banner_materials.is_empty(),"Water and existing battlefield banners use the source effects shaders")
 check(fx.particles.all(func(p):return p.mesh.material.vertex_color_use_as_albedo),"Particle lifetime colors and opacity reach their rendered material")
 check(fx.find_children("*","GeometryInstance3D",true,false).all(func(n):return n.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"Decorative effects do not add shadow passes or an opaque shadow beneath the fading rune")
 var cloth=game.world.find_children("SpiritCloth","MeshInstance3D",true,false)
 check(cloth.size()>1 and cloth.all(func(n):return n.mesh==cloth[0].mesh and n.material_override==cloth[0].material_override),"Identical opaque battlefield banners share mesh and material for instancing")
 var clock=float(fx.clock_time)
 var water_clock=float(fx.water_material.get_shader_parameter("clock_time"))
 var stone_position: Vector3=fx.float_roots[0].position
 await frames(30)
 check(fx.clock_time>clock and fx.water_material.get_shader_parameter("clock_time")>water_clock,"Water and wind advance with the game clock")
 check(fx.float_roots[0].position!=stone_position,"Floating stones animate during play")
 game.show_pause();var paused_clock=float(fx.clock_time)
 var paused_stone: Vector3=fx.float_roots[0].position
 await frames(10)
 check(is_equal_approx(fx.clock_time,paused_clock) and fx.float_roots[0].position==paused_stone,"Pause freezes shader time and floating scenery")
 game.resume();await frames(5)
 check(fx.clock_time>paused_clock,"Resume continues the effects")
 game.settings.quality=2;game.apply_quality()
 check(fx.lights.any(func(l):return l.shadow_enabled),"High quality enables the shrine accent shadow")
 game.settings.quality=0;game.apply_quality()
 check(not fx.visible and fx.particles.all(func(p):return not p.emitting),"Low quality stops added particles and hides decorative effects")
 check(fx.lights.all(func(l):return not l.visible and not l.shadow_enabled),"Low quality removes added light and shadow work")
 check(fx.banner_materials.all(func(m):return m.get_shader_parameter("animate")==false),"Low quality keeps battlefield banners visible with static cloth")
 game.settings.quality=1;game.apply_quality()
 check(fx.visible and fx.banner_materials.all(func(m):return m.get_shader_parameter("animate")==true),"Switching back to Medium restores animated scenery")
 await capture("standard",Vector3(32,18,214),Vector3(0,2,195))
 var old_fx=weakref(fx)
 game.restart_area();await frames(5)
 check(old_fx.get_ref()==null and game.world.get_node_or_null("SpiritFortressEffects")!=null,"Restart frees old effects and creates one fresh instance")
 var doc=load("res://scripts/map_document.gd").new();doc.reset_template()
 doc.place("banner",Vector3(-30,0,210),90)
 game.custom_map_data=doc.data.duplicate(true);game.restart_area();await frames(5)
 fx=game.world.get_node_or_null("SpiritFortressEffects")
 check(fx!=null,"Playable custom maps receive Spirit Fortress effects")
 if fx!=null:
  check(fx.get_node_or_null("SpiritPools")==null and fx.float_roots.is_empty(),"Custom maps receive no unplaced pools or floating stone scenery")
  check(game.world.cannon_sites.size()==12 and game.world.mine_sites.size()==4,"Custom map gameplay markers are preserved")
  check(game.world.find_children("SpiritCloth","MeshInstance3D",true,false).size()==3,"Every custom map banner receives animated cloth, including duplicate and rotated pieces")
  await capture("custom",Vector3(31,18,214),Vector3(0,2,195))
 var editor=load("res://scripts/map_builder_world.gd").new()
 editor.map_data=doc.data.duplicate(true);editor.editor_labels=true;root.add_child(editor)
 check(editor.get_node_or_null("SpiritFortressEffects")==null,"Map authoring keeps its clear lighting and has no runtime effects")
 editor.queue_free();game.custom_map_data.clear()
 game.start_mode("descent");await frames(5)
 check(not game.world.has_node("SpiritFortressEffects"),"Leaving Fire Siege clears the effects from other game modes")
 await finish()

func capture(label: String,from: Vector3,target: Vector3):
 if DisplayServer.get_name()=="headless":return
 if not "--spirit-captures" in OS.get_cmdline_user_args():return
 game.player.set_physics_process(false);game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 var camera=game.camera_rig.camera
 camera.global_position=from;camera.look_at(target)
 await frames(20);await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute("res://build/spirit-fortress")
 check(root.get_texture().get_image().save_png("res://build/spirit-fortress/"+label+".png")==OK,"Rendered "+label+" view saved")
 game.player.set_physics_process(true);game.camera_rig.set_process(true);game.camera_rig.set_physics_process(true)

func finish():
 print("SPIRIT_FORTRESS_RESULT checks=",checks," failures=",failures)
 game.sound_library.cancel();game.music.stop();game.queue_free();await frames(3)
 quit(1 if failures else 0)
