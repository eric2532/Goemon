extends SceneTree
## Read-only render-cost audit; writes raw pose matrices and mesh references.
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Large Army Rebuild/Tests/Render Cost"
func _initialize():run.call_deferred()
func run():
 DirAccess.make_dir_recursive_absolute(OUT)
 for kind in [11,5,7,8,10]:
  var resource=load("res://assets/characters/ally_crowd/%d.res"%kind);var image:Image=resource.get_meta("pose_texture").get_image();var mesh:ArrayMesh=resource.get_meta("mesh")
  var file=FileAccess.open(OUT+"/%d-pose.bin"%kind,FileAccess.WRITE);file.store_buffer(image.get_data());file.close()
  var vertices=0;var triangles=0
  for surface in mesh.get_surface_count():
   var arrays=mesh.surface_get_arrays(surface);vertices+=arrays[Mesh.ARRAY_VERTEX].size();triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
   file=FileAccess.open(OUT+"/%d-%d-indices.bin"%[kind,surface],FileAccess.WRITE);file.store_buffer(arrays[Mesh.ARRAY_INDEX].to_byte_array());file.close()
  var data={"kind":kind,"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),"vertices":vertices,"triangles":triangles,"surfaces":mesh.get_surface_count(),"palette":resource.get_meta("palette").map(func(entry):return {"path":str(entry.path),"bind":entry.bind}),"refs":resource.get_meta("vertex_refs").map(func(ref):return {"path":str(ref.path),"group":ref.group,"offset":ref.offset,"count":ref.count})}
  file=FileAccess.open(OUT+"/%d.json"%kind,FileAccess.WRITE);file.store_string(JSON.stringify(data,"  "));file.close()
  print("ARMY_RENDER_COST kind=",kind," vertices=",vertices," triangles=",triangles," parts=",data.palette.size()," texture=",image.get_size())
 for kind in [0,1,3]:
  var resource=load("res://scripts/forest/forest_thirstquencher_visual.gd").data(kind);var mesh:ArrayMesh=resource.get_meta("mesh");var textures={}
  for surface in mesh.get_surface_count():
   var mat=mesh.surface_get_material(surface);textures[mat.albedo_texture]=true
  print("ARMY_RENDER_COST soldier=",kind," surfaces=",mesh.get_surface_count()," unique_textures=",textures.size()," textured=",textures.keys().filter(func(t):return t!=null).size())
 quit()
