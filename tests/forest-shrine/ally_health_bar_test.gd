extends SceneTree
const Unit=preload("res://scripts/forest/explorer_helper_unit.gd")
class FakeGame extends Node:
 var model={"phase":"wave"}
 var camera_rig={}
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func _initialize():run.call_deferred()
func run():
 var a=Unit.new();var b=Unit.new()
 check(a.has_method("_create_health_display"),"Health bars can be initialized independently of ally combat models")
 if failures:a.free();b.free();quit(1);return
 var camera=Camera3D.new();root.add_child(camera);camera.rotation=Vector3(.2,.4,0)
 var game=FakeGame.new();root.add_child(game);game.camera_rig.camera=camera
 for unit in [a,b]:
  unit.game=game;unit._create_health_display();unit.remove_child(unit.health_display);root.add_child(unit.health_display)
  unit.state="acting";unit.max_hp=200;unit.hp=200;unit.update_health_display()
 var back_a=a.health_display.get_child(0);var back_b=b.health_display.get_child(0)
 check(back_a.mesh==back_b.mesh and a.health_fill.mesh==b.health_fill.mesh,"Allies share the two immutable health-bar meshes")
 check(back_a.material_override==back_b.material_override and a.health_fill.material_override==b.health_fill.material_override,"Allies share the two immutable health-bar materials")
 check(back_a.mesh!=a.health_fill.mesh and back_a.material_override!=a.health_fill.material_override,"Background and fill retain separate authored resources")
 check(back_a.mesh.size==Vector3(1.85,.22,.04) and a.health_fill.mesh.size==Vector3(1.7,.12,.04),"Original bar dimensions are preserved")
 check(back_a.material_override.albedo_color==Color("142b2b") and a.health_fill.material_override.albedo_color==Color("8ae1ac") and back_a.material_override.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED,"Original unshaded health colors are preserved")
 a.hp=50;a.update_health_display()
 check(is_equal_approx(a.health_fill.scale.x,.25) and is_equal_approx(a.health_fill.position.x,-.6375) and a.health_text.text=="50 / 200","Damage changes only the owning bar fill and health text")
 check(b.health_fill.scale.x==1 and b.health_fill.position.x==0 and b.health_text.text=="200 / 200","A sibling health bar remains full and unchanged")
 check(a.health_display.global_basis.is_equal_approx(camera.global_basis.orthonormalized()),"Each display preserves camera-facing orientation")
 a.state="idle";a.update_health_display()
 check(not a.health_display.visible and b.health_display.visible,"Parking one ally hides only its own display")
 a.state="acting";a.hp=0;a.update_health_display()
 check(not a.health_display.visible,"A dead ally's display remains hidden")
 a.hp=200;a.update_health_display()
 check(a.health_display.visible and a.health_fill.scale.x==1 and a.health_text.text=="200 / 200","A reused healed ally restores its independent full bar")
 var shared_mesh=b.health_fill.mesh;a.health_display.free();a.free()
 check(b.health_fill.mesh==shared_mesh and b.health_display.visible,"Disposing one ally leaves sibling bar resources valid")
 b.health_display.free();b.free();game.free();camera.free()
 print("ALLY_HEALTH_BAR_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
