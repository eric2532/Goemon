extends RefCounted
## Bounded native wall/arch parts; original map owns every walk cell and doorway.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Sections=preload("res://scripts/forest/forest_east_architecture_sections.gd")
const Tiles=preload("res://assets/maps/original_crossgate/building-surfaces.gd")
const Atlas=preload("res://assets/maps/original_crossgate/building-surfaces.png")

static func front_point(pixel:Vector2,g:Dictionary)->Vector3:
 var across=(pixel.x+float(g.origin[0]))/(32./3.);var plane=float(g.plane)
 var p=Vector3(across-plane,0,plane) if g.axis=="x" else Vector3(plane,0,across-plane)
 p.y=((p.z-p.x)*8.-pixel.y-float(g.origin[1]))*.045
 return p

static func wall_part(base,front,points:Array,normal:Vector3,depth:float):
 base.part="wall";Sections.oriented_quad(base,front,points,normal,true)
 var rear=[]
 for p:Vector3 in points:rear.append(p-normal*depth)
 Sections.oriented_quad(base,front,rear,-normal,false)
 for index in 4:
  var next=(index+1)%4;var center=(points[index]+points[next])*.5
  var middle=(points[0]+points[1]+points[2]+points[3])*.25
  var out=center-middle
  base.part="cap" if absf(out.y)>absf(out.x)+absf(out.z) else "wall"
  Sections.oriented_quad(base,front,[points[index],rear[index],rear[next],points[next]],out,false)

static func mesh(g:Dictionary,paint_texture:Texture2D,ground_texture:Texture2D)->Mesh:
 var base=Source.new([],Atlas,.045);base.tiles={"wall":Tiles.TILES.tina_ruin_stone,"cap":Tiles.TILES.tina_ruin_stone};base.pitches={"wall":1.4,"cap":1.4}
 var graphic=[Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0]
 var front=Source.new(graphic,paint_texture,.045)
 var normal=Vector3.BACK if g.axis=="x" else Vector3.LEFT
 for strip:Array in g.strips:
  var points=[front_point(Vector2(strip[0],strip[3]),g),front_point(Vector2(strip[0],strip[2]),g),front_point(Vector2(strip[1],strip[2]),g),front_point(Vector2(strip[1],strip[3]),g)]
  for p:Vector3 in points:p.y=maxf(0.,p.y)
  if maxf(points[1].y,points[2].y)<=.001:continue
  wall_part(base,front,points,normal,float(g.depth))
 var ground=Source.new(graphic,ground_texture,.045)
 var corners=[]
 for pixel:Vector2 in [Vector2.ZERO,Vector2(g.size[0],0),Vector2(g.size[0],g.size[1]),Vector2(0,g.size[1])]:corners.append(Sections.source_point(pixel,.015,g))
 Sections.oriented_quad(ground,ground,corners,Vector3.UP,false)
 var result=base.finish(true)
 var material:ShaderMaterial=result.surface_get_material(0).duplicate();material.set_shader_parameter("original_palette",false)
 result.surface_set_material(0,material)
 for source in [front,ground]:
  var part:Mesh=source.finish(true);result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.get_meta("source_surface_arrays"));result.surface_set_material(result.get_surface_count()-1,part.surface_get_material(0))
 result.set_meta("native_broken_wall",int(g.serial));result.set_meta("source_footprint",g.footprint)
 return result
