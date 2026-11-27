extends "res://tests/forest-shrine/falan_proportion_preview.gd"
const REPAIR_OUT="res://build/Other Files/Asset Toolkit/Falan Surface Repair/After/"
var checks=0
var reviewed={}
func _initialize():
 create_timer(240).timeout.connect(func():printerr("FALAN_SURFACE_TIMEOUT");quit(1))
 root.size=Vector2i(1280,900);root.set_flag(Window.FLAG_ALWAYS_ON_TOP,true);root.grab_focus()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPAIR_OUT))
 super._initialize()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FALAN_SURFACE_FAIL "+message)
func capture(model:Node3D,key:String,points:Array[Vector3]):
 var rect:Rect2=Fit.References.RECTS[key]
 var measured=Fit.projected_bounds(points,Transform3D(model.basis,Vector3.ZERO))
 check(measured.position.distance_to(rect.position)<.05 and measured.size.distance_to(rect.size)<.05,"Source height/width and anchor "+key)
 var nodes=model.find_children("*","MeshInstance3D",true,false)
 if model is MeshInstance3D:nodes.append(model)
 var triangles=0
 for node in nodes:
  for part in node.mesh.get_surface_count():
   var paint:Material=node.get_active_material(part)
   check(paint!=null,"Every building face has its own material "+key)
   if paint is ShaderMaterial:
    check(paint.get_shader_parameter("falan_source_projection")!=true,"Whole-building picture projection is absent "+key)
   var arrays=node.mesh.surface_get_arrays(part)
   var normal:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   var valid=normal.size()==arrays[Mesh.ARRAY_VERTEX].size()
   for n in normal:
    if not n.is_finite() or n.length_squared()<.1:valid=false
   check(valid,"Finite outward shading normals "+key)
   triangles+=node.mesh.get_faces().size()/3 if part==0 else 0
 if key.begins_with("house_"):
  var mesh:Mesh=nodes[0].mesh
  check(mesh.get_surface_count()==2 and mesh.surface_get_material(1).get_shader_parameter("architecture_roof")==true,"Facade, slate and masonry details have separate shared surfaces "+key)
  check(mesh.surface_get_material(0).get_shader_parameter("base_texture")==Architecture.Atlas,"Recovered doors/windows remain on facade UVs "+key)
  check(mesh.surface_get_material(1).get_shader_parameter("use_base_texture")==true and mesh.surface_get_material(1).get_shader_parameter("base_texture")==Architecture.Atlas,"Slate retains its native weathered paint "+key)
  check(is_same(mesh,Architecture.prepare(int(key.trim_prefix("house_")))),"Repeated houses reuse the prepared mesh "+key)
 var bounds=AABB(model.basis*points[0],Vector3.ZERO)
 for p:Vector3 in points:bounds=bounds.expand(model.basis*p)
 var target=bounds.get_center()
 camera.size=maxf(bounds.size.x+bounds.size.z,bounds.size.y*1.7)*1.05
 var views=[Vector3(65,40,65),Vector3(-65,40,65),Vector3(-65,40,-65),Vector3(65,40,-65)]
 if DisplayServer.get_name()!="headless":
  for side in views.size():
   camera.position=target+views[side];camera.look_at(target)
   for i in 4:await process_frame
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(REPAIR_OUT+key+"-%d.png"%side)==OK,"Capture "+key)
 reviewed[key]={"triangles":triangles,"meshes":nodes.size(),"source_bounds":str(measured),"views":4 if DisplayServer.get_name()!="headless" else 0}
 var report=FileAccess.open(REPAIR_OUT+"review.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures,"buildings":reviewed},"  "));report.close()
 print("FALAN_SURFACE_MODEL ",key," triangles=",triangles," meshes=",nodes.size())
 model.queue_free();await process_frame
