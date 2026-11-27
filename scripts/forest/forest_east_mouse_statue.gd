extends RefCounted
## Private closed BG-sculpture study. Existing map/navigation/NPC owners stay intact.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const ROOT="res://assets/maps/falan/east_region/mouse_statue/"
const EYE=Vector3(-.0625,.045,.0625)
static var catalog:Dictionary={}
static var prepared:Mesh
static var background_pieces:Dictionary={}
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func replaces_background(cell:Vector2i,serial:int)->bool:
 if background_pieces.is_empty():
  var rows:Array=data().sculpture_source_placements
  assert(rows.size()==186,"Only the exact single-use native sculpture mosaics may be replaced")
  for row:Dictionary in rows:background_pieces[Vector3i(row.cell[0],row.cell[1],row.graphic)]=true
 return background_pieces.has(Vector3i(cell.x,cell.y,serial))
static func point(pixel:Vector2,part:Dictionary,reverse:bool=false)->Vector3:
 var origin=Vector2(data().origin[0],data().origin[1]);var native=pixel+origin
 var ground=float(part.ground_pixel_y)
 # A shared source depth datum keeps the outstretched arm and held wand
 # coherent. The wand is held above the original circle, not rooted in it.
 var plane=ground+origin.y;var u=native.x*3./64.
 var base=Vector3(u-plane/16.,(plane-native.y)*.045,u+plane/16.)
 var depth=.18
 for mass:Array in part.masses:
  var delta=(pixel-Vector2(mass[0],mass[1]))/Vector2(mass[2],mass[3])
  depth=maxf(depth,float(mass[4])*exp(-delta.length_squared()*1.7))
 return base+EYE.normalized()*depth*(-1. if reverse else 1.)
static func normal(pixel:Vector2,part:Dictionary,reverse:bool=false)->Vector3:
 var tangent=point(pixel+Vector2.RIGHT*.5,part,reverse)-point(pixel-Vector2.RIGHT*.5,part,reverse)
 var vertical=point(pixel+Vector2.DOWN*.5,part,reverse)-point(pixel-Vector2.DOWN*.5,part,reverse)
 var n=vertical.cross(tangent).normalized()
 return -n if reverse else n
static func floor_point(pixel:Vector2)->Vector3:
 var native=pixel+Vector2(data().origin[0],data().origin[1])
 return Vector3(native.x*3./64.-native.y/16.,.018,native.x*3./64.+native.y/16.)
static func rear_color(pixel:Vector2,name:String)->Color:
 if name=="staff":return Color("bfb793")
 # The unseen head is plain mineral under the hood. Broad independent tones
 # follow those masses; neither eyes nor the frontal portrait repeat behind it.
 var head=exp(-((pixel-Vector2(213,250))/Vector2(112,117)).length_squared()*1.2)
 var folds=sin((pixel.x+pixel.y*.24)/21.)*.025
 return Color("50564f").lerp(Color("8d9382"),head*.72).lightened(folds)
static func staff_construction()->Mesh:
 Furniture.Parts.prepare_primitives()
 var ivory=Furniture.tool();var collars=Furniture.tool();var orb=Furniture.tool()
 var spec:Dictionary=data().parts.staff
 var shaft_top=point(Vector2(65,198),spec,true)-EYE.normalized()*.17
 var shaft_bottom=point(Vector2(65,375),spec,true)-EYE.normalized()*.17
 Furniture.Parts.rod(ivory,shaft_bottom,shaft_top,.16)
 # These three collars and the blue crown orb are visible in the native art;
 # their closed reverse depth follows the same shaft instead of a blank panel.
 for pixel_y in[198.,350.,376.]:
  var at=point(Vector2(65,pixel_y),spec,true)-EYE.normalized()*.24
  Furniture.Parts.oval(collars,at,Vector3(.77,.22,.77))
 var crown=point(Vector2(68,124),spec,true)-EYE.normalized()*.68
 Furniture.Parts.oval(orb,crown,Vector3(1.48,1.48,1.48))
 for index in spec.outline.size():
  var a:Array=spec.outline[index];var b:Array=spec.outline[(index+1)%spec.outline.size()]
  Furniture.Parts.rod(collars,point(Vector2(a[0],a[1]),spec,true)-EYE.normalized()*.08,point(Vector2(b[0],b[1]),spec,true)-EYE.normalized()*.08,.065)
 for pixel:Vector2 in[Vector2(33,201),Vector2(98,226)]:
  Furniture.Parts.oval(orb,point(pixel,spec,true)-EYE.normalized()*.22,Vector3(.35,.70,.35))
 return Furniture.finish([ivory,collars,orb],[Fort.material(Color("c3bea3"),false),Fort.material(Color("a49a73"),false),Fort.material(Color("427a8b"),false)])
