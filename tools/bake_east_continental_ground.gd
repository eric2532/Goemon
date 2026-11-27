extends SceneTree
## Offline use of the same owner, with exact serialized-array preservation checks.
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Cache=preload("res://scripts/forest/forest_east_ground_cache.gd")
const REPORT="res://build/Other Files/Asset Toolkit/East Gate Region/Continental Ground/"
var reports=[]
func _initialize():
 create_timer(1800,true,false,true).timeout.connect(func():printerr("EAST_GROUND_BAKE_TIMEOUT");quit(1))
 run.call_deferred()

func fingerprint(stage:Node3D)->String:
 var hash_=HashingContext.new();hash_.start(HashingContext.HASH_SHA256)
 for child in stage.get_children():
  assert(child is MeshInstance3D)
  hash_.update(var_to_bytes(child.transform))
  for surface in child.mesh.get_surface_count():
   var arrays:Array=child.mesh.surface_get_arrays(surface)
   for index in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV]:hash_.update(arrays[index].to_byte_array())
   var material:ShaderMaterial=child.get_active_material(surface)
   var texture:Texture2D=material.get_shader_parameter("base_texture")
   hash_.update(var_to_bytes([child.mesh.surface_get_primitive_type(surface),material.shader.resource_path,texture.resource_path]))
   for parameter in ["use_base_texture","use_vertex_color","base_color","surface_kind","alpha_cutout","original_palette","atlas_tile_pixels"]:
    hash_.update(var_to_bytes(material.get_shader_parameter(parameter)))
 return hash_.finish().hex_encode()

func differences(a:Node3D,b:Node3D)->Array:
 var result=[]
 if a.get_child_count()!=b.get_child_count():return ["Different chunk counts"]
 for i in a.get_child_count():
  var before:MeshInstance3D=a.get_child(i);var after:MeshInstance3D=b.get_child(i)
  if var_to_bytes(before.transform)!=var_to_bytes(after.transform):result.append([i,"transform_bytes",var_to_str(before.transform),var_to_str(after.transform),var_to_bytes(before.transform).hex_encode(),var_to_bytes(after.transform).hex_encode()])
  for surface in before.mesh.get_surface_count():
   var first:Array=before.mesh.surface_get_arrays(surface);var second:Array=after.mesh.surface_get_arrays(surface)
   for index in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV]:
    if first[index].to_byte_array()!=second[index].to_byte_array():result.append([i,"array",index,first[index].size(),second[index].size()])
   var m:ShaderMaterial=before.get_active_material(surface);var n:ShaderMaterial=after.get_active_material(surface)
   if m.shader.resource_path!=n.shader.resource_path:result.append([i,"shader",m.shader.resource_path,n.shader.resource_path])
   if before.mesh.surface_get_primitive_type(surface)!=after.mesh.surface_get_primitive_type(surface):result.append([i,"primitive"])
   for parameter in ["base_texture","use_base_texture","use_vertex_color","base_color","surface_kind","alpha_cutout","original_palette","atlas_tile_pixels"]:
    var left=m.get_shader_parameter(parameter);var right=n.get_shader_parameter(parameter)
    if left is Resource and right is Resource:
     if left.resource_path!=right.resource_path:result.append([i,parameter,left.resource_path,right.resource_path])
    elif var_to_bytes(left)!=var_to_bytes(right):result.append([i,parameter,var_to_str(left),var_to_str(right),typeof(left),typeof(right)])
  if result.size()>=12:break
 return result

func descriptors(stage:Node3D)->Array:
 var result=[]
 for child in stage.get_children():
  var material:ShaderMaterial=child.get_active_material(0)
  var texture:Texture2D=material.get_shader_parameter("base_texture")
  var row={"transform":var_to_bytes(child.transform).hex_encode(),"shader":material.shader.resource_path,"texture":texture.resource_path}
  for parameter in ["use_base_texture","use_vertex_color","base_color","surface_kind","alpha_cutout","original_palette","atlas_tile_pixels"]:
   row[parameter]=var_to_bytes(material.get_shader_parameter(parameter)).hex_encode()
  result.append(row)
 return result

