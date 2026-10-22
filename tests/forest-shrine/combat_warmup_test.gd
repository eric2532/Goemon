extends SceneTree
var checks=0
var failures=0
func _initialize():
 create_timer(60).timeout.connect(func():printerr("FAIL: combat warmup timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func run():
 var path="res://scripts/forest/forest_combat_warmup.gd"
 check(ResourceLoader.exists(path),"Forest prepares first-use combat graphics before an army's initial clash")
 if failures:finish();return
 var warmup=load(path).new();root.add_child(warmup)
 if not warmup.complete:await warmup.finished
 await process_frame
 check(warmup.complete and warmup.get_child_count()==0,"Graphics warmup finishes and releases its isolated viewport")
 var world=Node3D.new();root.add_child(world)
 seed(90824);var expected=randf();seed(90824)
 warmup.populate_samples(world)
 check(randf()==expected,"Preparing combat graphics preserves the gameplay random stream")
 var meshes=world.find_children("*","MeshInstance3D",true,false);var shaders={};var additive=false;var mixed=false;var ranger_ribbon=false
 for mesh in meshes:
  var material=mesh.material_override
  if material is ShaderMaterial:
   shaders[material.shader.resource_path]=true
   if material.shader.resource_path.ends_with("magic_ink_brush.gdshader") and mesh.mesh is ArrayMesh:
    var format=mesh.mesh.surface_get_format(0)
    ranger_ribbon=ranger_ribbon or (format&Mesh.ARRAY_FORMAT_COLOR!=0 and format&Mesh.ARRAY_FORMAT_NORMAL==0 and material.get_shader_parameter("use_vertex_alpha")==true)
  if material is StandardMaterial3D:
   additive=additive or material.blend_mode==BaseMaterial3D.BLEND_MODE_ADD
   mixed=mixed or material.blend_mode==BaseMaterial3D.BLEND_MODE_MIX
 check(shaders.has("res://assets/rogue/shaders/magic_ink_brush.gdshader"),"The actual blade ribbons and projectile pigment are prepared")
 check(ranger_ribbon,"The army Ranger ribbon's vertex-color mesh variant is prepared")
 check(shaders.has("res://assets/rogue/shaders/dragoon_energy.gdshader"),"Dragoon's actual 3D dragon shader is prepared")
 check(additive and mixed,"Ninja's additive and mixed finishing effects are both prepared")
 for role in [0,1,3]:
  var unit=world.get_node_or_null("WarmSoldier_%d"%role)
  check(unit is MultiMeshInstance3D and unit.multimesh.use_custom_data and unit.multimesh.mesh is ArrayMesh,"The actual batched soldier material/geometry variant is rendered at load (%d)"%role)
 check(world.get_node_or_null("WarmSoldierBullet")!=null and world.get_node_or_null("WarmSoldierCasing")!=null,"Original bullet skinning and casing graphics are prepared before the first gunshot")
 var sparks=world.find_children("*","MultiMeshInstance3D",true,false)
 check(sparks.any(func(node):return node.material_override is ShaderMaterial and node.material_override.shader.resource_path.ends_with("energy_sparks.gdshader")),"The instanced impact-spark graphics are prepared")
 check(world.find_children("*","CollisionObject3D",true,false).is_empty() and world.find_children("*","AudioStreamPlayer",true,false).is_empty(),"Warmup samples contain no collision bodies or playing combat sounds")
 world.queue_free();warmup.queue_free()
 for i in 8:await process_frame
 await create_timer(.35).timeout;finish()
func finish():
 print("COMBAT_WARMUP_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
