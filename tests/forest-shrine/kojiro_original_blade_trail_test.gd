extends SceneTree
const Trail=preload("res://scripts/recovered_leader_trail.gd")
var checks=0
var failures=0
class Owner extends Node:
 var game={"settings":{"reduced_flashes":true}}
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func run():
 var trail=Trail.new();trail.additive=true;trail.lifetime=16.0/30;trail.opacity=1;trail.light_color=Color(240.0/255,120.0/255,240.0/255);root.add_child(trail)
 var a=PackedVector3Array([Vector3(1,2,3),Vector3(1,4,3)]);var b=PackedVector3Array([Vector3(2,2,3),Vector3(2,4,3)])
 trail.advance(0,a,true,false);trail.advance(.03,b,true,false);trail.flush_mesh()
 var arrays=trail.mesh.surface_get_arrays(0)
 check(arrays[Mesh.ARRAY_VERTEX]==PackedVector3Array([a[0],a[1],b[1],a[0],b[1],b[0]]),"Original physical-blade quads remain exact")
 check(trail.material_override is StandardMaterial3D and trail.material_override.blend_mode==BaseMaterial3D.BLEND_MODE_ADD,"Original additive glow is restored")
 check(arrays[Mesh.ARRAY_COLOR][0].r>0.94 and arrays[Mesh.ARRAY_COLOR][0].g>0.47 and arrays[Mesh.ARRAY_COLOR][0].b>0.94,"Original pink-purple RGB is retained")
 check(absf(arrays[Mesh.ARRAY_COLOR][0].a-(1-.03/trail.lifetime))<=1.0/255,"Original per-sample alpha fade is retained")
 trail.advance(1,PackedVector3Array(),false,false)
 check(trail.mesh==null and trail.samples.is_empty(),"Original layer expires completely")
 var mesh_id=trail.prepared_mesh.get_instance_id();var material_id=trail.material_override.get_instance_id()
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 500:
  trail.advance(.016,a,true,false);trail.advance(.016,b,true,false);trail.flush_mesh();trail.advance(1,PackedVector3Array(),false,false)
 check(trail.prepared_mesh.get_instance_id()==mesh_id and trail.material_override.get_instance_id()==material_id,"Repeated original trails reuse their prepared mesh and material")
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Five hundred original trails retain no resources")
 trail.layers=0;trail.advance(.016,a,true,false)
 check(trail.samples.is_empty() and trail.mesh==null,"Hidden donors cannot leave an original blade trail")
 var owner=Owner.new();root.add_child(owner);trail.actor=owner;trail.layers=1
 trail.advance(0,a,true,false);trail.advance(.03,b,true,false)
 check(is_equal_approx(trail.material_override.albedo_color.a,.42),"Reduced flashes also subdue the original additive glow")
 owner.game.settings.reduced_flashes=false;trail.advance(0,PackedVector3Array(),false,false)
 check(is_equal_approx(trail.material_override.albedo_color.a,1.0),"Turning reduced flashes off restores original intensity")
 owner.queue_free();trail.queue_free();await process_frame
 print("KOJIRO_ORIGINAL_BLADE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