func run():
 Cache.baking=true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Cache.ROOT))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT+"Candidates"))
 for script in [Maps,Maps.Art,Maps.Forms,Maps.Forms.Source,load("res://scripts/forest/forest_east_region_art.gd")]:
  if script.get_source_code().sha256_text()!=FileAccess.get_sha256(script.resource_path):
   printerr("EAST_GROUND_BAKE_SOURCE_CHANGED_DURING_SCRIPT_LOAD ",script.resource_path);quit(1);return
 var inputs=Cache.signature()
 for source in [33000,43000]:
  var started=Time.get_ticks_usec();var original=Node3D.new();root.add_child(original)
  Maps.build(original,Maps.runtime_id(source))
  var stage=Node3D.new();stage.name="RecoveredEastGroundCache"
  for child in original.get_children():
   if not child.get_meta("original_ground_batch",false):continue
   original.remove_child(child);stage.add_child(child);child.owner=stage
  assert(stage.get_child_count()>0)
  var expected=fingerprint(stage)
  var before_descriptors=descriptors(stage)
  var scene=PackedScene.new();assert(scene.pack(stage)==OK)
  var path=REPORT+"Candidates/"+str(source)+".scn"
  assert(ResourceSaver.save(scene,path,ResourceSaver.FLAG_COMPRESS)==OK)
  var reloaded:PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
  var restored:Node3D=reloaded.instantiate()
  if fingerprint(restored)!=expected or inputs!=Cache.signature():
   var failure=FileAccess.open(REPORT+str(source)+"-failed-preservation.json",FileAccess.WRITE)
   failure.store_string(JSON.stringify({"differences":differences(stage,restored),"source_changed":inputs!=Cache.signature(),"before_descriptors":before_descriptors,"after_descriptors":descriptors(restored),"original_after_save_fingerprint":fingerprint(stage),"expected_fingerprint":expected,"reloaded_fingerprint":fingerprint(restored)},"  "));failure.close()
   printerr("EAST_GROUND_BAKE_FAILED_PRESERVATION source=",source)
   restored.free();stage.free();original.free();quit(1);return
  var destination=Cache.ROOT+str(source)+".scn"
  assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(destination+".part"))==OK)
  assert(DirAccess.rename_absolute(ProjectSettings.globalize_path(destination+".part"),ProjectSettings.globalize_path(destination))==OK)
  var state=Maps.state(Maps.runtime_id(source));var first_plane=0
  var openings:Array=original.get_meta("recovered_floor_openings")
  var aliases:Dictionary=Maps.Art.data().maps[Maps.path_for(Maps.runtime_id(source))].get("graphic_aliases",{})
  for i in state.size.x*state.size.y:
   var serial=state.raw.decode_u16(20+i*2)
   if serial==0 or Vector2i(i%state.size.x,i/state.size.x) in openings:continue
   var graphic:Dictionary=Maps.Art.data().graphics[str(int(aliases.get(str(serial),serial)))]
   if graphic.family!="void":first_plane+=1
  var record={"source":source,"inputs":inputs,"scene_sha256":FileAccess.get_sha256(path),"geometry_sha256":expected,"batches":stage.get_child_count(),"floor_placements":original.get_meta("recovered_floor_placements"),"plane0_floor_placements":first_plane,"source_placements":original.get_meta("recovered_source_placements"),"checks":2,"failures":0,"bake_ms":(Time.get_ticks_usec()-started)/1000.,"scope":"Every source ground chunk serialized and reloaded with identical vertex, normal, UV, transform, primitive and shader/texture-path fingerprints. Static and native collision remain with the existing runtime owner."}
  var manifest=Cache.ROOT+str(source)+".json"
  var file=FileAccess.open(manifest+".part",FileAccess.WRITE);file.store_string(JSON.stringify(record,"  "));file.close()
  assert(DirAccess.rename_absolute(ProjectSettings.globalize_path(manifest+".part"),ProjectSettings.globalize_path(manifest))==OK)
  reports.append(record);print("EAST_GROUND_BAKED source=",source," batches=",stage.get_child_count()," floor_placements=",record.floor_placements)
  restored.free();stage.free();original.free()
  for i in 4:await process_frame
 var report=FileAccess.open(REPORT+"preservation.json",FileAccess.WRITE);report.store_string(JSON.stringify({"maps":reports,"checks":reports.size()*2,"failures":0},"  "));report.close()
 print("EAST_GROUND_BAKE_RESULT checks=",reports.size()*2," failures=0")
 quit()
