extends SceneTree
## Catches generic stone/wood fallbacks, lost authored surface tags, and terrain
## misclassification while exercising the actual forest collider constructors.
const Art=preload("res://scripts/forest/forest_art.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const World=preload("res://scripts/forest/forest_world.gd")
var checks=0
var failures=0
var resolver
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func material(body,position_=Vector3.ZERO,extra:Dictionary={})->String:
 var hit={"collider":body,"position":position_,"normal":Vector3.UP,"shape":0,"face_index":-1}
 hit.merge(extra,true)
 return resolver.resolve(hit)
func run():
 check(ResourceLoader.exists("res://scripts/halo_impact_material.gd"),"Halo impact material resolver exists")
 if failures:finish();return
 resolver=load("res://scripts/halo_impact_material.gd")
 var parent=Node3D.new();root.add_child(parent)
 var body=Art.solid(parent,Vector3.ZERO,Vector3.ONE)
 check(material(body)=="stone","Unknown solid geometry has a safe stone fallback")
 for name_ in ["dirt","sand","stone","wood","metal_hollow","metal_thin","metal_thick","water","glass","leaves","human_skin"]:
  body.set_meta("halo_material",name_)
  check(material(body)==name_,"Authored %s keeps its native response"%name_)
 body.set_meta("halo_material","unknown")
 check(material(body)=="stone","Invalid metadata does not escape as an unknown native response")
 body.remove_meta("halo_material");body.name="Anything"
 check(material(body)=="stone","Arbitrary collider names never imply wood")
 parent.set_meta("halo_material","wood")
 check(material(body)=="wood","Imported child colliders inherit authored parent materials")
 body.set_meta("halo_material","metal_thin")
 check(material(body)=="metal_thin","Collider tag overrides inherited material")
 var shared=StaticBody3D.new();parent.add_child(shared)
 var wood_owner=Node3D.new();wood_owner.set_meta("halo_material","wood");shared.add_child(wood_owner)
 var metal_owner=Node3D.new();metal_owner.set_meta("halo_material","metal_thin");shared.add_child(metal_owner)
 var wood_id=shared.create_shape_owner(wood_owner);var metal_id=shared.create_shape_owner(metal_owner)
 shared.shape_owner_add_shape(wood_id,BoxShape3D.new());shared.shape_owner_add_shape(metal_id,BoxShape3D.new());shared.shape_owner_add_shape(wood_id,BoxShape3D.new())
 check(material(shared,Vector3.ZERO,{"shape":1})=="metal_thin","Interleaved shape owners retain each shape's authored material")
 check(material(shared,Vector3.ZERO,{"shape":2})=="wood","Later shape of the first owner retains wood")
 shared.free()
 var enemy=Ninja.new()
 check(resolver.resolve({"collider":body},enemy)=="human_skin","Goemon targets use native flesh even in front of metal")
 enemy.free();parent.remove_meta("halo_material")
 body.free()
 check(resolver.resolve({})=="stone","An empty or missed ray defaults safely")
 var stale=StaticBody3D.new();stale.free()
 check(resolver.resolve({"collider":stale})=="stone","A freed collider defaults safely")
 for kind in ["wall","gate","tower","shrine","mine"]:
  var structure=Art.building({"id":1,"kind":kind,"rotation":0});parent.add_child(structure)
  for collider in structure.find_children("*","StaticBody3D",true,false):
   check(material(collider)=="stone","Actual %s collider uses its stone geometry"%kind)
  structure.free()
 var world=World.new();world.model=Model.new();world.model.reset(42,{})
 world.model.trees={Vector2i(12,12):1.0};world.make_forest()
 check(material(world.forest_root.get_children().filter(func(n):return n is StaticBody3D)[0])=="wood","Actual forest tree collider has wood metadata")
 var ground=Art.solid(parent,Vector3.ZERO,Vector3.ONE)
 ground.set_meta("halo_ground_model",world.model);ground.set_meta("halo_material","leaves")
 world.model.roads={Vector2i(0,0):true}
 check(material(ground,Vector3.ZERO)=="dirt","Road hash lookup selects dirt over grass ground")
 check(material(ground,Vector3(72,0,72))=="leaves","Grass outside a road uses native grass effects")
 # Native face indices are triangle indices spanning mesh surfaces.
 ground.remove_meta("halo_ground_model");ground.set_meta("halo_face_materials",[{"end":2,"material":"wood"},{"end":5,"material":"dirt"}])
 check(material(ground,Vector3.ZERO,{"face_index":1})=="wood","Last triangle of a wood surface retains wood")
 check(material(ground,Vector3.ZERO,{"face_index":2})=="dirt","First triangle of the next surface uses the next material")
 check(material(ground,Vector3.ZERO,{"face_index":8})=="leaves","Invalid face index preserves authored fallback")
 var kai_body=StaticBody3D.new();parent.add_child(kai_body)
 var native_mesh=load("res://assets/maps/kai_highway/terrain.res")
 resolver.tag_terrain(kai_body,world.model,native_mesh)
 # Away from the origin road, each known native surface resolves through its
 # real baked triangle offset; expectations come from the source texture tiles.
 var first=0
 for slot in native_mesh.get_surface_count():
  var texture=native_mesh.surface_get_material(slot).get_shader_parameter("albedo_texture").resource_path.get_file()
  var wants={"grass.png":"leaves","texture_09003000_32x64.png":"leaves","earth.png":"dirt","texture_0a003000_32x64.png":"wood","texture_0a00d000_32x64.png":"wood"}
  if wants.has(texture):check(material(kai_body,Vector3(72,0,72),{"face_index":first})==wants[texture],"Native terrain %s selects %s"%[texture,wants[texture]])
  var arrays=native_mesh.surface_get_arrays(slot)
  first+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
 ground.free();world.free();parent.free();finish()
func finish():
 await process_frame;await process_frame
 print("HALO_IMPACT_MATERIAL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
