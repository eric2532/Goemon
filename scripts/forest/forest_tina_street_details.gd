extends RefCounted
## Source wall sections and containers, baked into the existing original-map mesh cache.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Harbor=preload("res://scripts/forest/forest_tina_harbor_details.gd")
const Tina=preload("res://scripts/forest/forest_tina_building_details.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const STOCKADES={11140:Vector2(20,64),11142:Vector2(24,62),11143:Vector2(28,60),11145:Vector2(30,60),11146:Vector2(28,56)}
const WATER_PROPS=[11464,11481,11482,11483]
const BENCHES=[10037,11041]
# Foot, cap centre, native cap radius, and opaque cap/stem paint rectangles.
const MUSHROOMS={
 11098:[[Vector2(6,20),Vector2(4,12),4.8,Rect2(1,9,4,3),Rect2(7,17,1,1)],
        [Vector2(15,21),Vector2(15,12),5.2,Rect2(12,9,5,3),Rect2(14,17,1,1)],
        [Vector2(21,11),Vector2(21,4),4.2,Rect2(18,1,5,3),Rect2(21,7,1,1)]],
 11099:[[Vector2(6,20),Vector2(4,12),4.8,Rect2(1,10,4,3),Rect2(8,16,1,1)],
        [Vector2(16,22),Vector2(15,12),5.2,Rect2(12,10,5,3),Rect2(14,18,1,1)],
        [Vector2(21,11),Vector2(21,4),4.2,Rect2(18,1,5,3),Rect2(21,7,1,1)],
        [Vector2(27,20),Vector2(26,10),5.0,Rect2(23,8,5,3),Rect2(24,16,1,1)],
        [Vector2(12,29),Vector2(10,21),4.0,Rect2(8,19,5,3),Rect2(10,26,1,1)]]
}
# Visible face axis and ground-plane offset, measured from the native stone base line.
const WALLS={11140:[false,-.71875],11142:[false,-.765625],11143:[false,-.8125],11145:[true,1.03125],11146:[true,1.078125],11333:[false,-1.4063],11334:[false,-1.4063],11335:[true,1.0938],11336:[true,1.1172],11337:[true,1.1172],11338:[true,1.1172],11339:[true,1.1719],11340:[true,1.1563],11341:[false,-.5156],11342:[false,-.7344],11343:[false,-.7578],11344:[false,-.75],11345:[false,-.6719],11346:[false,-.9219],11347:[true,.9531],11348:[false,-1.4063],11349:[false,-1.4063],11350:[true,1.0938],11351:[true,1.1172],11352:[true,1.1172],11353:[true,1.1172],11354:[true,1.1719],11355:[true,1.1563],11356:[false,-.5156],11358:[false,-.7578],11361:[false,-.9219],11362:[true,.9531]}
const BARRELS={
 10017:[[Vector2(24,61),1.35,3.4,"tina_barrel_brown"]],
 10032:[[Vector2(18,79),1.3,3.4,"tina_barrel_green"],[Vector2(61,103),1.35,3.4,"tina_barrel_red"],[Vector2(35,57),1.45,3.7,"tina_barrel_brown"]],
 10033:[[Vector2(62,100),1.3,3.4,"tina_barrel_green"],[Vector2(62,67),1.5,3.8,"tina_barrel_brown",3.4],[Vector2(40,99),1.35,3.4,"tina_barrel_red"],[Vector2(94,97),1.35,3.4,"tina_barrel_red"],[Vector2(23,126),1.3,3.4,"tina_barrel_green"],[Vector2(109,125),1.3,3.4,"tina_barrel_green"],[Vector2(64,155),1.35,3.4,"tina_barrel_red"]]
}

static var wall_outlines:Dictionary={}
static var mushroom_material:ShaderMaterial

static func plank(native,wood,pixels:Array,height:float,g:Dictionary,supports:Array=[0,1,2,3])->Array:
 var points=[]
 for pixel in pixels:points.append(Harbor.point(pixel,height,g))
 var middle=Vector2.ZERO
 for pixel:Vector2 in pixels:middle+=pixel/4
 var samples=pixels.map(func(pixel):return pixel.lerp(middle,.07))
 Tina.outward_quad(native,points.duplicate(),samples,Vector3.UP)
 wood.part="tina_box_plank"
 for i in 4:
  var j=(i+1)%4
  wood.quad(points[i],points[j],points[j]-Vector3.UP*.13,points[i]-Vector3.UP*.13)
 wood.quad(points[3]-Vector3.UP*.13,points[2]-Vector3.UP*.13,points[1]-Vector3.UP*.13,points[0]-Vector3.UP*.13)
 for index in supports:
  var corner:Vector3=points[index]
  var top=corner.lerp((points[0]+points[2])*.5,.12)
  Harbor.rod(wood,Vector3(top.x,.02,top.z),top-Vector3.UP*.10,.075,"tina_crate_trim")
 return points

static func bench_mesh(serial:int,g:Dictionary)->Mesh:
 var native=Harbor.skin(g);var wood=Harbor.structure()
 var seat=2.0 if serial==11041 else 1.6
 if serial==10037:
  var upper=plank(native,wood,[Vector2(2,46),Vector2(57,2),Vector2(65,8),Vector2(10,53)],seat,g,[0,1])
  var lower=plank(native,wood,[Vector2(14,58),Vector2(57,24),Vector2(64,28),Vector2(21,64)],.75,g,[2,3])
  for pair in [[0,3],[1,2]]:
   var a:Vector3=upper[pair[0]].lerp((upper[0]+upper[2])*.5,.12)
   var b:Vector3=lower[pair[1]].lerp((lower[0]+lower[2])*.5,.12)
   a.y=.30;b.y=.30;Harbor.rod(wood,a,b,.055,"tina_crate_trim")
 else:
  var seat_corners=plank(native,wood,[Vector2(8,83),Vector2(74,31),Vector2(98,47),Vector2(29,98)],seat,g,[2,3])
  var pixels=[Vector2(3,53),Vector2(70,7),Vector2(71,26),Vector2(4,73)];var points=[]
  for pixel in pixels:
   var p=Harbor.sign_point(pixel,g,Vector3.RIGHT)+Vector3(1.4,-2.24,-1.4)
   points.append(p)
  var a:Vector3=seat_corners[0].lerp((seat_corners[0]+seat_corners[2])*.5,.12)
  var b:Vector3=seat_corners[1].lerp((seat_corners[0]+seat_corners[2])*.5,.12)
  var high=(points[0].y+points[1].y)*.5;var low=(points[2].y+points[3].y)*.5
  points=[Vector3(a.x,high,a.z),Vector3(b.x,high,b.z),Vector3(b.x,low,b.z),Vector3(a.x,low,a.z)]
  Tina.outward_quad(native,points.duplicate(),pixels.duplicate(),Vector3.BACK)
  wood.part="tina_box_plank"
  wood.quad(points[3]+Vector3.FORWARD*.13,points[2]+Vector3.FORWARD*.13,points[1]+Vector3.FORWARD*.13,points[0]+Vector3.FORWARD*.13)
  for i in 4:
   var j=(i+1)%4
   wood.quad(points[i],points[j],points[j]+Vector3.FORWARD*.13,points[i]+Vector3.FORWARD*.13)
  for i in [0,1]:
   var top:Vector3=points[i]
   Harbor.rod(wood,Vector3(top.x,.02,top.z),top,.075,"tina_crate_trim")
 var result=Tina.join(native.finish(),wood.finish(),Transform3D.IDENTITY)
 result.set_meta("source_bench_backrest",serial==11041);return result

static func native_primitive(native,mesh:Mesh,pose:Transform3D,paint:Rect2):
 var arrays=mesh.surface_get_arrays(0);var normals=pose.basis.inverse().transposed()
 var indices=arrays[Mesh.ARRAY_INDEX]
 for j in (indices.size() if indices is PackedInt32Array and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()):
  var i=indices[j] if indices is PackedInt32Array and not indices.is_empty() else j
  var pixel=paint.get_center()
  native.surface.set_normal((normals*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
  native.surface.set_uv((native.graphic[0].position+pixel)/native.texture.get_size());native.surface.add_vertex(pose*arrays[Mesh.ARRAY_VERTEX][i])

static func mushrooms_mesh(serial:int,g:Dictionary)->Mesh:
 var native=Harbor.skin(g);Harbor.Parts.prepare_primitives()
 if Geo.sphere_mesh==null:
  var holder=Node3D.new();Geo.sphere(holder,Vector3.ZERO,Vector3.ONE,null);holder.free()
 for record in MUSHROOMS[serial]:
  var foot=Harbor.point(record[0],.02,g);var high=(record[0].y-record[1].y)*Harbor.PIXEL_HEIGHT
  var cap=Harbor.point(record[1],high,g);var delta=cap-foot
  var stem=Transform3D(Basis(Quaternion(Vector3.UP,delta.normalized())).scaled_local(Vector3(.10,delta.length(),.10)),(foot+cap)*.5)
  native_primitive(native,Harbor.Parts.cylinder,stem,record[4])
  var radius=record[2]*3/(32*sqrt(2.0))
  native_primitive(native,Geo.sphere_mesh,Transform3D(Basis.IDENTITY.scaled(Vector3(radius*2,radius*.95,radius*2)),cap),record[3])
 var result=native.finish()
 if mushroom_material==null:
  mushroom_material=result.surface_get_material(0).duplicate();mushroom_material.set_shader_parameter("original_palette",false)
  mushroom_material.set_shader_parameter("base_color",Color(.82,.82,.82))
  var brush=Image.create(1,1,false,Image.FORMAT_RGBA8);brush.fill(Color(.5,.5,.5))
  mushroom_material.set_shader_parameter("brush_texture",ImageTexture.create_from_image(brush))
 result.surface_set_material(0,mushroom_material)
 result.set_meta("source_mushroom_count",MUSHROOMS[serial].size());return result

static func wall_mesh(serial:int,g:Dictionary)->Mesh:
 var native=Harbor.skin(g);var edge=Harbor.structure()
 if wall_outlines.is_empty():wall_outlines=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/tina/wall-outlines.json")).graphics
 var record:Dictionary=wall_outlines[str(serial)]
 assert(record.source_rgba_sha256==g.rgba_sha256,"Regenerate stale native wall contours")
 var outline=PackedVector2Array()
 for pixel in record.outline:outline.append(Vector2(pixel[0],pixel[1]))
 var along_x:bool=WALLS[serial][0];var offset:float=WALLS[serial][1]
 var axis=Vector3.RIGHT if along_x else Vector3.BACK;var normal=axis.cross(Vector3.UP)
 var distance=offset if along_x else -offset;var profile=PackedVector2Array();var low=INF
 for pixel:Vector2 in outline:
  var across=(pixel.x+float(g.origin[0]))*3/32-offset
  var p=axis*across+normal*distance
  var y=(-float(g.origin[1])+(p.z-p.x)*8-pixel.y)*Harbor.PIXEL_HEIGHT
  profile.append(Vector2(across,y));low=minf(low,y)
 for i in profile.size():profile[i].y-=low
 # shortcut: native art provides the front; closed rear/edge depth uses the same regional stone kit.
 var depth=1.6 if serial in [11333,11334] else 1.1
 var sections=[[profile,false]]
 if STOCKADES.has(serial):
  var pixel:Vector2=STOCKADES[serial];var across=(pixel.x+float(g.origin[0]))*3/32-offset
  var p=axis*across+normal*distance
  var seam=(-float(g.origin[1])+(p.z-p.x)*8-pixel.y)*Harbor.PIXEL_HEIGHT-low
  var bounds=Rect2(profile[0],Vector2.ZERO)
  for point:Vector2 in profile:bounds=bounds.expand(point)
  sections.clear()
  for timber in [false,true]:
   var y0=seam if timber else -1.0;var y1=bounds.end.y+1 if timber else seam
   var clip=PackedVector2Array([Vector2(bounds.position.x-1,y0),Vector2(bounds.end.x+1,y0),Vector2(bounds.end.x+1,y1),Vector2(bounds.position.x-1,y1)])
   for polygon in Geometry2D.intersect_polygons(profile,clip):sections.append([polygon,timber])
 var turn=Basis(Vector3.UP,atan2(-axis.z,axis.x));var origin=normal*(distance-depth*.5)
 for section in sections:
  var shape=Shapes.extrude(section[0],depth);var arrays=shape.surface_get_arrays(0)
  for i in arrays[Mesh.ARRAY_VERTEX].size():
   var p:Vector3=turn*arrays[Mesh.ARRAY_VERTEX][i]+origin;var n:Vector3=turn*arrays[Mesh.ARRAY_NORMAL][i]
   if arrays[Mesh.ARRAY_NORMAL][i].z>.9:
    var source=p;source.y=p.y+low
    var pixel=Vector2(-float(g.origin[0])+(source.x+source.z)*32/3,-float(g.origin[1])+(source.z-source.x)*8-source.y/Harbor.PIXEL_HEIGHT)
    native.surface.set_normal(n);native.surface.set_uv((Vector2(g.rect[0],g.rect[1])+pixel)/native.texture.get_size());native.surface.add_vertex(p)
   else:
    var part=("tina_log_end" if n.y>.4 else "tina_hollow_bark") if section[1] else "tina_ruin_stone" if STOCKADES.has(serial) else "tina_ruin_snow" if n.y>.4 else "tina_ruin_stone"
    var uv=Vector2(p.x,p.z) if absf(n.y)>maxf(absf(n.x),absf(n.z)) else (Vector2(p.z,p.y) if absf(n.x)>absf(n.z) else Vector2(p.x,p.y))
    edge.surface.set_normal(n);edge.surface.set_uv(uv/1.5);edge.surface.set_uv2(edge.tiles[part]);edge.surface.add_vertex(p)
 var result=Tina.join(native.finish(),edge.finish(),Transform3D.IDENTITY);result.set_meta("source_ruin_wall",serial)
 return result

static func barrel_mesh(serial:int,g:Dictionary)->Mesh:
 var wood=Harbor.structure();var cap=Harbor.skin(Art.data().graphics["10017"])
 for item in BARRELS[serial]:
  var at=Harbor.point(item[0],item[4] if item.size()>4 else 0,g);var radius:float=item[1];var height:float=item[2]
  Harbor.cask(wood,at+Vector3.UP*height*.5,Vector3.UP,height,radius,item[3])
  # Reuse the intact original lid instead of copying partly occluded lids from a pile.
  for i in 16:
   var a=-i*TAU/16;var b=-(i+1)*TAU/16;var center=at+Vector3.UP*(height+.005)
   var points=[center,center+Vector3(cos(b),0,sin(b))*radius*.80,center+Vector3(cos(a),0,sin(a))*radius*.80]
   var pixels=[Vector2(23,14),Vector2(23+(cos(b)+sin(b))*.7071*17,14+(sin(b)-cos(b))*.7071*10),Vector2(23+(cos(a)+sin(a))*.7071*17,14+(sin(a)-cos(a))*.7071*10)]
   for j in 3:
    cap.surface.set_normal(Vector3.UP);cap.surface.set_uv((Vector2(cap.graphic[0].position)+pixels[j])/cap.texture.get_size());cap.surface.add_vertex(points[j])
 var result=Tina.join(wood.finish(),cap.finish(),Transform3D.IDENTITY);result.set_meta("source_barrels",BARRELS[serial].size())
 return result

static func open_box(g:Dictionary)->Mesh:
 var wood=Harbor.structure();var width=float(g.rect[2])*3/64;var h=width*.78;var t=.12;var half=width*.5
 var base=Harbor.point(Vector2(26,46),0,g)
 wood.part="tina_box_inner";wood.box(AABB(base+Vector3(-half,0,-half),Vector3(width,.08,width)))
 wood.part="tina_box_plank"
 for side in [-1,1]:
  wood.box(AABB(base+Vector3(-half,0,side*half-t*.5),Vector3(width,h,t)))
  wood.box(AABB(base+Vector3(side*half-t*.5,0,-half),Vector3(t,h,width)))
  for y in [h*.28,h*.56,h*.84]:
   wood.box(AABB(base+Vector3(-half-.02,y,side*half-t*.55),Vector3(width+.04,.035,t*1.1)))
   wood.box(AABB(base+Vector3(side*half-t*.55,y,-half-.02),Vector3(t*1.1,.035,width+.04)))
  wood.part="tina_box_inner"
  var x=side*(half-t*.55)
  wood.quad(base+Vector3(x,.08,-side*half),base+Vector3(x,h,-side*half),base+Vector3(x,h,side*half),base+Vector3(x,.08,side*half))
  wood.quad(base+Vector3(side*half,.08,x),base+Vector3(side*half,h,x),base+Vector3(-side*half,h,x),base+Vector3(-side*half,.08,x))
  wood.part="tina_box_plank"
 var result=wood.finish();result.set_meta("source_open_box",10055)
 return result

static func water_prop(serial:int,g:Dictionary)->Mesh:
 var wood=Harbor.structure()
 if serial in [11482,11483]:
  var axis=Vector3.BACK if serial==11482 else Vector3.RIGHT
  var across=Vector3.UP.cross(axis);var center=Harbor.point(Vector2(28,32),0,g)+Vector3.UP*.54
  var length_=3.25;var radius=.52;var inner=.31
  for i in 8:
   var a=-PI*.5-i*PI/8;var b=-PI*.5-(i+1)*PI/8
   var p=Vector3.UP*cos(a)+across*sin(a);var q=Vector3.UP*cos(b)+across*sin(b)
   wood.part="tina_hollow_bark"
   wood.quad(center+p*radius-axis*length_*.5,center+p*radius+axis*length_*.5,center+q*radius+axis*length_*.5,center+q*radius-axis*length_*.5)
   wood.part="tina_box_inner"
   wood.quad(center+q*inner-axis*length_*.5,center+q*inner+axis*length_*.5,center+p*inner+axis*length_*.5,center+p*inner-axis*length_*.5)
   for side in [-1,1]:
    var end=center+axis*side*length_*.5
    wood.part="tina_log_end"
    var ring=[end+p*inner,end+p*radius,end+q*radius,end+q*inner]
    if side<0:ring.reverse()
    wood.quad(ring[0],ring[1],ring[2],ring[3])
    wood.part="tina_box_inner"
    var inside=end-axis*side*.45
    if side>0:wood.quad(end+p*inner,end+q*inner,inside+q*inner,inside+p*inner)
    else:wood.quad(end+q*inner,end+p*inner,inside+p*inner,inside+q*inner)
    var points=[inside,inside+p*inner,inside+q*inner]
    if (points[2]-points[0]).cross(points[1]-points[0]).dot(axis*side)<0:points.reverse()
    for point in points:wood.surface.set_normal(axis*side);wood.surface.set_uv(Vector2(point.x,point.y));wood.surface.set_uv2(wood.tiles[wood.part]);wood.surface.add_vertex(point)
   if cos(a)<-.7 and cos(b)<-.7:
    wood.part="tina_ruin_snow"
    wood.quad(center+p*(radius+.045)-axis*length_*.49,center+p*(radius+.045)+axis*length_*.49,center+q*(radius+.045)+axis*length_*.49,center+q*(radius+.045)-axis*length_*.49)
  var result=wood.finish();result.set_meta("source_hollow_log",axis);return result
 var pail=serial==11481;var radius= .83 if pail else 1.55;var height=1.65 if pail else 1.35
 var center=Harbor.point(Vector2(17,40) if pail else Vector2(36,61),0,g)
 wood.part="tina_pail_wood" if pail else "tina_wash_wood"
 Tina.Parts.kili_round(wood,center,[Vector2(0,0),Vector2(radius*.80,0),Vector2(radius,height),Vector2(radius-.10,height),Vector2(radius*.80-.10,.12),Vector2(0,.12)])
 wood.part="tina_barrel_hoop"
 for y in [height*.18,height*.82]:Tina.Parts.kili_round(wood,center+Vector3.UP*y,[Vector2(radius*(.8+.2*y/height)+.025,0),Vector2(radius*(.8+.2*y/height)+.025,.065)])
 wood.part="tina_wash_water"
 for i in 24:
  var a=-i*TAU/24;var b=-(i+1)*TAU/24;var water_center=center+Vector3.UP*height*.76
  var points=[Vector3.ZERO,Vector3(cos(b),0,sin(b)),Vector3(cos(a),0,sin(a))]
  for point in points:
   wood.surface.set_normal(Vector3.UP);wood.surface.set_uv(Vector2(.5+point.x*.42,.5+point.z*.42));wood.surface.set_uv2(wood.tiles[wood.part]);wood.surface.add_vertex(water_center+point*radius*.87)
 if pail:
  for i in 12:
   var a=i*PI/12;var b=(i+1)*PI/12
   Harbor.rod(wood,center+Vector3(cos(a)*radius,height+sin(a)*radius,0),center+Vector3(cos(b)*radius,height+sin(b)*radius,0),.035,"tina_barrel_hoop")
  var result=wood.finish();result.set_meta("source_water_pail",true);return result
 var native=Harbor.skin(g)
 var corners=[center+Vector3(-1.0,.55,.15),center+Vector3(-1.0,2.8,-.4),center+Vector3(.15,2.8,-.4),center+Vector3(.15,.55,.15)]
 var pixels=[Vector2(5,28),Vector2(17,3),Vector2(40,28),Vector2(25,51)]
 Tina.outward_quad(native,corners,pixels,Vector3(0,1,1))
 wood.part="tina_box_plank"
 for side in [-1,1]:
  var edge=[corners[0],corners[1]] if side<0 else [corners[3],corners[2]]
  Harbor.rod(wood,edge[0],edge[1],.045,"tina_box_plank")
 for a in [0,1]:Harbor.rod(wood,corners[a],corners[3-a],.045,"tina_box_plank")
 # Unseen back uses the existing solid plank paint, without reversed board printing.
 wood.quad(corners[3]+Vector3.FORWARD*.04,corners[2]+Vector3.FORWARD*.04,corners[1]+Vector3.FORWARD*.04,corners[0]+Vector3.FORWARD*.04)
 var result=Tina.join(wood.finish(),native.finish(),Transform3D.IDENTITY);result.set_meta("source_washboard",true);return result
