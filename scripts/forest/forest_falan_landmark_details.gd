extends RefCounted
## Native paint stays on the surface of the existing solid facade.
const Data=preload("res://assets/maps/falan/city_landmark_details.gd")
const SourceMesh=preload("res://scripts/forest/forest_coastal_mesh.gd")
static var materials:Dictionary={}
static var panel:QuadMesh

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
 var node=Geo.mesh(root,panel,p,material(feature))
 node.name="Recovered_"+feature
 node.set_meta("falan_source_feature",feature)
 node.rotation.y=yaw;node.scale=Vector3(size_.x,size_.y,1)
 return node
