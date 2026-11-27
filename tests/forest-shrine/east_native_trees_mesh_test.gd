extends SceneTree
const Trees=preload("res://scripts/forest/forest_east_native_trees.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Tree Families/Typed27/meshes.json"
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label);push_error(label)
func run():
 Trees.Base.Art.load_east();var rows=[];var before={};var source_hashes={}
 for path in ["res://scripts/forest/forest_east_native_trees.gd",Trees.ROOT+"data.json"]:source_hashes[path]=FileAccess.get_sha256(path)
 for master:Dictionary in Trees.data().masters.values():
  for part in Trees.Base.Meadow.source(master.asset):
   for slot in part.mesh.get_surface_count():
    var material:Material=part.material if part.material!=null else part.mesh.surface_get_material(slot)
    if material is StandardMaterial3D:before[material]=[material.albedo_color,material.albedo_texture]
 var private_canopies=[];var vertices=0
 for token in Trees.data().graphics:
  var serial=int(token);var g:Dictionary=Trees.Base.Art.data().graphics[token];var result:Mesh=Trees.mesh(serial,g);var spec:Dictionary=Trees.data().graphics[token]
  check(Trees.mesh(serial,g)==result,"Per-ID immutable mesh cache "+token)
  var low=Vector2(INF,INF);var high=Vector2(-INF,-INF);var actual_arrays:Array=result.get_meta("east_cpu_arrays")
  var traced=spec.get("kind","")=="native_canopy_tree";var native_arrays:Array=[]
  if not traced:
   var master:Mesh=Trees.master(spec.asset);native_arrays=master.get_meta("east_cpu_arrays")
   check(actual_arrays.size()==native_arrays.size(),"Whole-master surfaces retained "+token)
  else:check(spec.branch_segments>0 and spec.crown_junction.size()==2,"Source-traced trunk/tier contract "+token)
  for slot in actual_arrays.size():
   var arrays:Array=actual_arrays[slot]
   if not traced:check(arrays[Mesh.ARRAY_TEX_UV]==native_arrays[slot][Mesh.ARRAY_TEX_UV] and arrays[Mesh.ARRAY_INDEX]==native_arrays[slot][Mesh.ARRAY_INDEX],"Whole-master UV/index unchanged "+token+" "+str(slot))
   for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
    vertices+=1
    if not p.is_finite():check(false,"Finite tree geometry "+token);break
    var raw=Vector3(p.x,p.y/Trees.Base.OWNER_Y_SCALE,p.z)
    var pixel=Vector2((raw.x+raw.z)*Trees.Base.Fit.HORIZONTAL,(raw.z-raw.x)*8.-raw.y*Trees.Base.Fit.VERTICAL)
    low=low.min(pixel);high=high.max(pixel)
   if not traced and Trees.canopy_surfaces[spec.asset][slot]:
    var material:Material=result.surface_get_material(slot)
    check(material is ShaderMaterial and material.get_shader_parameter("source_cutout")==true,"Private source-alpha foliage shader "+token)
    check(material not in private_canopies,"No shared mutable per-ID canopy material "+token);private_canopies.append(material)
  var error:Variant=null
  if not traced:
   var target:Rect2=result.get_meta("east_tree_target");error=maxf(low.distance_to(target.position),high.distance_to(target.end))
   check(error<.03,"Source rectangle fitted before ownerY adaptation "+token)
  var bounds=result.get_aabb()
  if traced:
   var foot=Trees.Base.projected(Vector2((spec.visible[0]+spec.visible[2])*.5,float(spec.visible[3])-2.),g,0.,float(spec.ground_offset))
   check(absf(foot.y)<.001,"Native painted foot remains onoriginal ground "+token)
  else:check(absf(bounds.position.y)<.15,"Original ground contact retained "+token)
  rows.append({"graphic":serial,"kind":spec.get("kind","whole_master_tree"),"asset":spec.asset,"source_fit_error_pixels":error,"owner_bounds":var_to_str(bounds),"foliage_tint":spec.foliage_tint,"bark_tint":spec.bark_tint})
 for material in before:check(material.albedo_color==before[material][0] and material.albedo_texture==before[material][1],"Original shared master material unchanged")
 for path in source_hashes:check(FileAccess.get_sha256(path)==source_hashes[path],"Input remained frozen "+path)
 var file=FileAccess.open(OUT,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"vertices":vertices,"graphics":rows,"source_hashes":source_hashes,"scope":"Headless geometry/source-fit/material-isolation checks only. Private27candidate has no runtime hook and requires rendered silhouette/tint review."},"  "));file.close()
 print("EAST_NATIVE_TREES_MESHES graphics=",rows.size()," vertices=",vertices," checks=",checks," failures=",failures.size());quit(failures.size())
