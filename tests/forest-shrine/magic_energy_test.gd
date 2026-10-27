extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Exercise the existing player, native victims, shared audio and prepared waves.
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
const Ink=preload("res://assets/rogue/scripts/ink_brush_style.gd")
var combat
var visual=false
var output="res://build/Other Files/Asset Toolkit/Purple Energy/Direction"
func quiet(node:Node):
 if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
 for child in node.get_children():quiet(child)
func reset_cast():
 combat.cancel();combat.reset_run();combat.set_process(false)
 game.player.position=ORIGIN;game.player.velocity=Vector3.DOWN*30;game.player.move_and_slide();game.player.velocity=Vector3.ZERO;game.player.facing=Vector3.BACK
 combat.player.pos=game.player.position;combat.player.angle=0;combat.player.grounded=true;combat.aim=ORIGIN+Vector3.BACK*40
 combat.sound.last_events.clear();game.player.attack_chain.reset()
func advance_cast(count:int):
 for i in count:
  combat.tick(1.0/60);combat._sync_hero();combat._animate(1.0/60,0);combat.fx.tick(1.0/60)
  if visual:await physics_frame
func capture(label_:String):
 if not visual:return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output.path_join(label_+".png"))==OK,"Saved "+label_+" gameplay view")
func run():
 visual="--visual" in OS.get_cmdline_user_args()
 if not OS.get_environment("GOEMON_MAGIC_OUTPUT").is_empty():output=OS.get_environment("GOEMON_MAGIC_OUTPUT")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 await setup_fixture()
 if visual:DisplayServer.window_move_to_foreground();root.grab_focus()
 game.set_process(false);game.army_runtime.set_physics_process(false);game.tuning.invincible=true
 game.training_dummy.position=Vector3(0,-100,0);game.training_dummy.hide()
 game.player.select_character(9);combat=game.player.active_ability;combat.set_process(false)
 verify_audio()
 var runtime=game.army_runtime;runtime.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 runtime.set_navigation(9200,{"width":0})
 var victims=[]
 for distance in [8,18,30]:
  var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3.BACK*distance);row.hp=100000;row.max_hp=100000;victims.append(row.id)
 runtime.import_arrivals();runtime.sync_targets()
 game.model.update_vision(ORIGIN)
 var fixed_camera=Camera3D.new();game.add_child(fixed_camera)
 fixed_camera.global_position=ORIGIN+Vector3(-9,5,-9)
 fixed_camera.look_at(ORIGIN+Vector3(0,1.5,4));fixed_camera.make_current()
 for node in [game,game.player,game.camera_rig]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 reset_cast();combat.attack();await advance_cast(6)
 var ribbons=combat.fx.items.filter(func(item):return item.kind=="magic-brush")
 check(game.player.is_on_floor() and not ribbons.is_empty(),"Grounded sword stroke emits its existing brush ribbon")
 if not ribbons.is_empty():
  var ribbon=ribbons[-1].node;var weapon=combat.visual_actor.joints.Weapon_Cutlass.node
  var tip=weapon.to_global(combat.visual_actor.WEAPON_AXES["magic-swordsman"])
  var vertices=ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  check(ribbon.material_override.get_shader_parameter("purple_energy") and ribbon.to_global(vertices[-1]).distance_to(tip)<.015,"New energy shading follows the authored blade tip")
 await capture("sword")
 await advance_cast(60)
 reset_cast()
 var last_cut=Vector3.ZERO
 for repeat in 6:
  game.player.position=ORIGIN;combat.player.pos=ORIGIN;combat.player.vel=Vector3.ZERO
  game.player.attack_chain.reset()
  var before=vic_health(victims);combat.action("flintlock")
  # Fix aim down the open lane; the camera is offset only to review the art.
  combat.player.attack.waveDirection=Vector3.BACK;combat.player.attack.angle=0;combat.player.angle=0
  check(combat.projectiles.is_empty() and combat.player.attack!=null,"Wave preserves its windup")
  await advance_cast(9)
  check(combat.projectiles.size()==1,"Contact releases exactly one wave")
  if combat.projectiles.is_empty():continue
  var shot=combat.projectiles[0]
  check(combat.sound.voices.any(func(v):return v.stream==SoundLibrary.original_for(13,"musashi_rotation") and v.pitch_scale==1.0),"Actual release plays Mighty Strike at source pitch")
  check(shot.damage==100 and is_equal_approx(shot.vel.length(),22) and shot.pierce and is_equal_approx(shot.width,2.5),"Wave keeps damage, speed, piercing and width")
  check(shot.mesh.get_child_count()==2,"Energy reuses the two prepared crescent surfaces")
  verify_wave_facing(shot)
  for blade in shot.mesh.get_children():
   var vertices=blade.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   check(blade.to_global(vertices[0]).y>0 and blade.to_global(vertices[-1]).y>0,"Both moon tips remain above the ground release plane")
  var cut=shot.mesh.basis.x.normalized()
  if repeat>0:check(absf(cut.dot(last_cut))<.95,"Consecutive shots use distinct cutting planes, including cycle wrap")
  last_cut=cut
  var flight_basis=shot.mesh.basis
  await advance_cast(6)
  check(shot.mesh.basis.is_equal_approx(flight_basis),"Crescent keeps its cutting orientation during flight")
  if repeat<5:await capture("wave-"+str(repeat+1))
  await advance_cast(130)
  var after=vic_health(victims)
  check(before[0]-after[0]==100 and before[1]-after[1]==100 and before[2]-after[2]==100,"Repeated piercing wave hits each native victim exactly once: "+str([before[0]-after[0],before[1]-after[1],before[2]-after[2]]))
  check(combat.projectiles.is_empty(),"Wave expires at its existing range")
 # Exercise actual aim selection as well as the visual's isolated axis checks.
 for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
  reset_cast();game.player.ai_controlled=true;game.player.ai_aim=ORIGIN+direction*30
  combat.action("flintlock")
  check(combat.player.attack.waveDirection.dot(direction)>.999,"Ground aim follows the target heading: "+str(direction))
  var center:Vector3=combat.player.pos+Vector3.UP*1.65*game.player.growth_multiplier()
  combat.release_sword_wave(combat.player.attack)
  var shot=combat.projectiles[-1]
  check(shot.mesh.position.distance_to(center+direction*.9*game.player.growth_multiplier())<.001,"Wave launches centered ahead of the caster instead of sideways at the blade")
  verify_wave_facing(shot)
  game.player.ai_controlled=false
 for direction in [Vector3.RIGHT,Vector3.FORWARD,Vector3(1,.7,-1).normalized(),Vector3.UP,Vector3.DOWN]:
  reset_cast();game.player.position=ORIGIN+Vector3.UP*20;combat.player.pos=game.player.position
  combat.action("flintlock");combat.player.attack.waveDirection=direction
  await advance_cast(9)
  check(combat.projectiles.size()==1,"Aimed wave releases for "+str(direction))
  if not combat.projectiles.is_empty():verify_wave_facing(combat.projectiles[0])
 reset_cast();combat.fx.clear();quiet(game)
 var fx=combat.fx;var nodes=[]
 var ordinary=Ink.material(Color("ff4444"))
 check(not ordinary.get_shader_parameter("purple_energy"),"Other fighters retain their own brush shader palette")
 fx.reduced_flashes=true
 var dim=fx.create_projectile("wave",combat.tint());fx.add_child(dim)
 check(dim.get_meta("ink_materials").all(func(m):return m.get_shader_parameter("purple_energy") and m.get_shader_parameter("energy")<=.42),"Reduced flashes keep the crescent with subdued emission")
 fx.recycle_projectile(dim);fx.reduced_flashes=false
 for i in 8:
  var node=fx.create_projectile("wave",combat.tint());fx.add_child(node);node.position=ORIGIN+Vector3((i%4-1.5)*5,2,4+floori(i/4.0)*5);node.rotation.z=PI/2+(i%3-1)*.7;nodes.append(node)
 for i in 90:
  for node in nodes:Ink.animate(node,1.0/60)
  await process_frame
 var before_nodes=get_node_count();var before_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var durations=[];var focused=0;var previous=Time.get_ticks_usec()
 for i in 240:
  for node in nodes:Ink.animate(node,1.0/60)
  await process_frame
  var now=Time.get_ticks_usec();durations.append((now-previous)/1000.0);previous=now
  if root.has_focus():focused+=1
 var growth_nodes=get_node_count()-before_nodes;var growth_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-before_resources
 check(growth_nodes==0 and growth_resources==0,"Eight overlapping prepared waves have no node/resource growth")
 durations.sort()
 var report={"rendered":visual,"frames":durations.size(),"focused_frames":focused,"frame_median_ms":durations[120],"frame_p95_ms":durations[228],"frame_p99_ms":durations[237],"frame_max_ms":durations[-1],"node_growth":growth_nodes,"resource_growth":growth_resources}
 FileAccess.open(output.path_join("profile-desktop.json" if visual else "profile-headless.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 await capture("overlap")
 for node in nodes:fx.recycle_projectile(node)
 for i in 100:
  var node=fx.create_projectile("wave",combat.tint())
  check(nodes.has(node) and node.transform==Transform3D.IDENTITY,"Reuse resets transform without reconstructing the wave")
  check(node.get_meta("ink_materials").all(func(m):return m.get_shader_parameter("brush_clock")==0.0),"Reuse clears the previous energy clock")
  fx.add_child(node);fx.recycle_projectile(node)
 quiet(game);game.queue_free();game=null;paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MAGIC_ENERGY_RESULT checks=%d failures=%d profile=%s"%[checks,failures,str(report)]);quit(1 if failures else 0)
func vic_health(ids:Array)->Array:
 return ids.map(func(id):return game.actors[id].hp)
func verify_wave_facing(shot:Dictionary):
 var direction:Vector3=shot.vel.normalized()
 check(shot.mesh.basis.z.normalized().dot(direction)>.999,"Every cutting plane keeps +Z aligned with travel")
 for blade in shot.mesh.get_children():
  var vertices=blade.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  var edge:Vector3=blade.to_global(vertices[65])
  var inside:Vector3=blade.to_global(vertices[64])
  var left:Vector3=blade.to_global(vertices[0]);var right:Vector3=blade.to_global(vertices[-1])
  check((edge-inside).dot(direction)>.4 and (edge-left).dot(direction)>1 and (edge-right).dot(direction)>1,"Convex cutting edge leads the hollow and both moon tips")
  check(vertices[0].distance_to(vertices[1])<.0001 and vertices[-1].distance_to(vertices[-2])<.0001,"Both crescent ends taper to sharp points")
func verify_audio():
 var lib=game.sound_library;var swing=SoundLibrary.original_for(13,"heavy_swing");var wave=SoundLibrary.original_for(13,"musashi_rotation")
 for slot in ["native_claymore-sweep","move_primary_1_weapon","move_primary_2_weapon","move_primary_3_weapon","move_dive_weapon","native_claymore-wave","move_secondary_weapon"]:
  var expected=wave if slot in ["native_claymore-wave","move_secondary_weapon"] else swing
  check(game.sound_preview(9,slot)==expected,"Sound Studio previews the reused sample for "+slot)
 for index in 3:
  reset_cast();combat.combo=index;combat.combo_timer=1;combat.attack()
  combat.tick(.04,false)
  check(combat.sound.voices.any(func(v):return v.stream==swing and v.playing and v.pitch_scale==1.0),"Combo %d plays Lumina at source pitch"%index)
  quiet(game)
 lib.select_character(9);lib.custom["native_claymore-sweep"]=wave
 check(lib.playback_for(9,"move_primary_1_weapon",null).stream==wave,"Existing swing recordings still override the default")
 lib.custom.clear();lib.mutes["native_claymore-wave"]=true
 check(lib.playback_for(9,"move_secondary_weapon",null).muted,"Existing wave mute still applies")
 lib.mutes.clear()
 check(SoundLibrary.original_for(8,"native_claymore-sweep")==null and SoundLibrary.original_for(7,"native_claymore-wave")==null,"Shared event names do not replace Dragoon or Knight sounds")
