extends SceneTree
const Actor=preload("res://assets/rogue/scripts/actor.gd")
const Renderer=preload("res://scripts/forest/ally_rigid_renderer.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 var camera=Camera3D.new();root.add_child(camera);camera.current=true
 var renderer=Renderer.new();root.add_child(renderer);renderer.set_process(false)
 var near_=Actor.new();root.add_child(near_);near_.setup("ranger");near_.position=Vector3(0,0,-3)
 var far_=Actor.new();root.add_child(far_);far_.setup("ranger");far_.position=Vector3(0,0,-100)
 renderer.register_actor(near_);renderer.register_actor(far_)
 var group=renderer.groups.values()[0]
 var near_mesh=group.entries[0].source.get_ref();var far_mesh=group.entries[1].source.get_ref()
 var original_mesh=near_mesh.mesh;var original_lods=original_mesh.get("_surfaces").map(func(surface):return surface.get("lods",[]))
 var original_bounds=near_mesh.get_aabb();var original_bias=near_mesh.lod_bias
 renderer.sync()
 check(original_lods.any(func(lods):return not lods.is_empty()),"Equipped imported meshes contain real generated distance LODs")
 check(near_mesh.mesh==original_mesh and far_mesh.mesh==original_mesh,"Mixed-distance equipment preserves original native mesh identity")
 check(near_mesh.layers==1 and far_mesh.layers==1 and renderer.get_child_count()==0,"Individual native geometry retains separate culling and LOD decisions")
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=20;far_.scale=Vector3.ONE*.01;renderer.sync()
 check(near_mesh.get_aabb()==original_bounds and near_mesh.lod_bias==original_bias and far_mesh.lod_bias==original_bias,"Orthographic scale changes preserve native bounds and detail bias")
 check(original_mesh.get("_surfaces").map(func(surface):return surface.get("lods",[]))==original_lods,"All imported LOD index data stays untouched")
 check(far_.scale==Vector3.ONE*.01 and near_mesh.mesh==far_mesh.mesh,"Native source transforms preserve independently scaled equipment")
 renderer.set_enabled(false)
 check(near_mesh.layers==1 and far_mesh.layers==1,"Disabling material sharing leaves all original render layers intact")
 renderer.free();near_.free();far_.free();camera.free()
 print("ALLY_RIGID_LOD_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
