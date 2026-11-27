extends RefCounted
## Exact East source IDs reuse complete existing masters; layout/physics stay with their owners.
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Tiles=preload("res://assets/maps/original_crossgate/building-surfaces.gd")
const Atlas=preload("res://assets/maps/original_crossgate/building-surfaces.png")
const Timber=preload("res://scripts/forest/forest_il_laruka_buildings.gd")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Profiles=preload("res://scripts/forest/forest_east_fallback_families.gd")
const ROOT="res://assets/maps/falan/east_region/classic_architecture/"
static var catalog:Dictionary={}
static var meshes:Dictionary={}

static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog

static func owns(serial:int)->bool:return data().graphics.has(str(serial))

static func frame_axis(token:String)->Vector3:
 return Vector3.RIGHT if token=="x" else Vector3.LEFT if token=="-x" else Vector3.FORWARD if token=="-z" else Vector3.BACK

static func timber_fence(g:Dictionary)->Mesh:
 var skin=Source.new([],Atlas,.045);skin.tiles=Tiles.TILES;skin.part="timber"
 var spec:Dictionary=g.fence;var high=2.1;var placed={}
 var segments=[]
 if spec.has("segments"):
  for line:Array in spec.segments:segments.append([Vector3(line[0][0],0,line[0][1]),Vector3(line[1][0],0,line[1][1]),int(line[2])])
 else:
  for index in spec.arms.size():
   var axis=frame_axis(spec.arms[index]);var length_=float(spec.get("lengths",[])[index] if spec.has("lengths") else spec.length)
   var start=-axis*length_*.5 if spec.arms.size()==1 else Vector3.ZERO
   segments.append([start,start+axis*length_,int(spec.get("stations",[])[index] if spec.has("stations") else spec.posts)])
 for line:Array in segments:
  var start:Vector3=line[0];var end:Vector3=line[1];var count_=int(line[2]);var length_=start.distance_to(end)
  for index in count_:
   var p=start.lerp(end,float(index)/maxi(1,count_-1))
   if placed.has(p):continue
   placed[p]=true
   Timber.bar(skin,p,p+Vector3.UP*(high-.22),.18)
   var spike=CylinderMesh.new();spike.top_radius=0;spike.bottom_radius=.15;spike.height=.24;spike.radial_segments=4;spike.rings=0
   var arrays=spike.get_mesh_arrays()
   for vertex in arrays[Mesh.ARRAY_INDEX]:
    var q:Vector3=arrays[Mesh.ARRAY_VERTEX][vertex]+p+Vector3.UP*(high-.10);var n:Vector3=arrays[Mesh.ARRAY_NORMAL][vertex]
    skin.surface.set_normal(n);skin.surface.set_uv2(skin.tiles.timber);skin.surface.set_uv(Vector2(q.x+q.z,-q.y));skin.surface.add_vertex(q)
  for y in [.48,1.48]:Timber.bar(skin,start+Vector3.UP*y,end+Vector3.UP*y,.16)
  if spec.style=="slat":
   for index in ceili(length_/.31):
    var p=start.lerp(end,(index+.5)/ceili(length_/.31));Timber.bar(skin,p+Vector3.UP*.51,p+Vector3.UP*1.43,.22)
   Timber.bar(skin,start+Vector3.UP*1.57,end+Vector3.UP*1.57,.22)
 return skin.finish()

