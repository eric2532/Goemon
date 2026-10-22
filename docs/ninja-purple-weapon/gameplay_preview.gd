extends SceneTree
var game
var failures=0
var checks=0
var config_path="user://ninja-weapon-preview-%d.cfg"%OS.get_process_id()
var folder=ProjectSettings.globalize_path("res://docs/ninja-purple-weapon")
func _initialize():run.call_deferred()
func frames(n=4):
 for i in n:await process_frame
func check(ok: bool,note: String):
 checks+=1
 print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func shot(label_: String,offset: Vector3,height: float=1.5):
 game.camera_rig.camera.position=game.player.position+offset
 game.camera_rig.camera.look_at(game.player.position+Vector3.UP*height)
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(folder+"/game-"+label_+".png")==OK,"Native Ninja capture: "+label_)
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path
 root.add_child(game);current_scene=game
 await frames();game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.player.select_character(5);game.player.set_auto_attack(false)
 game.player.position=Vector3(0,.05,70);game.player.velocity=Vector3.ZERO;game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
 game.player.facing=Vector3.FORWARD;game.camera_rig.yaw=0
 game.model.update_vision(game.player.position);game.world.update_fog()
 var c=game.player.active_ability;c.reset_run()
 for i in 20:c._move_body(1.0/60)
 c.player.pos=game.player.position;c.player.angle=PI;c.aim=game.player.position+Vector3.FORWARD*30
 c._animate(0,0)
 var weapon: Node3D=c.visual_actor.joints.Weapon_Cutlass.node
 var mesh=weapon.find_child("Weapon_Cutlass_Geometry",true,false)
 check(mesh is MeshInstance3D,"Updated weapon imports as the existing Ninja weapon node")
 var has_purple=false
 for i in mesh.mesh.get_surface_count():
  var mat=mesh.mesh.surface_get_material(i)
  if mat!=null and "Purple_handle" in mat.resource_name:has_purple=true
 check(has_purple,"Live game loads the new purple handle material")
 for view in [["front",Vector3(0,2.1,-6)],["side",Vector3(6,2.1,0)],["three-quarter",Vector3(4,2.5,-5)],["back",Vector3(0,2.1,6)]]:
  await shot(view[0],view[1])
 for stage in range(3):
  c.player.attack=null;c.player.cooldowns.cutlass=0;c.combo=stage;c.combo_timer=1;c.attack()
  var a: Dictionary=c.player.attack;a.time=a.contact
  c._animate(0,0)
  var rig=c.visual_actor.cosplay_rig
  var hand: Vector3=rig.skeleton.global_transform*rig.pose("Hand_R").origin
  check(weapon.global_position.distance_to(hand)<.005,"New weapon stays attached to the attacking hand (stage %d)"%(stage+1))
  await shot("attack-%d"%(stage+1),Vector3(3.2,2.2,-4),1.25)
 game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 game.queue_free();paused=false;await frames();await create_timer(.35).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("NINJA_WEAPON_NATIVE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
