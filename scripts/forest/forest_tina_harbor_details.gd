extends RefCounted
## Native boat/sign landmarks, prepared once in the existing scenery mesh cache.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Paint=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Tina=preload("res://scripts/forest/forest_tina_building_details.gd")
const Parts=preload("res://scripts/forest/forest_falan_lamps.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const BuildingData=preload("res://assets/maps/original_crossgate/building-surfaces.gd")
const BuildingAtlas=preload("res://assets/maps/original_crossgate/building-surfaces.png")
const BOATS=[11500,11501]
const SIGNS=[11489,11491,11495,11496,11497,11499]
# Native 3/4 view: vertical pixels and the 8 px ground shear cancel at the 1.6 camera elevation.
const PIXEL_HEIGHT=.1

static func skin(g:Dictionary):
 return Paint.new([Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(Art.ROOT+Art.data().pages[int(g.page)]),PIXEL_HEIGHT)

static func structure():
 var result=Paint.new([],BuildingAtlas,PIXEL_HEIGHT);result.tiles=BuildingData.TILES
 return result

# Invert the existing native projector; source anchors are not the boat's centre.
static func point(pixel:Vector2,height:float,g:Dictionary)->Vector3:
 var sum=(pixel.x+float(g.origin[0]))*3/32
 var difference=(pixel.y+float(g.origin[1])+height/PIXEL_HEIGHT)/8
 return Vector3((sum-difference)*.5,height,(sum+difference)*.5)

static func rod(target,a:Vector3,b:Vector3,radius:float,part:String):
 var delta=b-a
 if delta.length_squared()<.000001:return
 Parts.prepare_primitives()
 var pose=Transform3D(Basis(Quaternion(Vector3.UP,delta.normalized())).scaled_local(Vector3(radius*2,delta.length(),radius*2)),(a+b)*.5)
 var normals=pose.basis.inverse().transposed();var arrays=Parts.cylinder.surface_get_arrays(0)
 for index in arrays[Mesh.ARRAY_INDEX]:
  target.surface.set_normal((normals*arrays[Mesh.ARRAY_NORMAL][index]).normalized())
  target.surface.set_uv(arrays[Mesh.ARRAY_TEX_UV][index]);target.surface.set_uv2(target.tiles[part]);target.surface.add_vertex(pose*arrays[Mesh.ARRAY_VERTEX][index])

static func cask(target,at:Vector3,axis:Vector3,length_:float,radius:float,paint:String="tina_boat_cask"):
 var body=structure();body.part=paint
 Tina.Parts.kili_round(body,Vector3.ZERO,[Vector2(0,0),Vector2(radius*.80,0),Vector2(radius,length_*.2),Vector2(radius,length_*.8),Vector2(radius*.80,length_),Vector2(0,length_)])
 body.part="tina_barrel_hoop"
 for y in [length_*.17,length_*.80]:Tina.Parts.kili_round(body,Vector3.UP*y,[Vector2(radius*1.01,0),Vector2(radius*1.01,.10)])
 var mesh=body.finish();target.surface.append_from(mesh,0,Transform3D(Basis(Quaternion(Vector3.UP,axis)),at-axis*length_*.5))

static func boat_mesh(serial:int,g:Dictionary)->Mesh:
 var native=skin(g);var wood=structure();var white=serial==11500
 var hull_paint="tina_boat_white" if white else "tina_boat_red"
 var rail_paint="tina_boat_green" if white else "tina_boat_blue"
 var port=[Vector2(16,131),Vector2(56,213),Vector2(106,260),Vector2(175,297),Vector2(252,326),Vector2(333,347)] if white else [Vector2(15,116),Vector2(54,205),Vector2(105,255),Vector2(175,295),Vector2(255,324),Vector2(336,342)]
 var starboard=[Vector2(16,131),Vector2(75,167),Vector2(123,205),Vector2(201,249),Vector2(272,291),Vector2(333,347)] if white else [Vector2(15,116),Vector2(82,159),Vector2(133,202),Vector2(205,244),Vector2(272,288),Vector2(336,342)]
 var polygon=PackedVector2Array(port)
 for i in range(starboard.size()-2,0,-1):polygon.append(starboard[i])
 var indices=Geometry2D.triangulate_polygon(polygon);wood.part=hull_paint
 for i in range(0,indices.size(),3):
  var vertices=[point(polygon[indices[i]],0,g),point(polygon[indices[i+1]],0,g),point(polygon[indices[i+2]],0,g)]
  if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).y<0:vertices.reverse()
  for p:Vector3 in vertices:
   wood.surface.set_normal(Vector3.UP);wood.surface.set_uv2(wood.tiles[hull_paint]);wood.surface.set_uv(Vector2(p.x,p.z)/2.0);wood.surface.add_vertex(p)
 for edge in [port,starboard]:
  for i in edge.size()-1:
   var a=point(edge[i],.15,g);var b=point(edge[i+1],.15,g)
   var c=b+Vector3.UP*-1.45;var d=a+Vector3.UP*-1.45
   var normal=Vector3.LEFT if edge==port else Vector3.RIGHT
   # shortcut: the client exposes one hull face; the opposite planking mirrors its own source paint.
   Tina.outward_quad(native,[a,b,c,d],[edge[i],edge[i+1],edge[i+1]+Vector2(2,10),edge[i]+Vector2(2,10)],normal)
   rod(wood,a,b,.09,rail_paint)
   rod(wood,a+Vector3.UP*.75,b+Vector3.UP*.75,.055,rail_paint)
   if i>0:rod(wood,a,a+Vector3.UP*.75,.06,hull_paint)
 var stern=point(Vector2(7,94),1.7,g);var bow=point(Vector2(333,342),.15,g)
 rod(wood,point(port[0],0,g),stern,.12,hull_paint)
 var base_pixel=Vector2(140,242);var top_pixel=Vector2(140,7)
 var mast_base=point(base_pixel,.12,g);var mast_top=mast_base+Vector3.UP*((base_pixel.y-top_pixel.y)*PIXEL_HEIGHT)
 rod(wood,mast_base,mast_top,.11,"tina_boat_red" if white else "tina_boat_blue")
 rod(wood,mast_base+Vector3(.17,1.0,0),mast_top+Vector3(.12,-.3,0),.07,"tina_boat_white")
 rod(wood,mast_top,stern,.025,"tina_boat_white");rod(wood,mast_top,bow,.025,"tina_boat_white")
 rod(wood,mast_top,mast_base+Vector3(0,.2,-4),.025,"tina_boat_white")
 var pole_base=point(Vector2(280,427) if white else Vector2(303,406),-2.10,g)
 var pole_height=(103 if white else 86)*PIXEL_HEIGHT
 rod(wood,pole_base,pole_base+Vector3.UP*pole_height,.16,"tina_fence_wood")
 wood.part="tina_boat_white"
 for i in 4:
  var y=pole_height-.45+i*.11
  Tina.Parts.kili_round(wood,pole_base+Vector3.UP*y,[Vector2(.19,0),Vector2(.19,.06)])
 rod(wood,bow,pole_base+Vector3.UP*(pole_height-.2),.035,"tina_boat_white")
 if white:
  var roof=[Vector2(49,145),Vector2(92,111),Vector2(136,139),Vector2(94,171)];var points=[]
  var cabin_height=33*PIXEL_HEIGHT
  for pixel:Vector2 in roof:points.append(point(pixel,cabin_height,g))
  Tina.outward_quad(native,points.duplicate(),roof.duplicate(),Vector3.UP)
  for i in 4:
   var j=(i+1)%4
   var a:Vector3=points[i];var b:Vector3=points[j]
   Tina.painted_quad(native,a-Vector3.UP*cabin_height,a,b,b-Vector3.UP*cabin_height,[roof[i]+Vector2(0,33),roof[i],roof[j],roof[j]+Vector2(0,33)])
   rod(wood,a,b,.055,"timber")
  # The original net is kept on the cabin face, with a separate raised hanging edge.
  var net=[Vector2(94,151),Vector2(111,151),Vector2(111,216),Vector2(94,216)]
  var at=point(Vector2(102,216),.20,g)
  Tina.outward_quad(native,[at+Vector3(0,2.925,-.7),at+Vector3(0,2.925,.7),at+Vector3(0,0,.7),at+Vector3(0,0,-.7)],net,Vector3.LEFT)
  for pixel in [Vector2(165,277),Vector2(187,291)]:cask(wood,point(pixel,1.05,g)+Vector3.RIGHT*2.0,Vector3.RIGHT,2.5,1.0)
 else:
  cask(wood,point(Vector2(193,287),1.05,g)+Vector3.RIGHT*1.8,Vector3.UP,1.9,1.12)
  for z in [-16.0,-10.0,-1.0]:
   wood.part="tina_boat_red";wood.box(AABB(Vector3(1.2,.32,z),Vector3(3.6,.16,.42)))
 # Map placement supplies the water datum; keep the deck above it to avoid coplanar water flicker.
 var result=Tina.join(wood.finish(),native.finish(),Transform3D(Basis.IDENTITY,Vector3.UP*.55))
 result.set_meta("source_boat",serial);result.set_meta("source_cargo_count",2 if white else 1)
 return result

const BOARDS={
 11491:[Vector2(12,52),Vector2(16,34),Vector2(33,15),Vector2(50,8),Vector2(61,12),Vector2(65,21),Vector2(65,62),Vector2(14,94)],
 11495:[Vector2(2,3),Vector2(14,4),Vector2(30,15),Vector2(48,30),Vector2(61,43),Vector2(61,49),Vector2(49,48),Vector2(27,32),Vector2(9,18)],
 11496:[Vector2(2,4),Vector2(13,3),Vector2(32,14),Vector2(52,32),Vector2(62,46),Vector2(58,49),Vector2(44,44),Vector2(23,29),Vector2(7,14)],
 11497:[Vector2(1,33),Vector2(11,21),Vector2(33,5),Vector2(50,1),Vector2(58,4),Vector2(52,15),Vector2(35,29),Vector2(13,43),Vector2(3,45)],
 11499:[Vector2(24,19),Vector2(33,16),Vector2(43,22),Vector2(50,36),Vector2(48,47),Vector2(41,50),Vector2(31,44),Vector2(24,34)],
 11489:[Vector2(34,39),Vector2(37,27),Vector2(49,21),Vector2(59,22),Vector2(62,30),Vector2(57,42),Vector2(45,50),Vector2(36,48)]
}
static func sign_point(pixel:Vector2,g:Dictionary,axis:Vector3)->Vector3:
 var across=(pixel.x+float(g.origin[0]))*3/32/(axis.x+axis.z)
 var at=axis*across
 at.y=(-float(g.origin[1])+(at.z-at.x)*8-pixel.y)*PIXEL_HEIGHT
 return at

static func sign_mesh(serial:int,g:Dictionary)->Mesh:
 var native=skin(g);var wood=structure();var axis=Vector3.RIGHT if serial in [11497,11489,11491] else Vector3.BACK
 if serial in [11489,11499]:axis=Vector3(1,0,1).normalized()
 var normal=axis.cross(Vector3.UP);var profile=PackedVector2Array()
 var image=native.texture.get_image().get_region(Rect2i(g.rect[0],g.rect[1],g.rect[2],g.rect[3]))
 var mask=BitMap.new();mask.create_from_image_alpha(image,.5)
 var boundary:PackedVector2Array=Geometry2D.offset_polygon(PackedVector2Array(BOARDS[serial]),1.0)[0]
 for y in image.get_height():
  for x in image.get_width():
   if not Geometry2D.is_point_in_polygon(Vector2(x,y),boundary):mask.set_bit(x,y,false)
 var outline=PackedVector2Array()
 for polygon:PackedVector2Array in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),.7):
  if polygon.size()>outline.size():outline=polygon
 assert(outline.size()>=3,"The native sign board must retain a solid source contour")
 for pixel:Vector2 in outline:
  var p=sign_point(pixel,g,axis);profile.append(Vector2(p.dot(axis),p.y))
 var model=Shapes.extrude(profile,.12);var arrays=model.surface_get_arrays(0)
 var turn=Basis(Vector3.UP,atan2(-axis.z,axis.x));var rect=Vector2(g.rect[0],g.rect[1])
 for i in arrays[Mesh.ARRAY_VERTEX].size():
  var p:Vector3=turn*arrays[Mesh.ARRAY_VERTEX][i];var n:Vector3=turn*arrays[Mesh.ARRAY_NORMAL][i]
  if arrays[Mesh.ARRAY_NORMAL][i].z>.9:
   var sample=p-normal*.06
   var pixel=Vector2(-float(g.origin[0])+(sample.x+sample.z)*32/3,-float(g.origin[1])+(sample.z-sample.x)*8-sample.y/PIXEL_HEIGHT)
   native.surface.set_normal(n);native.surface.set_uv((rect+pixel)/native.texture.get_size());native.surface.add_vertex(p)
  else:
   wood.surface.set_normal(n);wood.surface.set_uv(Vector2(p.dot(axis),p.y));wood.surface.set_uv2(wood.tiles.tina_fence_wood);wood.surface.add_vertex(p)
 if serial==11491:
  for pair in [[Vector2(10,117),Vector2(10,40)],[Vector2(64,82),Vector2(64,3)]]:
   var base=point(pair[0],0,g);var top=sign_point(pair[1],g,axis)
   rod(wood,base,top,.16,"tina_sign_bark")
   wood.part="tina_soft_snow"
   Tina.Parts.kili_round(wood,top,[Vector2(.20,0),Vector2(.17,.18),Vector2(0,.24)])
   Tina.Parts.kili_round(wood,base,[Vector2(.48,.01),Vector2(.40,.11),Vector2(0,.22)])
 elif serial in [11495,11496,11497]:
  var bottom=Vector2(29,61) if serial!=11497 else Vector2(32,61)
  var top=Vector2(29,29) if serial!=11497 else Vector2(32,26)
  rod(wood,point(bottom,0,g),sign_point(top,g,axis),.065,"tina_fence_wood")
 else:
  var paths=[[Vector2(22,78),Vector2(18,59),Vector2(19,36),Vector2(14,18),Vector2(8,1)],
             [Vector2(19,36),Vector2(31,14),Vector2(53,6),Vector2(66,15)],
             [Vector2(18,59),Vector2(35,64)], [Vector2(22,78),Vector2(37,82)], [Vector2(22,78),Vector2(9,84)]] if serial==11499 else [[Vector2(69,82),Vector2(67,59),Vector2(64,38),Vector2(70,19),Vector2(75,8)], [Vector2(64,38),Vector2(57,14),Vector2(40,8),Vector2(18,12)], [Vector2(67,59),Vector2(79,65)], [Vector2(69,82),Vector2(54,85)]]
  for path in paths:
   for i in path.size()-1:
    var a=point(path[i],0,g) if path[i].y>=(72 if serial==11499 else 78) else sign_point(path[i],g,axis)
    var b=point(path[i+1],0,g) if path[i+1].y>=(72 if serial==11499 else 78) else sign_point(path[i+1],g,axis)
    var radius=.32-i*.055 if path==paths[0] else (.10 if path[0].y>55 else .075)
    rod(wood,a,b,radius,"tina_sign_bark")
  var leaf=[Vector2(33,0),Vector2(79,0),Vector2(79,37),Vector2(33,37)] if serial==11499 else [Vector2(1,0),Vector2(53,0),Vector2(53,31),Vector2(1,31)]
  var leaves=BitMap.new();leaves.create_from_image_alpha(image,.5)
  for y in image.get_height():
   for x in image.get_width():
    var pixel=Vector2(x,y)
    if not Geometry2D.is_point_in_polygon(pixel,PackedVector2Array(leaf)) or Geometry2D.is_point_in_polygon(pixel,boundary):leaves.set_bit(x,y,false)
  for cluster:PackedVector2Array in leaves.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),.7):
   var triangles=Geometry2D.triangulate_polygon(cluster)
   for i in range(0,triangles.size(),3):
    for side in [-1,1]:
     var pixels=[cluster[triangles[i]],cluster[triangles[i+1]],cluster[triangles[i+2]]];var points=[]
     for pixel:Vector2 in pixels:points.append(sign_point(pixel,g,axis)+normal*.08)
     if (points[2]-points[0]).cross(points[1]-points[0]).dot(normal*side)<0:points.reverse();pixels.reverse()
     for j in 3:
      native.surface.set_normal(normal*side);native.surface.set_uv((rect+pixels[j])/native.texture.get_size());native.surface.add_vertex(points[j])
 if serial in [11495,11489]:
  var base=sign_point(Vector2(29,66) if serial==11495 else Vector2(69,84),g,axis)
  wood.part="snowroof";Tina.Parts.kili_round(wood,Vector3(base.x,.02,base.z),[Vector2(.55,0),Vector2(.40,.10),Vector2(0,.18)])
 var result=Tina.join(native.finish(),wood.finish(),Transform3D.IDENTITY);result.set_meta("source_sign",serial)
 return result