static func iron_fence(g:Dictionary)->Mesh:
 var spec:Dictionary=g.fence;var boxes=Boxes.new();var iron=Fort.material(Color(g.iron_rgb[0],g.iron_rgb[1],g.iron_rgb[2]),false)
 for token:String in spec.arms:
  var axis=frame_axis(token);var center=Vector3.ZERO if spec.arms.size()==1 else axis*1.4
  if spec.get("partial",false):
   for index in [1,2]:
    var at=axis*(float(index)*.5);boxes.add(at+Vector3.UP*1.35,Vector3(.09,2.7,.09),iron)
    boxes.add(at+Vector3.UP*2.76,Vector3(.16,.18,.16),iron)
   for y in [.40,2.2]:boxes.add(axis*.5+Vector3.UP*y,Vector3(.12,.10,1.1) if absf(axis.z)>.5 else Vector3(1.1,.10,.12),iron)
  else:Court.ironwork(boxes,center,10675 if absf(axis.z)>.5 else 10674,iron)
 if spec.style!="grille":
  # The source solitary/corner posts reuse closed stepped metal courses.
  for row in [[.18,.18,0.],[.12,2.65,.18],[.20,.16,2.78],[.10,.32,2.94]]:
   var width=float(row[0])*2.;var height=float(row[1]);var y=float(row[2])
   boxes.add(Vector3(0,y+height*.5,0),Vector3(width,height,width),iron)
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);var cube=BoxMesh.new();cube.size=Vector3.ONE
 for group:Dictionary in boxes.groups.values():
  for pose:Transform3D in group.transforms:tool.append_from(cube,0,Transform3D(Basis.IDENTITY,group.origin)*pose)
 var result=tool.commit();result.surface_set_material(0,iron);return result

static func measured_pier(g:Dictionary)->Mesh:
 var base=Source.new([],load(ROOT+str(g.serial)+"-surfaces.png"),.045)
 base.tiles={"stone":Vector2.ZERO,"gold":Vector2.ZERO,"cap":Vector2(128,0)}
 base.pitches={"stone":1.4,"gold":1.4,"cap":1.4}
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],Atlas,.045)
 var rows=[]
 for row:Array in g.profile:rows.append(Vector3(row[0],row[1],row[2]))
 if not g.round:
  if g.blue_foundation:
   var split=maxi(1,floori(rows.size()*.28));base.tiles.stone=Vector2(256,0)
   Profiles.profile(base,front,rows.slice(0,split+1),Vector3.ZERO,.035)
   base.tiles.stone=Vector2.ZERO;Profiles.profile(base,front,rows.slice(split),Vector3.ZERO,.035)
  else:Profiles.profile(base,front,rows,Vector3.ZERO,.035)
 else:
  var radius=rows.map(func(row:Vector3):return row.x).max()
  for index in rows.size()-1:
   var low:Vector3=rows[index];var high:Vector3=rows[index+1]
   base.part="cap" if high.y>rows[-1].y*.90 or low.y<rows[-1].y*.12 else "stone"
   for side in 24:
    var a=-side*TAU/24.;var b=-(side+1)*TAU/24.
    var points=[Vector3(cos(a)*low.x,low.y,sin(a)*low.x),Vector3(cos(a)*high.x,high.y,sin(a)*high.x),Vector3(cos(b)*high.x,high.y,sin(b)*high.x),Vector3(cos(b)*low.x,low.y,sin(b)*low.x)]
    for corner in [0,1,2,0,2,3]:
     var p:Vector3=points[corner];var angle=a if corner<2 else b
     base.surface.set_normal(Vector3(cos(angle),0,sin(angle)));base.surface.set_uv2(base.tiles[base.part])
     base.surface.set_uv(Vector2(-angle*radius,-p.y)/1.4);base.surface.add_vertex(p)
  base.part="cap"
  for top in [false,true]:
   var row:Vector3=rows[-1] if top else rows[0];var center=Vector3.UP*row.y
   for side in 24:
    var a=side*TAU/24.;var b=(side+1)*TAU/24.;var p=center+Vector3(cos(a)*row.x,0,sin(a)*row.x);var q=center+Vector3(cos(b)*row.x,0,sin(b)*row.x)
    for point:Vector3 in ([center,p,q] if top else [center,q,p]):
     base.surface.set_normal(Vector3.UP if top else Vector3.DOWN);base.surface.set_uv2(base.tiles.cap)
     base.surface.set_uv(Vector2(point.x,point.z)/1.4);base.surface.add_vertex(point)
 var result=base.finish();var material:ShaderMaterial=result.surface_get_material(0).duplicate();material.set_shader_parameter("original_palette",false);result.surface_set_material(0,material)
 return result

