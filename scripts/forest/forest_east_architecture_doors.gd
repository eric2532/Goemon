extends RefCounted
## Source-facing native carved leaves over real closed timber sections.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Tiles=preload("res://assets/maps/original_crossgate/building-surfaces.gd")
const Atlas=preload("res://assets/maps/original_crossgate/building-surfaces.png")

static func mesh(g:Dictionary,texture:Texture2D)->Mesh:
 var a=Vector3(g.floor_edge[0][0],0,g.floor_edge[0][1]);var b=Vector3(g.floor_edge[1][0],0,g.floor_edge[1][1]);var along=(b-a).normalized();var normal=along.cross(Vector3.UP)
 var outline=PackedVector2Array()
 for pixel:Array in g.outline_pixels:
  var x=((float(pixel[0])+float(g.origin[0]))/(32./3.)-a.x-a.z)/(along.x+along.z)
  var point=a+along*x;outline.append(Vector2(x,((point.z-point.x)*8.-float(pixel[1])-float(g.origin[1]))*.045))
 var section=Shapes.extrude(outline,float(g.depth));var arrays=section.surface_get_arrays(0);var pose=Transform3D(Basis(along,Vector3.UP,normal),a-normal*float(g.depth)*.5)
 var base=Source.new([],Atlas,.045);base.tiles={"wood":Tiles.TILES.tina_fence_wood};base.part="wood"
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,.045)
 for index in arrays[Mesh.ARRAY_VERTEX].size():
  var p:Vector3=pose*arrays[Mesh.ARRAY_VERTEX][index];var n:Vector3=(pose.basis*arrays[Mesh.ARRAY_NORMAL][index]).normalized()
  base.surface.set_normal(n);base.surface.set_uv2(base.tiles.wood);base.surface.set_uv(Vector2(-p.y,p.dot(along))/1.4);base.surface.add_vertex(p)
  if n.dot(normal)>.9:front.projected_vertex(p+normal*.006,n,p)
 var result=base.finish();var wood:ShaderMaterial=result.surface_get_material(0).duplicate();wood.set_shader_parameter("original_palette",false);result.surface_set_material(0,wood)
 var native=front.finish();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,native.surface_get_arrays(0));result.surface_set_material(1,native.surface_get_material(0))
 return result
