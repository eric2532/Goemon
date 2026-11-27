extends SceneTree
## Dynamic collisions use the same indexed triangles, including cached Freyja meshes.
const Model=preload("res://scripts/forest/forest_model.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_terrain.gd")
var checks=0
var failures=0
var rows=[]
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("TERRAIN_COLLISION_ARRAYS_FAIL "+label_)
func _initialize():run.call_deferred()
func verify(terrain,label_:String):
 var mesh:ArrayMesh=terrain.mesh()
 var cpu:Array=mesh.get_meta("source_surface_arrays",[])
 check(not cpu.is_empty(),"Dynamic builder retains its existing CPU triangles: "+label_)
 if cpu.is_empty():return
 var before=var_to_bytes(cpu)
 # Independent old-path oracle; this readback is diagnostic test work only.
 var first=ArrayMesh.new();first.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
 var old=first.create_trimesh_shape().get_faces()
 var start=Time.get_ticks_usec();var shape=terrain.collision();var elapsed=Time.get_ticks_usec()-start
 var actual:PackedVector3Array=shape.get_faces()
 check(actual.to_byte_array()==old.to_byte_array(),"Every collision triangle/order matches the prior first-surface shape: "+label_)
 check(actual.size()==(terrain.width-1)*(terrain.width-1)*6,"Decorative apron never enters playable collision: "+label_)
 check(not mesh.has_meta("source_surface_arrays"),"CPU staging arrays are released after collision preparation: "+label_)
 check(var_to_bytes(cpu)==before,"Preparing collision does not mutate the visual/source arrays: "+label_)
 check(terrain.collision()==shape and terrain.mesh()==mesh,"Repeated setup shares the same owned mesh and shape: "+label_)
 rows.append({"case":label_,"vertices":cpu[Mesh.ARRAY_VERTEX].size(),"faces":actual.size()/3,"surfaces":mesh.get_surface_count(),"cpu_collision_usec":elapsed,"triangles_exact":actual.to_byte_array()==old.to_byte_array()})
func run():
 var dynamic=Meadow.new();dynamic.expansion=1.5;dynamic.configure([])
 verify(dynamic,"expanded-meadow")
 var raised=Meadow.new();raised.raised_castle=true;raised.configure([]);verify(raised,"raised-meadow-with-apron")
 for scale_ in [1.,2.]:
  var arena=Model.create_terrain("wind_meadow",scale_,1.,false,"arena");arena.configure([])
  verify(arena,"FalanArena-"+str(scale_))
 for area in ["sokia_coast","sokia_desert","ghana_north_road"]:
  var layout=Regions.layout(area);var model=Model.new();model.reset(41829558,{},layout,false)
  verify(model.terrain,area)
  var other=Model.new();other.reset(41829558,{},layout,false)
  check(other.terrain.mesh()==model.terrain.mesh() and other.terrain.collision()==model.terrain.collision(),"New terrain instance reuses exact Freyja cache after CPU staging release: "+area)
 var baked=Meadow.new();baked.configure([])
 check(baked.collision()==load(Meadow.asset_path("collision.res",1.)),"Default baked collision remains unchanged")
 var output="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/terrain-collision-arrays.json"
 var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"scope":"CPU collision setup correctness; rendered terrain, native reachability and performance remain separate."},"  "));file.close()
 print("TERRAIN_COLLISION_ARRAYS_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
