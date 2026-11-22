extends RefCounted
## Native cliff mouths need open tunnels rather than the generic solid ridge.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Paint=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Parts=preload("res://scripts/forest/forest_tina_building_details.gd")
const Cliffs=preload("res://scripts/forest/forest_original_cliffs.gd")
const IDS=[12834,12839]

static func mesh(serial:int,g:Dictionary,height:float)->Mesh:
 var native=Paint.new([Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]),Vector2.ZERO,Vector2.ONE,0],load(Art.ROOT+Art.data().pages[int(g.page)]),.045)
 var inside=Paint.new(native.graphic,native.texture,.045)
 Cliffs.data()
 var rect:Array=Cliffs.entrance_paint[str(serial)]
 var stone=Paint.new([Rect2(rect[0],rect[1],rect[2],rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],Cliffs.texture(),.045)
 stone.projection_center=Vector3(3,0,-3)
 var cavity=SurfaceTool.new();cavity.begin(Mesh.PRIMITIVE_TRIANGLES)
 var snowy=serial==12834
 var pose=Transform3D(Basis(Vector3.UP,PI if snowy else PI*.5),Vector3(3,0,1.5) if snowy else Vector3(-1.5,0,-3))
 # shortcut: the original visible rim supplies paint; tunnel depth and hidden rock are reconstructed.
 var hole=[]
 var rim=[Vector2(-4.5,0),Vector2(-4.5,4),Vector2(-3.7,8),Vector2(-.7,height),Vector2(2.8,height*.85),Vector2(4.5,5.5),Vector2(4.5,0)]
 var inner_pixels=[Vector2(100,315),Vector2(82,268),Vector2(78,207),Vector2(96,167),Vector2(133,166),Vector2(155,247),Vector2(166,308)] if snowy else [Vector2(39,309),Vector2(48,259),Vector2(67,217),Vector2(88,180),Vector2(109,174),Vector2(101,226),Vector2(86,291)]
 var outer_pixels=[Vector2(41,338),Vector2(24,264),Vector2(20,169),Vector2(111,33),Vector2(153,55),Vector2(180,162),Vector2(202,304)] if snowy else [Vector2(7,306),Vector2(23,236),Vector2(54,133),Vector2(99,65),Vector2(166,119),Vector2(194,231),Vector2(139,351)]
 var source_span:Vector2=inner_pixels.back()-inner_pixels.front();var source_height=0.0;var heights=[]
 for pixel:Vector2 in inner_pixels:
  var baseline=inner_pixels.front().y+(pixel.x-inner_pixels.front().x)*source_span.y/source_span.x
  source_height=maxf(source_height,(baseline-pixel.y)*.045)
  heights.append((baseline-pixel.y)*.045)
 var source_size=Vector2(source_span.x*3/32,source_height)
 var floor_center=(inner_pixels.front().x+inner_pixels.back().x)*.5
 var head_center=(inner_pixels[3].x+inner_pixels[4].x)*.5
 var shear=(head_center-floor_center)/source_span.x
 var recess=absf(head_center-floor_center)*3/32
 for i in inner_pixels.size():
  var height_fraction=float(heights[i])/source_height
  hole.append(Vector2(((inner_pixels[i].x-floor_center)/source_span.x-shear*height_fraction)*source_size.x,heights[i]))
 hole=rounded(hole);rim=rounded(rim);inner_pixels=rounded(inner_pixels);outer_pixels=rounded(outer_pixels)
 for i in hole.size()-1:
  var a=pose*Vector3(hole[i].x,hole[i].y,recess*hole[i].y/source_height);var b=pose*Vector3(hole[i+1].x,hole[i+1].y,recess*hole[i+1].y/source_height)
  var c=pose*Vector3(rim[i+1].x,rim[i+1].y,.65);var d=pose*Vector3(rim[i].x,rim[i].y,.65)
  for band in 4:
   var u=band/4.0;var v=(band+1)/4.0
   Parts.painted_quad(native,a.lerp(d,u),b.lerp(c,u),b.lerp(c,v),a.lerp(d,v),[inner_pixels[i].lerp(outer_pixels[i],u),inner_pixels[i+1].lerp(outer_pixels[i+1],u),inner_pixels[i+1].lerp(outer_pixels[i+1],v),inner_pixels[i].lerp(outer_pixels[i],v)])
  var back_a=pose*Vector3(hole[i].x*.83,hole[i].y*.90,4.5)
  var back_b=pose*Vector3(hole[i+1].x*.83,hole[i+1].y*.90,4.5)
  var shade=Vector2(125,243) if snowy else Vector2(80,250)
  Parts.painted_quad(inside,a,back_a,back_b,b,[inner_pixels[i],inner_pixels[i].lerp(shade,.8),inner_pixels[i+1].lerp(shade,.8),inner_pixels[i+1]])
  stone.quad(c,pose*Vector3(rim[i+1].x,rim[i+1].y,4.5),pose*Vector3(rim[i].x,rim[i].y,4.5),d)
  stone.quad(pose*Vector3(rim[i+1].x,rim[i+1].y,4.5),back_b,back_a,pose*Vector3(rim[i].x,rim[i].y,4.5))
  for p in [back_b,back_a,pose*Vector3(0,2.4,4.5)]:cavity.add_vertex(p)
 # Close the floor and recessed end while keeping the entry open at ground level.
 var floor_points=[pose*Vector3(hole.back().x,.025,0),pose*Vector3(hole.back().x*.83,.025,4.5),pose*Vector3(hole.front().x*.83,.025,4.5),pose*Vector3(hole.front().x,.025,0)]
 var shade=Vector2(125,243) if snowy else Vector2(80,250)
 Parts.painted_quad(inside,floor_points[0],floor_points[1],floor_points[2],floor_points[3],[inner_pixels.back(),inner_pixels.back().lerp(shade,.8),inner_pixels.front().lerp(shade,.8),inner_pixels.front()])
 for p in [Vector3(hole.front().x*.83,0,4.5),Vector3(hole.back().x*.83,0,4.5),Vector3(0,2.4,4.5)]:cavity.add_vertex(pose*p)
 cavity.generate_normals()
 var dark=cavity.commit();dark.surface_set_material(0,Geo.mat("111714"))
 var shell=Parts.join(native.finish(),stone.finish(),Transform3D.IDENTITY,inside.finish())
 var result=Parts.join(shell,dark,Transform3D.IDENTITY)
 result.set_meta("native_cave_mouth",serial)
 result.set_meta("native_mouth_size",source_size)
 result.set_meta("native_mouth_profile",hole)
 result.set_meta("native_mouth_recess",recess)
 return result

static func rounded(points:Array)->Array:
 var result=[]
 for i in points.size()-1:
  for step in 4:
   result.append(points[i].cubic_interpolate(points[i+1],points[maxi(0,i-1)],points[mini(points.size()-1,i+2)],step/4.0))
 result.append(points.back())
 return result
