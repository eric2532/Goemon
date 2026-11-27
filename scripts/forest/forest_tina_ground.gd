extends RefCounted
## Tina terrain variants only; original cells, heights and collision stay owned by Original.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Paint=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Harbor=preload("res://scripts/forest/forest_tina_harbor_details.gd")
static var records:Dictionary={}
static var meshes:Dictionary={}
static var texture:Texture2D
static var floor_materials={}

static func floor_material(source:int,origin:Vector2)->Material:
 if floor_materials.has(source):return floor_materials[source]
 var material=ShaderMaterial.new();material.shader=preload("res://scripts/forest/forest_tina_ground.gdshader")
 material.set_shader_parameter("continuous_floor",load("res://assets/maps/falan/tina/ground-continuous-%d.png"%source))
 material.set_shader_parameter("map_origin",origin)
 floor_materials[source]=material
 return material

static func shore(serial:int)->bool:
 return serial in range(12566,12602) or serial in range(12720,12754)

static func water_backing(root:Node3D,row:Dictionary):
 var cells=row.size.x*row.size.y;var covered={}
 for z in row.size.y:
  for x in row.size.x:
   if row.raw.decode_u16(20+(z*row.size.x+x)*2) not in range(5000,5009):continue
   for dz in range(-1,2):
    for dx in range(-1,2):
     var cell=Vector2i(x+dx,z+dz)
     if Rect2i(Vector2i.ZERO,row.size).has_point(cell):covered[cell]=true
 var source=floor_mesh(5000,Art.data().graphics["5000"]).surface_get_arrays(0)
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for cell:Vector2i in covered:
  var at=Vector3(row.origin.x+cell.x*3,-.025,row.origin.y+cell.y*3)
  for i in source[Mesh.ARRAY_VERTEX].size():
   surface.set_normal(Vector3.UP);surface.set_uv(source[Mesh.ARRAY_TEX_UV][i]);surface.add_vertex(source[Mesh.ARRAY_VERTEX][i]+at)
 var node=MeshInstance3D.new();node.name="TinaShoreWaterBacking";node.mesh=surface.commit()
 node.material_override=Paint.material(texture);root.add_child(node)

static func floor_mesh(serial:int,g:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 if records.is_empty():records=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/tina/ground.json")).graphics
 if texture==null:texture=load("res://assets/maps/falan/tina/ground.png")
 var record:Dictionary=records[str(serial)]
 assert(record.source_rgba_sha256==g.rgba_sha256,"Regenerate Tina ground gutters")
 var r:Array=record.rect
 var skin=Paint.new([Rect2(r[0],r[1],r[2],r[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,.045)
 var level=-2.10 if serial in range(5000,5009) else .012
 if level<0:skin.graphic[1].y+=level/.045
 skin.quad(Vector3(-1.5,level,-1.5),Vector3(1.5,level,-1.5),Vector3(1.5,level,1.5),Vector3(-1.5,level,1.5))
 meshes[serial]=skin.finish()
 return meshes[serial]

static func bank_mesh(serial:int,g:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var skin=Harbor.skin(g)
 # The old one-cell box clipped the tall shoreline painting into disconnected
 # posts. Invert its native projection across a cap, descending bank and water.
 var rows=[0.0,float(g.rect[3])]
 for y in [-float(g.origin[1]),21-float(g.origin[1])]:
  if y>0 and y<float(g.rect[3]):rows.append(y)
 rows.sort()
 for row in rows.size()-1:
  var pixels=[Vector2(0,rows[row]),Vector2(g.rect[2],rows[row]),Vector2(g.rect[2],rows[row+1]),Vector2(0,rows[row+1])]
  var points=[]
  for pixel:Vector2 in pixels:
   var height=clampf(-(pixel.y+float(g.origin[1]))*.1,-2.10,0)
   points.append(Harbor.point(pixel,height,g))
  # Three depth bands are sufficient; the original texture carries the contours.
  for i in [0,1,2,0,2,3,0,2,1,0,3,2]:
   skin.surface.set_normal(Vector3.UP)
   skin.surface.set_uv((skin.graphic[0].position+pixels[i].clamp(Vector2.ONE*.5,Vector2(g.rect[2],g.rect[3])-Vector2.ONE*.5))/skin.texture.get_size())
   skin.surface.add_vertex(points[i])
 meshes[serial]=skin.finish()
 return meshes[serial]
