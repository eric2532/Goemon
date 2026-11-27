extends SceneTree
const RootTree=preload("res://scripts/forest/forest_east_root_compounds.gd")
func _initialize():run.call_deferred()
func run():
 RootTree.Base.Art.load_east()
 var mesh:Mesh=RootTree.mesh();var rows=[]
 for slot in mesh.get_surface_count():
  var arrays:Array=mesh.get_meta("east_cpu_arrays")[slot];var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var material:ShaderMaterial=mesh.surface_get_material(slot);var texture:Variant=material.get_shader_parameter("base_texture");var triangles=[];var bounds=AABB();var first=true
  for start in range(0,points.size(),3):
   if maxf(points[start].y,maxf(points[start+1].y,points[start+2].y))<11.:continue
   var tri=[]
   for corner in 3:
    var p:Vector3=points[start+corner];tri.append([p.x,p.y,p.z]);bounds=AABB(p,Vector3.ZERO)if first else bounds.expand(p);first=false
   triangles.append(tri)
  rows.append({"surface":slot,"texture":texture.resource_path if texture is Texture2D else str(texture),"vertices":points.size(),"upper_bounds":var_to_str(bounds),"upper_triangles":triangles})
 var p="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Ancient Root Branches/surface-diagnostic.json";var f=FileAccess.open(p,FileAccess.WRITE);f.store_string(JSON.stringify({"scope":"Private read-only CPU surface ownership above11m; diagnostic only, not visual approval.","module_sha256":FileAccess.get_sha256("res://scripts/forest/forest_east_root_compounds.gd"),"surfaces":rows}));f.close();print("ROOT_SURFACE_DIAGNOSTIC ",rows.size());quit()
