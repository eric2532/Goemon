extends SceneTree
const Art=preload("res://scripts/forest/forest_il_laruka_art.gd")
func _initialize():
 create_timer(90).timeout.connect(func():printerr("IL_LARUKA_GEOMETRY_TIMEOUT");quit(1))
 call_deferred("run")
func run():
 var stage=Node3D.new();root.add_child(stage)
 var count=0
 var rows=[]
 for serial in Art.Data.BUILDINGS:
  var start=stage.get_child_count()
  Art.build_building(stage,Vector3.ZERO,serial);count+=1
  var triangles=0;var surfaces=0;var parts=0
  for i in range(start,stage.get_child_count()):
   var owner=stage.get_child(i);var nodes=[owner];nodes.append_array(owner.find_children("*","Node3D",true,false))
   for node in nodes:
    var mesh:Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D else null
    if mesh==null:continue
    parts+=1;surfaces+=mesh.get_surface_count()
    for slot in mesh.get_surface_count():
     var arrays=mesh.surface_get_arrays(slot);var indices=arrays[Mesh.ARRAY_INDEX]
     triangles+=(indices.size() if indices is PackedInt32Array and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3*(node.multimesh.instance_count if node is MultiMeshInstance3D else 1)
  rows.append({"graphic":serial,"family":"building","parts":parts,"surfaces":surfaces,"triangles":triangles})
 for key in Art.Data.GRAPHICS:
  var serial=int(key);var g=Art.graphic(serial);var family=Art.Solids.kind(serial,false,g)
  if serial in Art.Data.BUILDINGS or family in ["tree","void"]:continue
  var mesh=Art.scenery_mesh(serial,g)
  assert(mesh!=null and mesh.get_surface_count()>0,"Missing prepared mesh "+key+" "+family)
  var triangles=0
  for i in mesh.get_surface_count():
   var arrays=mesh.surface_get_arrays(i);var indices=arrays[Mesh.ARRAY_INDEX]
   triangles+=(indices.size() if indices is PackedInt32Array and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
  rows.append({"graphic":serial,"family":family,"surfaces":mesh.get_surface_count(),"triangles":triangles})
  count+=1
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/Il and Laruka/mesh-audit.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(rows,"  "));file.close()
 print("IL_LARUKA_GEOMETRY meshes=",count)
 stage.queue_free()
 for i in 4:await process_frame
 quit()
