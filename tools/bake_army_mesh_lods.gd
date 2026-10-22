extends SceneTree
func _initialize():
 for kind in [11,5,7,8,10]:
  var path="res://assets/characters/ally_crowd/%d.res"%kind
  var resource=load(path);var mesh=preload("res://scripts/forest/crowd/army_mesh_lod.gd").build(resource)
  mesh.set_meta("source_sha256",FileAccess.get_sha256(path))
  var error=ResourceSaver.save(mesh,"res://assets/characters/ally_crowd/lod_%d.res"%kind,ResourceSaver.FLAG_COMPRESS)
  if error!=OK:printerr("FAIL: meshLOD save ",kind," error=",error);quit(1);return
  print("ARMY_LOD_BAKE kind=",kind)
 quit()
