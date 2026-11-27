extends RefCounted
## Private source-contour mass; complete rounded roots and independent hidden bark.
const Old=preload("res://scripts/forest/forest_east_root_compounds.gd")
const Base=Old.Base
const ROOT="res://assets/maps/falan/east_region/root_sculpt_prototype/"
const EYE=Vector3(-.0625,.045,.0625)
static var catalog={}
static var prepared:Mesh
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func sample(grid:Array,pixel:Vector2)->float:
 var x=clampf(pixel.x/4.,0.,grid[0].size()-1);var y=clampf(pixel.y/4.,0.,grid.size()-1);var x0=int(x);var y0=int(y);var x1=mini(x0+1,grid[0].size()-1);var y1=mini(y0+1,grid.size()-1)
 return lerpf(lerpf(grid[y0][x0],grid[y0][x1],x-x0),lerpf(grid[y1][x0],grid[y1][x1],x-x0),y-y0)
static func source_point(pixel:Vector2)->Vector3:
 var p=pixel+Base.v(data().origin);var height=sample(data().height_grid,pixel);var floor_y=p.y+height/.045
 return Vector3(p.x*3./64.-floor_y/16.,height,p.x*3./64.+floor_y/16.)
static func point(pixel:Vector2,reverse:bool)->Vector3:
 var p=source_point(pixel);var depth=sample(data().depth_grid,pixel);var side=-.65 if reverse else .35
 if not reverse:
  var hollow=PackedVector2Array()
  for at:Array in data().hollow:hollow.append(Base.v(at))
  if Geometry2D.is_point_in_polygon(pixel,hollow):side=0.;depth=0.;p-=EYE.normalized()*2.8
 p+=EYE.normalized()*depth*side;p.y=maxf(0.,p.y);return p
static func normal(pixel:Vector2,reverse:bool)->Vector3:
 var right=point(pixel+Vector2.RIGHT*.5,reverse)-point(pixel-Vector2.RIGHT*.5,reverse);var down=point(pixel+Vector2.DOWN*.5,reverse)-point(pixel-Vector2.DOWN*.5,reverse);var n=right.cross(down).normalized();return n if reverse else -n
static func mesh()->Mesh:
 if prepared!=null:return prepared
 var info=data();var row=[Rect2(0,0,info.size[0],info.size[1]),-Base.v(info.origin),Vector2.ONE,0];var front=Base.PreparedSkin.new(row,load(Old.ROOT+"body-front.png"),.045);var back=Base.PreparedSkin.new(row,load(ROOT+"independent-back.png"),.045)
 for cell:Array in info.active_cells:
  var x=float(cell[0])*4.;var y=float(cell[1])*4.;var corners=[Vector2(x,y),Vector2(x+4,y),Vector2(x+4,y+4),Vector2(x,y+4)]
  for side in[false,true]:
   var skin=back if side else front
   for index in([2,1,0,3,2,0]if side else[0,1,2,0,2,3]):
    var pixel:Vector2=corners[index];skin.projected_vertex(point(pixel,side),normal(pixel,side),source_point(pixel))
 var reverse:Mesh=back.finish();var material:ShaderMaterial=reverse.surface_get_material(0).duplicate();material.set_shader_parameter("original_palette",false);material.set_shader_parameter("surface_kind",4.0);reverse.surface_set_material(0,material)
 var parts=[reverse,front.finish()];var old:Mesh=Old.mesh();var arrays:Array=old.get_meta("east_cpu_arrays")
 for slot in[5,6,7,8,9]:
  var piece=ArrayMesh.new();piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays[slot]);piece.surface_set_material(0,old.surface_get_material(slot));piece.set_meta("east_cpu_arrays",[arrays[slot]]);parts.append(piece)
 prepared=Base.combine(parts);prepared.set_meta("east_ancient_root_sculpt_private",true);return prepared
