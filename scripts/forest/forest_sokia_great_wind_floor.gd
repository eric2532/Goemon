extends RefCounted
## Native floor cells are visual only; the existing cave owner keeps every collider.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Atlas=preload("res://assets/maps/falan/sokia/scenery/great-wind-floor.png")
static var meshes:Dictionary={}
static var ceiling_paint:ShaderMaterial
static func build(root:Node3D,origin:Vector2):
 if meshes.is_empty():
  var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/scenery/great-wind-floor.json"))
  var raw:PackedByteArray=data.floor.hex_decode();var surfaces={false:Source.new([],Atlas,.1),true:Source.new([],Atlas,.1)}
  for i in int(data.size[0])*int(data.size[1]):
   var serial=raw.decode_u16(i*2)
   if serial<1000:continue
   var g:Dictionary=data.graphics[str(serial)];var r:Array=g.rect;var wet:bool=g.water
   var level=-.16 if wet else .025
   var at=origin+Vector2(i%int(data.size[0]),i/int(data.size[0]))*3.
   var skin=surfaces[wet]
   skin.graphic=[Rect2(r[0],r[1],r[2],r[3]),-Vector2(g.origin[0],g.origin[1])-Vector2((at.x+at.y)*32./3.,(at.y-at.x)*8.)+Vector2(0,level/.1),Vector2.ONE,0]
   skin.quad(Vector3(at.x-1.5,level,at.y-1.5),Vector3(at.x+1.5,level,at.y-1.5),Vector3(at.x+1.5,level,at.y+1.5),Vector3(at.x-1.5,level,at.y+1.5))
  for wet in surfaces:
   meshes[wet]=surfaces[wet].finish()
   var paint=Source.material(Atlas).duplicate();paint.set_shader_parameter("original_palette",wet)
   meshes[wet].surface_set_material(0,paint)
 for wet in meshes:
  var node=MeshInstance3D.new();node.name="NativeGreatWindWater" if wet else "NativeGreatWindFloor"
  node.mesh=meshes[wet];node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(node)

 var ceiling=root.find_child("SolidCaveCeiling",true,false) as MeshInstance3D
 if ceiling!=null:
  if ceiling_paint==null:
   ceiling_paint=load("res://scripts/forest/forest_stone_fort.gd").material(Color("655e51"),false).duplicate()
   var shader=Shader.new();shader.code=ceiling_paint.shader.code.replace("render_mode cull_back;","render_mode cull_disabled;");ceiling_paint.shader=shader
  ceiling.material_override=ceiling_paint