static func tiled_surface(reference:Mesh,slot:int,wall:bool)->Mesh:
 var base=Source.new([],Atlas,.045);base.tiles=Tiles.TILES
 var arrays=reference.surface_get_arrays(slot);var indices=arrays[Mesh.ARRAY_INDEX]
 var indexed=indices is PackedInt32Array and not indices.is_empty()
 for j in (indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()):
  var i=indices[j] if indexed else j;var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var n:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
  var role="timber"
  if wall:role="stone" if n.y>.5 else "timber" if absf(n.x)>.03 and absf(n.z)>.03 else "plaster"
  base.surface.set_normal(n);base.surface.set_uv2(base.tiles[role])
  var axis=Vector3.RIGHT if absf(n.z)>.5 else Vector3.BACK
  base.surface.set_uv(Vector2(p.dot(axis),-p.y)/1.4 if absf(n.y)<.7 else Vector2(p.x,p.z)/1.4)
  base.surface.add_vertex(p)
 return base.finish()

static func close_reused_paint(reference:Mesh,serial:int,g:Dictionary)->Mesh:
 var result=ArrayMesh.new()
 for slot in reference.get_surface_count():
  var part:Mesh=tiled_surface(reference,slot,true) if g.kit=="venoa_wall" else reference
  var from_slot=0 if g.kit=="venoa_wall" else slot
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.surface_get_arrays(from_slot));result.surface_set_material(result.get_surface_count()-1,part.surface_get_material(from_slot))
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(ROOT+str(serial)+"-front.png"),.045)
 for slot in reference.get_surface_count():
  var arrays=reference.surface_get_arrays(slot);var indices=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty()
  for j in (indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()):
   var i=indices[j] if indexed else j;var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var n:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
   if n.dot(Vector3(-1,1.603567,1))>0:front.projected_vertex(p+n*.006,n,p)
 var observed=front.finish();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,observed.surface_get_arrays(0));result.surface_set_material(result.get_surface_count()-1,observed.surface_get_material(0))
 return result

static func independent_house_back(reference:Mesh,kit:String)->Mesh:
 var result=ArrayMesh.new()
 for slot in reference.get_surface_count():
  if kit=="kili_house" and slot>0:
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,reference.surface_get_arrays(slot));result.surface_set_material(result.get_surface_count()-1,reference.surface_get_material(slot));continue
  var observed=SurfaceTool.new();observed.begin(Mesh.PRIMITIVE_TRIANGLES)
  var reverse=Source.new([],Atlas,.045);reverse.tiles=Tiles.TILES
  var arrays=reference.surface_get_arrays(slot);var indices=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty()
  for j in range(0,indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size(),3):
   var first=indices[j] if indexed else j;var n:Vector3=arrays[Mesh.ARRAY_NORMAL][first]
   var hidden=n.dot(Vector3(-1,0,1))<-.01
   for corner in 3:
    var i=indices[j+corner] if indexed else j+corner;var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i]
    if not hidden:
     observed.set_normal(arrays[Mesh.ARRAY_NORMAL][i]);observed.set_uv(arrays[Mesh.ARRAY_TEX_UV][i])
     if arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array and not arrays[Mesh.ARRAY_TEX_UV2].is_empty():observed.set_uv2(arrays[Mesh.ARRAY_TEX_UV2][i])
     observed.add_vertex(p)
    else:
     var role="woodwall" if kit=="venoa_house" else "plaster"
     if n.y>.25:role="blue_roof" if kit=="venoa_house" else "stone"
     elif n.y<-.25:role="timber"
     reverse.surface.set_normal(n);reverse.surface.set_uv2(reverse.tiles[role])
     var axis=Vector3.RIGHT if absf(n.z)>.5 else Vector3.BACK
     reverse.surface.set_uv(Vector2(p.dot(axis),-p.y)/1.6 if absf(n.y)<.7 else Vector2(p.x,p.z)/1.6);reverse.surface.add_vertex(p)
  var front_mesh=observed.commit()
  if front_mesh!=null:
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,front_mesh.surface_get_arrays(0));result.surface_set_material(result.get_surface_count()-1,reference.surface_get_material(slot))
  var back_mesh=reverse.finish();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,back_mesh.surface_get_arrays(0));result.surface_set_material(result.get_surface_count()-1,back_mesh.surface_get_material(0))
 return result

