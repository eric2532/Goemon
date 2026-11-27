extends RefCounted
## The audited near-city notch reuses the existing original shore owner.
const Shore=preload("res://scripts/forest/forest_venoa_southwest_scenery.gd")
const Full=preload("res://assets/maps/falan/freyja_residual/full/data.gd")
static var data:Dictionary={}

static func catalog()->Dictionary:
 if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/freyja_residual/provenance.json"))
 return data

static func clipping(material:ShaderMaterial,terrain,enabled:bool):
 var area:String=terrain.variant
 var active=enabled and area in ["freyja","east_gate"]
 material.set_shader_parameter("use_adjoining_source_repair",active)
 material.set_shader_parameter("adjoining_source_repair",load("res://assets/maps/falan/freyja_residual/"+area+"-exception.png")if active else null)
 var bounds:Rect2=terrain.mask_bounds()if active else Rect2()
 material.set_shader_parameter("adjoining_source_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y))

static func collisions(model)->Array:
 var area:String=model.terrain.variant
 if not Full.BLOCKS.has(area):return []
 var frame:Transform2D=model.terrain.Regions.frame(area).inverse()
 var result=[]
 var rectangles:Array=catalog().areas.get(area,{}).get("blocked_rectangles",[]).duplicate()
 for rect:Rect2i in Full.BLOCKS[area]:rectangles.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
 for row in rectangles:
  var source=Rect2(Vector2(row[0],row[1])*3.-Vector2.ONE*1.5,Vector2(row[2],row[3])*3.)
  var local:Rect2=frame*source
  var box=AABB(Vector3(local.position.x,2.,local.position.y),Vector3(local.size.x,10.,local.size.y))
  result.append(["freyja_source_collision",Transform3D(Basis.IDENTITY,box.get_center()),box,row])
 return result

static func build(parent:Node3D,model):
 var area:String=model.terrain.variant
 if area not in ["freyja","east_gate"]:return
 var root=Node3D.new();root.name="FreyjaResidualSourceBanks";parent.add_child(root)
 var frame:Transform2D=model.terrain.Regions.frame(area)
 var groups={}
 for row in catalog().areas[area].shores:
  var serial=int(row[2]);var point:Vector2=frame.inverse()*(Vector2(row[0],row[1])*3.)
  var top=maxf(model.terrain.WATER_HEIGHT+2.10,model.surface_height(point.x,point.y))+.035
  var pose=Transform3D(Basis(Vector3.UP,frame.get_rotation()).scaled(Vector3(1,(top-model.terrain.WATER_HEIGHT)/2.10,1)),Vector3(point.x,top,point.y))
  if not groups.has(serial):groups[serial]=[]
  groups[serial].append([pose,row])
 for serial in groups:
  var rows:Array=groups[serial];var mesh=Shore.detail_mesh(serial,catalog().graphics[str(serial)])
  var part=MultiMeshInstance3D.new();part.name="NativeResidualBank_"+str(serial)
  part.multimesh=MultiMesh.new();part.multimesh.transform_format=MultiMesh.TRANSFORM_3D
  part.multimesh.mesh=mesh;part.multimesh.instance_count=rows.size()
  for i in rows.size():part.multimesh.set_instance_transform(i,rows[i][0])
  part.set_meta("source_anchors",rows.map(func(row):return row[1]))
  part.set_meta("prepared_poses",rows.map(func(row):return row[0]))
  root.add_child(part)
 root.set_meta("source_anchors",catalog().areas[area].shores)
