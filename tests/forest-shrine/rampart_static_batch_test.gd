extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const World=preload("res://scripts/forest/forest_world.gd")
const Art=preload("res://scripts/forest/forest_rampart_art.gd")
const BASELINE="res://tests/forest-shrine/rampart_native_geometry.json"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func numbers(values:Array)->String:
 var result=[]
 for value in values:result.append("%.4f"%float(value))
 return ",".join(result)
func vector(value:Vector3)->String:return numbers([value.x,value.y,value.z])
func bounds(box:AABB)->String:return vector(box.position)+";"+vector(box.size)
func descriptor(transform_:Transform3D,size_:Vector3,material:Material,shadow:int)->String:
 var box=transform_*AABB(-size_*.5,size_)
 return vector(transform_.origin)+"|"+bounds(box)+"|"+str(material.get_shader_parameter("base_color").to_html())+"|"+str(shadow)
func snapshot(parent:Node3D,world)->Dictionary:
 var boxes=[];var decks=[];var collision=[];var batches=0;var direct=0;var materials=true;var batch_bounds=true;var material_counts={}
 var readback=DisplayServer.get_name()!="headless"
 for node in parent.get_node("RaisedWallRoutes").get_children():
  if node is MeshInstance3D:
   if node.mesh is BoxMesh:
    direct+=1;boxes.append(descriptor(node.global_transform,node.mesh.size,node.material_override,node.cast_shadow))
    var key=str(node.material_override.get_shader_parameter("base_color").to_html())+"|"+str(node.cast_shadow)
    material_counts[key]=material_counts.get(key,0)+1
   else:decks.append(str(node.name).get_slice("@",0)+"|"+bounds(node.global_transform*node.mesh.get_aabb()))
  elif node is MultiMeshInstance3D:
   batches+=1;materials=materials and node.material_override in world.fog_materials
   var key=str(node.material_override.get_shader_parameter("base_color").to_html())+"|"+str(node.cast_shadow)
   material_counts[key]=material_counts.get(key,0)+node.multimesh.instance_count
   batch_bounds=batch_bounds and node.multimesh.custom_aabb.size.x>0 and node.multimesh.custom_aabb.size.y>0 and node.multimesh.custom_aabb.size.z>0
   var mesh_size:Vector3=node.multimesh.mesh.size
   for index in node.multimesh.instance_count:
    var local:Transform3D=node.multimesh.get_instance_transform(index)
    boxes.append(descriptor(node.global_transform*local,mesh_size,node.material_override,node.cast_shadow))
    var actual=local*AABB(-mesh_size*.5,mesh_size)
    if readback:batch_bounds=batch_bounds and node.multimesh.custom_aabb.encloses(actual.grow(-.0001))
  elif node is StaticBody3D:
   for shape in node.get_children():
    if shape is CollisionShape3D:
     if shape.shape is BoxShape3D:collision.append(str(node.collision_layer)+"|"+descriptor(shape.global_transform,shape.shape.size,world.fog_materials[0],0))
     elif shape.shape is ConvexPolygonShape3D:
      var points=[]
      for point in shape.shape.points:points.append(vector(shape.global_transform*point))
      collision.append(str(node.collision_layer)+"|"+";".join(points))
 boxes.sort();decks.sort();collision.sort()
 return {"boxes":boxes,"decks":decks,"collision":collision,"batches":batches,"direct":direct,"materials":materials,"batch_bounds":batch_bounds,"material_counts":material_counts,"readback":readback}
func fixture(map_path:String)->Dictionary:
 var data=JSON.parse_string(FileAccess.get_file_as_string(map_path));var model=Model.new();model.reset(42,{},data)
 var world=World.new();world.model=model
 var parent=Node3D.new();root.add_child(parent);parent.position=Vector3(7,2,-9)
 Art.build(world,parent)
 var result=snapshot(parent,world)
 parent.free();world.free()
 return result
func run():
 var maps=["res://assets/maps/forest_twin_ramparts.json","res://assets/maps/forest_four_gates.json"]
 var baseline={}
 if "--capture-native" in OS.get_cmdline_user_args():
  for map_path in maps:
   var state=fixture(map_path)
   if state.batches>0:printerr("Cannot replace native geometry baseline with batched output");quit(1);return
   baseline[map_path]={"boxes":state.boxes,"decks":state.decks,"collision":state.collision}
  var output=FileAccess.open(BASELINE,FileAccess.WRITE);output.store_string(JSON.stringify(baseline));output.close()
 else:baseline=JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
 for map_path in maps:
  var orphans_before=Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
  var state=fixture(map_path);var expected:Dictionary=baseline[map_path]
  var expected_materials={}
  for item in expected.boxes:
   var fields:String=item;var key=fields.get_slice("|",2)+"|"+fields.get_slice("|",3)
   expected_materials[key]=expected_materials.get(key,0)+1
  check(state.material_counts==expected_materials,"Every native decorative box retains its exact material/shadow/count: "+map_path)
  if state.readback:check(state.boxes==expected.boxes,"Every native decorative box retains its world bounds and center: "+map_path)
  else:print("SKIP: Per-instance transform readback requires a native renderer; headless Godot returns identity transforms")
  check(state.decks==expected.decks,"StoneWallDeck meshes retain exact names and world bounds: "+map_path)
  check(state.collision==expected.collision,"All native static collision shapes remain exact: "+map_path)
  check(state.materials and state.batch_bounds,"Batches retain original fog materials and contain all transformed instances")
  check(state.direct==0 and state.batches>0 and state.batches<state.boxes.size()/5,"Static repeated boxes use spatial batches with fewer visual objects")
  var again=fixture(map_path)
  check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)==orphans_before,"Repeated map construction and teardown leave no orphan nodes")
  check(again.boxes==state.boxes and again.decks==state.decks and again.collision==state.collision and again.batches==state.batches,"Map rebuild creates exactly one fresh copy of each visual and collision")
  print("RAMPART_BATCH_METRICS map=%s boxes=%d batches=%d decks=%d collisions=%d"%[map_path,state.boxes.size(),state.batches,state.decks.size(),state.collision.size()])
 print("RAMPART_STATIC_BATCH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