static func mesh()->Mesh:
 if prepared!=null:return prepared
 var g=data();var size_=Vector2(g.size[0],g.size[1]);var origin=Vector2(g.origin[0],g.origin[1]);var parts=[];var figure_bounds=AABB();var first=true
 var floor_skin=East.PreparedSkin.new([Rect2(Vector2.ZERO,size_),-origin,Vector2.ONE,0],load(ROOT+"ground.png"),.045)
 var corners=[Vector2.ZERO,Vector2(size_.x,0),size_,Vector2(0,size_.y)]
 for i in[0,1,2,0,2,3]:floor_skin.surface.set_normal(Vector3.UP);floor_skin.surface.set_uv(corners[i]/size_);floor_skin.surface.add_vertex(floor_point(corners[i]))
 parts.append(floor_skin.finish(true))
 for name:String in["body","staff"]:
  var spec:Dictionary=g.parts[name];var step=int(spec.step);var cells={}
  for row:Array in spec.cells:cells[Vector2i(row[0],row[1])]=true
  var native=East.PreparedSkin.new([Rect2(Vector2.ZERO,size_),-origin,Vector2.ONE,0],load(ROOT+name+"-front.png"),.045)
  var hidden=Furniture.tool()
  for cell:Vector2i in cells:
   var x=float(cell.x);var y=float(cell.y);var right=minf(x+step,size_.x);var down=minf(y+step,size_.y)
   var pixels=[Vector2(x,y),Vector2(right,y),Vector2(right,down),Vector2(x,down)];var front=[];var back=[]
   for pixel:Vector2 in pixels:front.append(point(pixel,spec));back.append(point(pixel,spec,true))
   for index in[0,1,2,0,2,3]:native.projected_vertex(front[index],normal(pixels[index],spec),front[index])
   # Independent physical-scale mineral/ivory continuation on the reverse.
   for index in[3,2,1,3,1,0]:hidden.set_color(rear_color(pixels[index],name));hidden.set_normal(normal(pixels[index],spec,true));hidden.set_uv(Vector2(back[index].x,back[index].y)/1.5);hidden.add_vertex(back[index])
   for edge in 4:
    var neighbour=cell+[Vector2i(0,-step),Vector2i(step,0),Vector2i(0,step),Vector2i(-step,0)][edge]
    if cells.has(neighbour):continue
    var next=(edge+1)%4;hidden.set_color(rear_color((pixels[edge]+pixels[next])*.5,name));Furniture.Shapes.quad(hidden,front[next],front[edge],back[edge],back[next])
  var face_mesh=native.finish(true);parts.append(face_mesh)
  var arrays=Source.committed_arrays(hidden.commit_to_arrays());var reverse=ArrayMesh.new();reverse.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var material:ShaderMaterial=Source.material(load(ROOT+name+"-material.png")).duplicate();material.set_shader_parameter("use_base_texture",false);material.set_shader_parameter("use_vertex_color",true);material.set_shader_parameter("vertex_color_srgb",true);material.set_shader_parameter("alpha_cutout",false);material.set_shader_parameter("original_palette",false)
  reverse.surface_set_material(0,material);reverse.set_meta("east_cpu_arrays",[arrays]);parts.append(reverse)
  var closed_bounds=face_mesh.get_aabb().merge(reverse.get_aabb())
  figure_bounds=closed_bounds if first else figure_bounds.merge(closed_bounds);first=false
 var staff=staff_construction();parts.append(staff);figure_bounds=figure_bounds.merge(staff.get_aabb())
 prepared=East.combine(parts);prepared.set_meta("east_source_mouse_statue",33608);prepared.set_meta("source_bg_mosaics",g.source_placements.size());prepared.set_meta("statue_bounds",figure_bounds);prepared.set_meta("inferred_hidden_sculpture",true)
 return prepared