static func mesh(serial:int,graphic:Dictionary={})->Mesh:
 assert(owns(serial),"Unenrolled East architecture graphic")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)]
 g["serial"]=serial
 if not graphic.is_empty():assert(graphic.rgba_sha256==g.source_rgba_sha256,"Regenerate stale East architecture metadata")
 var raw:Mesh
 match g.kit:
  "city_house":raw=load("res://scripts/forest/forest_falan_architecture.gd").prepare(serial)
  "city_magic_shop":raw=load("res://scripts/forest/forest_falan_magic_shop.gd").prepare()
  "east_village":raw=load("res://scripts/forest/forest_east_village_buildings.gd").prepare(serial)
  "venoa_house":raw=load("res://scripts/forest/forest_venoa_buildings.gd").prepare(serial)
  "il_house":raw=load("res://scripts/forest/forest_il_laruka_buildings.gd").prepare(serial)
  "kili_house":raw=load("res://scripts/forest/forest_coastal_buildings.gd").shape(serial)
  "kili_wall":raw=load("res://scripts/forest/forest_kili_art.gd").prepare_wall(serial)
  "venoa_wall":raw=load("res://scripts/forest/forest_venoa_walls.gd").prepare(serial)
  "supported_sign":
   Art.load_east()
   var native:Dictionary=Art.data().graphics[str(serial)]
   raw=load("res://scripts/forest/forest_original_map_details.gd").sign_mesh(serial,native)
  "timber_fence":raw=timber_fence(g)
  "iron_fence":raw=iron_fence(g)
  "measured_pier":raw=measured_pier(g)
  _:assert(false,"Every enrolled architecture ID must have an existing compatible source owner")
 assert(raw!=null,"Existing source owner must produce a complete mesh")
 var result:Mesh=raw
 if g.kit!="supported_sign":
  var b:Array=g.visible
  var target=Rect2(Vector2(g.origin[0]+b[0],g.origin[1]+b[1]),Vector2(b[2]-b[0],b[3]-b[1]))
  var pose=Fit.measure(Fit.mesh_points(raw),"",Basis(Vector3.UP,PI*.5),target)
  var owner=Transform3D(Basis.IDENTITY.scaled(Vector3(1,.045*Fit.VERTICAL,1)),Vector3.ZERO)
  result=Fit.transformed(raw,owner*pose)
 if g.kit in ["kili_wall","venoa_wall","timber_fence","iron_fence","measured_pier"]:result=close_reused_paint(result,serial,g)
 elif g.kit in ["kili_house","venoa_house"]:result=independent_house_back(result,g.kit)
 elif g.kit=="supported_sign":
  var complete=ArrayMesh.new()
  for slot in result.get_surface_count():
   var part:Mesh=tiled_surface(result,slot,false) if slot>0 else result
   var from_slot=0 if slot>0 else slot
   complete.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.surface_get_arrays(from_slot));complete.surface_set_material(complete.get_surface_count()-1,part.surface_get_material(from_slot))
  result=complete
 result.set_meta("east_existing_architecture",serial);result.set_meta("reused_source_kit",g.kit)
 result.set_meta("source_rgba_sha256",g.source_rgba_sha256);result.set_meta("source_footprint",g.footprint)
 result.set_meta("inferred_hidden_geometry",true)
 meshes[serial]=result
 return result
