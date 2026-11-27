extends SceneTree
## Exact minimum-depth/cache-key regression, plus unchanged canonical4m geometry.
const Live=preload("res://scripts/forest/forest_east_bank_caps.gd")
const Before=preload("res://build/Other Files/Asset Toolkit/East Gate Region/Bank Caps/Body Material Candidate/bank_caps_before.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Bank Caps/Body Material Candidate/"
var checks=0
var errors=[]
func _initialize():
 create_timer(180,true,false,true).timeout.connect(func():printerr("BANK_TEN_CM_TIMEOUT");quit(2));run.call_deferred()
func check(okay:bool,label:String):
 checks+=1
 if not okay:errors.append(label);printerr("BANK_DEPTH_FAIL ",label)
func material_key(material:ShaderMaterial)->Array:
 var result=[material.shader.code]
 for parameter:Dictionary in material.shader.get_shader_uniform_list():
  var value=material.get_shader_parameter(parameter.name)
  result.append([parameter.name,value.resource_path if value is Resource else value])
 return result
func run():
 var before=Fresh.snapshot([get_script().resource_path,"scripts/forest/forest_east_bank_caps.gd",OUT+"bank_caps_before.gd","assets/maps/falan/east_region/bank_caps/data.json","assets/maps/falan/east_region/bank_caps/surfaces.png"]);var rows=[]
 check(FileAccess.get_sha256(OUT+"bank_caps_before.gd")=="682c0b0e6656f2e3d7e27faf0110e014918d6f3f8aa6b4dd47f4693a4cc2dc4c","Frozen comparison is the published before-guard helper")
 for serial in range(12500,12536):
  var mesh=Live.mesh(serial,.100);check(mesh!=null and mesh.get_surface_count()==2,"Exact0.100cache depth creates both native/body surfaces "+str(serial))
  if mesh==null:continue
  var bounds=mesh.get_aabb();var arrays:Array=mesh.get_meta("source_surface_arrays_all");var finite=true;var vertices=0
  for surface:Array in arrays:
   for point:Vector3 in surface[Mesh.ARRAY_VERTEX]:finite=finite and point.is_finite();vertices+=1
   for channel in [Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
    if surface[channel]!=null:
     for value in surface[channel]:finite=finite and value.is_finite()
   if surface[Mesh.ARRAY_INDEX]!=null:
    for index:int in surface[Mesh.ARRAY_INDEX]:finite=finite and index>=0 and index<surface[Mesh.ARRAY_VERTEX].size()
  check(finite and vertices>0,"Finite indexed native/body channels "+str(serial))
  check(absf(bounds.position.y+.1)<.01 and absf(bounds.end.y)<.01,"Exact10cm independent continuation depth "+str(serial))
  var old=Before.mesh(serial,4.);var current=Live.mesh(serial,4.)
  check(var_to_bytes(old.get_meta("source_surface_arrays_all"))==var_to_bytes(current.get_meta("source_surface_arrays_all")),"Canonical4m packed geometry and attributes unchanged "+str(serial))
  for surface in 2:check(material_key(old.surface_get_material(surface))==material_key(current.surface_get_material(surface)),"Canonical4m surface material unchanged %s/%s"%[serial,surface])
  check(bounds.position.x==current.get_aabb().position.x and bounds.position.z==current.get_aabb().position.z and bounds.size.x==current.get_aabb().size.x and bounds.size.z==current.get_aabb().size.z,"Minimum depth preserves nativeXZ footprint "+str(serial))
  rows.append({"serial":serial,"bounds":str(bounds),"vertices":vertices})
 var changed=Fresh.changed(before);check(changed.is_empty(),"Minimum depth proof sources stayed current")
 var file=FileAccess.open(OUT+"ten-centimetre-proof.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":errors.size(),"failed":errors,"forms":rows,"source_hashes":before,"source_changed":changed,"scope":"Guard-only minimum0.100depth regression across all36forms, with exact canonical4m arrays/materials. No source geometry/nativefront/support/walk changes. Actual scene visual acceptance remains separate."},"  "));file.close()
 print("BANK_TEN_CM checks=",checks," failures=",errors.size());quit(1 if not errors.is_empty() else 0)
