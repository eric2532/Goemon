extends RefCounted
## Native paint stays on the surface of the existing solid facade.
const Data=preload("res://assets/maps/falan/city_landmark_details.gd")
const SourceMesh=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
static var materials:Dictionary={}
static var panel:QuadMesh
static var medallion:Mesh

static func material(feature:String)->Material:
 if materials.has(feature):return materials[feature]
 var row:Array=Data.FEATURES[feature]
 var texture:Texture2D=row[0]
 var rect:Rect2=row[1]
 var result:ShaderMaterial=SourceMesh.material(texture).duplicate()
 result.set_shader_parameter("uv_scale",(rect.size-Vector2.ONE)/texture.get_size())
 result.set_shader_parameter("uv_offset",(rect.position+Vector2.ONE*.5)/texture.get_size())
 materials[feature]=result
 return result

static func add(root:Node3D,feature:String,p:Vector3,size_:Vector2,yaw:float=0.0)->MeshInstance3D:
 if panel==null:panel=QuadMesh.new();panel.size=Vector2.ONE
 var shape:Mesh=panel
 if feature in ["office_rosette","castle_clock"]:
  if medallion==null:
   var outline=PackedVector2Array()
   for i in 64:outline.append(Vector2(cos(i*TAU/64),sin(i*TAU/64))*.5)
   var arrays=Shapes.extrude(outline,.06).surface_get_arrays(0)
   var uv=PackedVector2Array()
   for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:uv.append(Vector2(point.x+.5,.5-point.y))
   arrays[Mesh.ARRAY_TEX_UV]=uv
   medallion=ArrayMesh.new();medallion.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  shape=medallion
 var node=Geo.mesh(root,shape,p,material(feature))
 node.name="Recovered_"+feature
 node.set_meta("falan_source_feature",feature)
 node.rotation.y=yaw;node.scale=Vector3(size_.x,size_.y,1)
 return node
