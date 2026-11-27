extends RefCounted
## Original isometric paint projected onto solid, reusable 3D pieces.
const Paint=preload("res://scripts/forest/forest_painterly_environment.gd")
static var materials:Dictionary={}
var graphic:Array
var texture:Texture2D
var pixel_height:float
var surface:SurfaceTool
var tiles:Dictionary={}
var pitches:Dictionary={}
var part="plaster"
var baked_scale=Vector3.ONE
var feature=false
var projection_center=Vector3.ZERO
var reflection_threshold=.01

func _init(row:Array,atlas:Texture2D,height_per_pixel:float):
 graphic=row;texture=atlas;pixel_height=height_per_pixel
 surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)

static func material(atlas:Texture2D,tiled:bool=false)->Material:
 var key=[atlas,tiled]
 if materials.has(key):return materials[key]
 var result=ShaderMaterial.new()
 result.shader=Paint.SURFACE
 result.set_shader_parameter("surface_kind",5.0)
 result.set_shader_parameter("use_vertex_color",false)
 result.set_shader_parameter("use_base_texture",true)
 result.set_shader_parameter("base_texture",atlas)
 result.set_shader_parameter("brush_texture",Paint.BRUSH)
 result.set_shader_parameter("base_color",Color.WHITE)
 result.set_shader_parameter("alpha_cutout",true)
 result.set_shader_parameter("original_palette",true)
 if tiled:result.set_shader_parameter("atlas_tile_pixels",128.0)
 materials[key]=result
 return result

func vertex(point:Vector3,normal:Vector3):
 var sample=point
 # The sprite records two faces; reflect that paint onto unseen walls and roof slopes.
 if normal.x>reflection_threshold:sample.x=2*projection_center.x-sample.x
 if normal.z< -reflection_threshold:sample.z=2*projection_center.z-sample.z
 projected_vertex(point,normal,sample)

func projected_vertex(point:Vector3,normal:Vector3,sample:Vector3):
 var pixel:Vector2=graphic[1]+Vector2((sample.x+sample.z)*32.0/3.0,(sample.z-sample.x)*8.0-sample.y/pixel_height)
 var rect:Rect2=graphic[0]
 pixel=pixel.clamp(Vector2.ONE*.5,rect.size-Vector2.ONE*.5)
 surface.set_normal(normal)
 surface.set_uv((rect.position+pixel)/texture.get_size())
 surface.add_vertex(point)

func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3):
 if not tiles.is_empty():
  a*=baked_scale;b*=baked_scale;c*=baked_scale;d*=baked_scale
 var normal=(c-a).cross(b-a)
 if normal.length_squared()<.00000001:normal=(d-a).cross(b-a)
 if normal.length_squared()<.00000001:return
 normal=normal.normalized()
 if not tiles.is_empty():
  var tangent=(d-a).normalized() if d.distance_squared_to(a)>.0001 else (c-b).normalized()
  var up=normal.cross(tangent).normalized()
  var pitch={"plaster":.45,"timber":2.0,"trim":.35,"stone":.9,"villa_stone":.75,"thatch":2.0,"round_thatch":2.0,"blue_roof":2.0,"tina_blue_roof":6.0,"tina_green_roof":6.0,"tina_brown_roof":6.0,"10006_roof":3.0,"10007_roof":3.0,"architecture_blue_roof":6.0,"architecture_green_roof":6.0,"architecture_red_roof":6.0,"dormer_cap":.75}.get(part,1.5)
  pitch=pitches.get(part,pitch)
  var points=[a,b,c,d]
  var corners=[Vector2(.0001,.9999),Vector2(.0001,.0001),Vector2(.9999,.0001),Vector2(.9999,.9999)]
  for i in [0,1,2,0,2,3]:
   var p:Vector3=points[i]
   surface.set_normal(normal)
   surface.set_uv2(tiles[part])
   surface.set_uv(corners[i] if feature else Vector2(p.dot(tangent),-p.dot(up))/pitch)
   surface.add_vertex(p)
  return
 for point in [a,b,c,a,c,d]:vertex(point,normal)

func panel(a:Vector3,b:Vector3,c:Vector3,d:Vector3,paint:String):
 var previous=part
 part=paint;feature=true
 quad(a,b,c,d)
 part=previous;feature=false

func box(bounds:AABB):
 var a=bounds.position;var b=bounds.end
 quad(Vector3(a.x,a.y,b.z),Vector3(a.x,b.y,b.z),Vector3(b.x,b.y,b.z),Vector3(b.x,a.y,b.z))
 quad(Vector3(a.x,a.y,a.z),Vector3(a.x,b.y,a.z),Vector3(a.x,b.y,b.z),Vector3(a.x,a.y,b.z))
 quad(Vector3(b.x,a.y,b.z),Vector3(b.x,b.y,b.z),Vector3(b.x,b.y,a.z),Vector3(b.x,a.y,a.z))
 quad(Vector3(b.x,a.y,a.z),Vector3(b.x,b.y,a.z),Vector3(a.x,b.y,a.z),Vector3(a.x,a.y,a.z))
 quad(Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z))

static func committed_arrays(arrays:Array)->Array:
 # Match RenderingServer4.6.1's normal packing without reading the uploaded mesh.
 var result=arrays.duplicate(true);var normals:PackedVector3Array=result[Mesh.ARRAY_NORMAL]
 for i in normals.size():
  var packed=normals[i].octahedron_encode()*65535.
  normals[i]=Vector3.octahedron_decode(Vector2(clampi(int(packed.x),0,65535)/65535.,clampi(int(packed.y),0,65535)/65535.))
 result[Mesh.ARRAY_NORMAL]=normals
 return result

func finish(retain_arrays:bool=false)->Mesh:
 var arrays=surface.commit_to_arrays() if retain_arrays else []
 var result=surface.commit()
 if retain_arrays:result.set_meta("source_surface_arrays",committed_arrays(arrays))
 result.surface_set_material(0,material(texture,not tiles.is_empty()))
 return result
