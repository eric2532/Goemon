extends RefCounted
## Original Sokia props share the existing terrain, foliage and static collision owners.
const Data=preload("res://assets/maps/falan/sokia/data.gd")
const Atlas=preload("res://assets/maps/falan/sokia/props.png")
const Details=preload("res://scripts/forest/forest_sokia_details.gd")
const MASKS={
 "sokia_coast":preload("res://assets/maps/falan/sokia/sokia_coast_surface.png"),
 "sokia_desert":preload("res://assets/maps/falan/sokia/sokia_desert_surface.png"),
 "ghana_road":preload("res://assets/maps/falan/sokia/ghana_road_surface.png"),
 "ghana_north_road":preload("res://assets/maps/falan/sokia/ghana_north_road_surface.png")}
static var meshes={}
static var material:ShaderMaterial
static func owns(area:String)->bool:return MASKS.has(area)
static func collisions(model,frame:Transform2D)->Array:
 var result=[]
 for rect:Rect2i in Data.BLOCKS[model.falan_area]:
  var center=frame*((Vector2(rect.position)+Vector2(rect.size-Vector2i.ONE)*.5)*3.0)
  var size_=Vector2(rect.size)*3.0
  var height=30.0 if model.falan_area=="ghana_north_road" else 10.0
  var box=AABB(Vector3(center.x-size_.x*.5,2.0,center.y-size_.y*.5),Vector3(size_.x,height,size_.y))
  result.append(["sokia_source_collision",Transform3D(Basis.IDENTITY,box.get_center()),box,0])
 return result
static func kili_prop(serial:int)->bool:
 return Data.GRAPHICS.has(serial) and ((serial>=11625 and serial<=11710) or (serial>=12160 and serial<=12180))
static func build(parent:Node3D,model,frame:Transform2D,rows:Array):
 if material==null:
  material=ShaderMaterial.new();material.shader=preload("res://scripts/forest/sokia_scenery.gdshader")
  material.set_shader_parameter("source_art",Atlas)
 var groups={}
 for row in rows:
  var serial:int=row[1]
  if not Data.GRAPHICS.has(serial):continue
  var cell:Vector2i=row[0];var span:Vector2i=row[2]
  var at=frame*((Vector2(cell)+Vector2(span-Vector2i.ONE)*Vector2(.5,-.5))*3.0)
  var key=[serial,Vector2i(floori(at.x/48),floori(at.y/48))]
  if not groups.has(key):groups[key]=[]
  var rect:Rect2i=Data.GRAPHICS[serial]
  groups[key].append(Transform3D(Basis.IDENTITY,Vector3(at.x,model.surface_height(at.x,at.y)+rect.size.y*.023,at.y)))
 for key in groups:
  var serial:int=key[0]
  if not meshes.has(serial):
   var rect:Rect2i=Data.GRAPHICS[serial]
   var mesh=QuadMesh.new();mesh.size=Vector2(rect.size)*.046
   var arrays=mesh.surface_get_arrays(0);var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
   for i in uvs.size():uvs[i]=(Vector2(rect.position)+uvs[i]*Vector2(rect.size))/Atlas.get_size()
   var mapped=ArrayMesh.new();mapped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);meshes[serial]=mapped
  var batch=MultiMeshInstance3D.new();batch.name="SokiaNativeProp_%d_%d_%d"%[serial,key[1].x,key[1].y];batch.material_override=material
  batch.extra_cull_margin=Data.GRAPHICS[serial].size.x*.023;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.mesh=meshes[serial]
  batch.multimesh.instance_count=groups[key].size()
  for i in groups[key].size():batch.multimesh.set_instance_transform(i,groups[key][i])
  batch.set_meta("source_graphic",serial);batch.set_meta("source_placements",groups[key].size())
  parent.add_child(batch)
