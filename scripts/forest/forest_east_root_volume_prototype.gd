extends RefCounted
## Private closed root reconstruction; source face pixels and hollow stay exact.
const Old=preload("res://scripts/forest/forest_east_root_compounds.gd")
const Base=preload("res://scripts/forest/forest_east_region_art.gd")
const ROOT="res://assets/maps/falan/east_region/root_volume_prototype/"
const EYE=Vector3(-.0625,.045,.0625)
static var catalog={}
static var prepared:Mesh
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func height(pixel:Vector2)->float:
 var grid:Array=data().height_grid;var x=clampf(pixel.x/4.,0.,grid[0].size()-1);var y=clampf(pixel.y/4.,0.,grid.size()-1);var x0=int(x);var y0=int(y);var x1=mini(x0+1,grid[0].size()-1);var y1=mini(y0+1,grid.size()-1)
 return lerpf(lerpf(grid[y0][x0],grid[y0][x1],x-x0),lerpf(grid[y1][x0],grid[y1][x1],x-x0),y-y0)*.045
static func source_point(pixel:Vector2)->Vector3:
 var p=pixel+Vector2(data().origin[0],data().origin[1]);var y=height(pixel);var plane=p.y+y/.045
 return Vector3(p.x*3./64.-plane/16.,y,p.x*3./64.+plane/16.)
static func point(pixel:Vector2,reverse:bool)->Vector3:
 var p=source_point(pixel);var thickness=clampf(p.y/.65,0.,1.)
 if reverse:p-=EYE.normalized()*4.*thickness;p.y=maxf(0.,p.y)
 else:p+=EYE.normalized()*.8*thickness
 return p
static func normal(pixel:Vector2,reverse:bool)->Vector3:
 var horizontal=point(pixel+Vector2.RIGHT*.5,reverse)-point(pixel-Vector2.RIGHT*.5,reverse);var vertical=point(pixel+Vector2.DOWN*.5,reverse)-point(pixel-Vector2.DOWN*.5,reverse)
 var n=horizontal.cross(vertical).normalized();return n if reverse else -n
static func back_vertex(skin,p:Vector3,n:Vector3):
 skin.surface.set_normal(n);skin.surface.set_uv(Vector2((p.x+p.z)/4.,-p.y/3.2));skin.surface.set_uv2(Vector2.ZERO);skin.surface.add_vertex(p)
static func mesh()->Mesh:
 if prepared!=null:return prepared
 var info=data();var g={"origin":info.origin,"rect":[0,0,info.size[0],info.size[1]],"footprint":[1,1]};var front=Base.PreparedSkin.new([Rect2(0,0,info.size[0],info.size[1]),-Vector2(info.origin[0],info.origin[1]),Vector2.ONE,0],load(Old.ROOT+"body-front.png"),.045)
 var back=Base.PreparedSkin.new([],load(Old.ROOT+"bark-grain.png"),.045);back.tiles={"bark":Vector2.ZERO};back.part="bark"
 var outline=PackedVector2Array();var hollow=PackedVector2Array()
 for p:Array in info.outline:outline.append(Vector2(p[0],p[1]))
 for p:Array in info.hollow:hollow.append(Vector2(p[0],p[1]))
 for y in range(0,int(info.size[1]),4):
  for x in range(0,int(info.size[0]),4):
   var quad=PackedVector2Array([Vector2(x,y),Vector2(x+4,y),Vector2(x+4,y+4),Vector2(x,y+4)]);var polygons=Geometry2D.intersect_polygons(quad,outline)
   for poly:PackedVector2Array in polygons:
    for cut:PackedVector2Array in Geometry2D.clip_polygons(poly,hollow):
     var indices=Geometry2D.triangulate_polygon(cut)
     for i in range(0,indices.size(),3):
      for j in[0,1,2]:
       var pixel=cut[indices[i+j]];front.projected_vertex(point(pixel,false),normal(pixel,false),source_point(pixel))
      for j in[2,1,0]:
       var pixel=cut[indices[i+j]];back_vertex(back,point(pixel,true),normal(pixel,true))
 for ring:PackedVector2Array in[outline,hollow]:
  for i in ring.size():
   var a=ring[i];var b=ring[(i+1)%ring.size()];var p=point(a,false);var q=point(b,false);var r=point(b,true);var s=point(a,true);var n=(r-p).cross(q-p).normalized()
   for v:Vector3 in[p,q,r,p,r,s]:back_vertex(back,v,n)
 var body:Mesh=Base.bark_finish(back);var parts=[body,front.finish()];var old:Mesh=Old.mesh();var arrays:Array=old.get_meta("east_cpu_arrays")
 # Reuse the unchanged closed source crown and its two measured branch limbs.
 # The incompatible original cylindrical core/neck is not copied.
 for slot in[5,6,7,8,9]:
  var piece=ArrayMesh.new();piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays[slot]);piece.surface_set_material(0,old.surface_get_material(slot));piece.set_meta("east_cpu_arrays",[arrays[slot]]);parts.append(piece)
 prepared=Base.combine(parts);prepared.set_meta("east_ancient_root_volume_private",true);return prepared
