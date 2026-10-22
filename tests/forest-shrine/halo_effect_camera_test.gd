extends SceneTree
## Native distance bands, timed camera offsets, alpha-zero lighten flashes and
## restoration exercise actual Camera3D and ActionCamera recoil state.
class GameFixture extends Node:
 var camera_rig:Node
 var player:Node
class HeroFixture extends Node3D:
 var master_chief_combat:Node
class CombatFixture extends Node:
 var native_fx:Node
var checks=0
var failures=0
var effects
var game
var hero:Node3D
var camera:Camera3D
var data
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func near(value:float,want:float,label_:String,tolerance:float=.0001):check(absf(value-want)<tolerance,label_+" (%s expected %s)"%[value,want])
func present():
 effects._process(0.0)
func run():
 check(ResourceLoader.exists("res://scripts/halo_effect_camera.gd"),"Native camera presentation helper exists")
 if failures:finish();return
 effects=load("res://scripts/halo_effect_camera.gd").new();root.add_child(effects);effects.set_process(false)
 game=GameFixture.new();root.add_child(game)
 hero=HeroFixture.new();root.add_child(hero);game.player=hero
 camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,2,0)
 game.camera_rig=ActionCamera.new();game.camera_rig.camera=camera;game.camera_rig.first_person_recoil=.02
 effects.configure(game,hero)
 data=load("res://scripts/halo_effect_data.gd").new()
 var native=data.resolve("weapons\\rocket launcher\\explosion","damage_effect")
 var base=camera.global_transform
 effects.emit(native,Vector3(4,0,0),3.0);effects.tick(0);present()
 var full=camera.global_position.distance_to(base.origin)
 near(full,.03490659967*3.048*3,"Rocket shake converts native translation at full inner-radius strength")
 check(effects.overlay.visible,"Native zero-duration explosion flash appears for one presentation frame")
 near(effects.flash_intensity,.7,"Explosion flash keeps native maximum intensity")
 var frame=camera.global_transform
 present()
 check(camera.global_transform.is_equal_approx(frame),"Repeated presentation without elapsed time never compounds shake")
 effects.tick(.75);present()
 near(camera.global_position.distance_to(base.origin),full*.5,"Native linear shake fades over its full1.5second duration")
 check(not effects.overlay.visible,"Zero-duration flash clears after its one native presentation frame")
 near(game.camera_rig.first_person_recoil,.02,"Native presentation never consumes or adds to weapon recoil")
 effects.tick(.8);present()
 check(camera.global_transform.is_equal_approx(base),"Expired native shake restores the exact camera pose")
 check(effects.live_count()==0,"Native camera states drain completely")
 effects.emit(native,Vector3(11.43,0,0),3.0);effects.tick(0);present()
 near(camera.global_position.distance_to(base.origin),full*.5,"Distance halfway between native inner/outer radii halves shake")
 effects.clear()
 effects.emit(native,Vector3(20,0,0),3.0);effects.tick(0);present()
 check(effects.live_count()==0 and camera.global_transform.is_equal_approx(base),"Explosion outside the scaled cutoff has no camera presentation")
 var shotgun=data.resolve("weapons\\shotgun\\trigger","damage_effect").duplicate(true)
 shotgun._local=true
 effects.emit(shotgun,Vector3(0,2,-1));effects.tick(0);present()
 check(camera.global_position.distance_to(base.origin)>0,"Owner-local zero-radius shotgun trigger retains its native timed translation shake")
 effects.tick(.1);present()
 check(camera.global_position.distance_to(base.origin)<.0325*3.048*.26,"Native late fade and wobble reduce shotgun shake by midpoint")
 effects.clear()
 var impulse={"radius":{"from":0,"to":0},"_local":true,"temporary_camera_impulse":{"duration":.2,"fade_function":"linear","rotation":.1,"pushback":.1,"jitter":{"from":0,"to":0}}}
 effects.emit(impulse,Vector3(0,0,-3));effects.tick(0);present()
 near(camera.global_position.z,.3048,"Native temporary pushback moves camera away from the event")
 check(not camera.global_basis.is_equal_approx(base.basis),"Native temporary impulse includes directional rotation")
 effects.tick(.1);present()
 near(camera.global_position.z,.1524,"Temporary pushback fades during authored duration")
 # The game camera can recompute its base pose between presentation frames.
 var moved=Transform3D(Basis(Vector3.UP,.2),Vector3(10,4,5));camera.global_transform=moved
 effects.tick(.02);present();effects.clear()
 check(camera.global_transform.is_equal_approx(moved),"Clear restores a newly recomputed camera pose without rewinding player movement")
 # Native lighten adds RGB even when the authored tint alpha is zero.
 var flash={"radius":{"from":0,"to":0},"_local":true,"screen_flash":{"type":"lighten","priority":"medium","duration":.4,"fade_function":"late","maximum_intensity":.5,"tint_lower_bound":{"a":0,"r":1,"g":0,"b":0}}}
 effects.emit(flash,hero.position);effects.tick(0);present()
 check(effects.overlay.visible,"Alpha-zero native lighten tint still draws RGB")
 near(effects.flash_intensity,.25,"Native screen flash evaluates fade at clipped intensity")
 effects.tick(.2);present()
 near(effects.flash_intensity,.0625,"Native late screen flash fades using remaining time and clipped strength")
 for i in 200:effects.emit(flash,hero.position)
 check(effects.live_count()<=3,"Repeated native damage presentation stays bounded to three channels")
 effects.clear()
 check(not effects.overlay.visible and effects.live_count()==0,"Clear removes screenflash and every timed camera channel")
 check(camera.global_transform.is_equal_approx(moved),"Cleared effect leaves no accumulated translation or rotation")
 if DisplayServer.get_name()!="headless":
  effects.emit(flash,hero.position);effects.tick(0);present();await process_frame;await process_frame
  effects.clear()
 var adapter=load("res://scripts/halo_weapon_effects.gd").new();adapter.configure(game,hero);root.add_child(adapter);adapter.set_process(false);adapter.camera_effects.set_process(false)
 adapter._camera_effect(native,{"transform":Transform3D(Basis.IDENTITY,Vector3(4,0,0)),"scale":3.0,"camera":"world"})
 adapter.camera_effects.tick(0);adapter.camera_effects._process(0)
 var adapter_full=camera.global_position.distance_to(moved.origin)
 adapter.advance(.75);adapter.camera_effects._process(0)
 near(camera.global_position.distance_to(moved.origin),adapter_full*.5,"Adapter advance progresses the native camera timeline")
 adapter.clear()
 check(camera.global_transform.is_equal_approx(moved),"Adapter clear restores camera without leaving its presentation offset")
 var combat=CombatFixture.new();hero.master_chief_combat=combat;combat.native_fx=adapter
 var fp=load("res://scripts/halo_weapon_effects.gd").new();fp.configure(game,hero,camera,2);root.add_child(fp);fp.set_process(false);fp.camera_effects.set_process(false)
 adapter._camera_effect(native,{"transform":Transform3D(Basis.IDENTITY,Vector3(4,0,0)),"scale":3.0,"camera":"world"})
 adapter.camera_effects.tick(0);adapter.camera_effects._process(0)
 fp._camera_effect(shotgun,{"transform":Transform3D(Basis.IDENTITY,Vector3(.1,-.1,-.8)),"scale":1.0,"camera":"first_person"})
 fp.camera_effects.tick(0);fp.camera_effects._process(0)
 check(fp.camera_effects.live_count()==0,"First-person firing delegates presentation to the actual world camera owner")
 adapter.camera_effects._process(0)
 adapter.clear();fp.clear()
 check(camera.global_transform.is_equal_approx(moved),"Firing plus explosion cancellation restores exact pose when world adapter clears first")
 fp.free();combat.free();hero.master_chief_combat=null;adapter.free()
 effects.free();game.camera_rig.free();game.free();hero.free();camera.free();data=null;finish()
func finish():
 await process_frame;await process_frame
 print("HALO_EFFECT_CAMERA_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
