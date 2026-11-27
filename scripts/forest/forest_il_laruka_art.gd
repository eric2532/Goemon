extends RefCounted
## Source placements share existing solid scenery, furniture, tree and mesh caches.
const Data=preload("res://assets/maps/falan/il_laruka/data.gd")
const Buildings=preload("res://scripts/forest/forest_il_laruka_buildings.gd")
const Solids=preload("res://scripts/forest/forest_original_map_solids.gd")
const Original=preload("res://scripts/forest/forest_original_map_art.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Cliffs=preload("res://scripts/forest/forest_original_cliffs.gd")
const Walls=preload("res://scripts/forest/forest_venoa_walls.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Quay=preload("res://assets/maps/falan/il_laruka/quay-cells.gd")
const IlSource=preload("res://scripts/forest/forest_east_il_source_completion.gd")
const IDS={"il_village":2000,"laruka":2300}
static var graphics={}
static var source_meshes={}

static func owns_room(id:int)->bool:return Data.MAPS.has(id) and id not in [2000,2300]

static func graphic(serial:int)->Dictionary:
 if graphics.is_empty():
  # Shared native sign/wall builders resolve their paint through this same catalog.
  var catalog=Original.data();var page=catalog.pages.size()
  catalog.pages.append("../falan/il_laruka/paint.png");catalog.solid_pages.append("../falan/il_laruka/paint.png")
  for key in Data.GRAPHICS:
   var g:Dictionary=Data.GRAPHICS[key].duplicate(true);g.page=page
   g["shore_bank"]=g.get("shore_bank",false) or int(key) in range(12500,12536)
   graphics[key]=g
  catalog.graphics.merge(graphics,false)
 return graphics[str(serial)]

static func scenery_mesh(serial:int,g:Dictionary)->Mesh:
 if serial in range(16566,16578):
  if not source_meshes.has(serial):
   var r=g.rect;var span=Vector2(g.footprint[0],g.footprint[1])*3
   var art=[Rect2(r[0],r[1],r[2],r[3]),-Vector2(g.origin[0],g.origin[1]),span,r[3]]
   var counter=preload("res://scripts/forest/forest_coastal_rooms.gd").painted_shape(serial,"coast_counter",art,Data.ATLAS)
   source_meshes[serial]=preload("res://scripts/forest/forest_falan_proportions.gd").transformed(counter,Transform3D(Basis.IDENTITY,Vector3((span.x-3)*.5,0,(3-span.y)*.5)))
  return source_meshes[serial]
 if serial in range(11252,11266):return Walls.prepare(serial)
 if serial in range(12536,12566) and Cliffs.owns(serial):
  if not source_meshes.has(serial):source_meshes[serial]=Cliffs.mesh(serial,g)
  return source_meshes[serial]
 if serial in [11010,11011]:
  if not source_meshes.has(serial):
   var r=g.rect;var w=float(g.footprint[0])*3;var d=float(g.footprint[1])*3
   var skin=Source.new([Rect2(r[0],r[1],r[2],r[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],Data.ATLAS,.045)
   var log_=CylinderMesh.new();log_.height=w;log_.top_radius=.24;log_.bottom_radius=.24;log_.radial_segments=8
   for i in ceili(d/.48):
    var at=Vector3((w-3)*.5,0,1.26-i*.48)
    Solids.append(skin,log_,Transform3D(Basis(Vector3.BACK,PI*.5),at))
   source_meshes[serial]=skin.finish()
  return source_meshes[serial]
 var family=Solids.kind(serial,false,g)
 var texture=Data.SURFACES[int(g.surfaces[0])] if family=="rock" or family=="wall" and serial in Solids.WALLS else Data.ATLAS
 return Solids.mesh(serial,family,g,texture)

static func point(id:int,row:Array)->Vector2:
 return (Vector2(row[0],row[1])-Vector2(Data.SIZES[id]/2))*3.0

static func shared_gate(area:String,row:Array)->bool:
 var at=point(IDS[area],row);var serial:int=row[2]
 if area=="il_village":return serial in [11032,11077,11078,11140,11141,11142,11144,11147,11148] and at.distance_to(Regions.IL_GATE)<40
 return serial in [11077,11078,11254,11257,11260,11261,11263,11264,11374] and at.distance_to(Regions.LARUKA_GATE)<28

static func building_mesh(serial:int)->Mesh:
 return Buildings.prepare(serial)

static func plan(model,area:String,offset:Vector2=Vector2.ZERO,approach:bool=false)->Array:
 var id:int=IDS[area];var result=[]
 for row in IlSource.rows(id,Data.MAPS[id]):
  var serial:int=row[2]
  if shared_gate(area,row):continue
  var g=graphic(serial);var at=point(id,row)+Vector2((g.footprint[0]-1)*1.5,-(g.footprint[1]-1)*1.5)
  if approach and (at.x< -25 or absf(at.y+18)>55):continue
  at+=offset
  var p=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
  if serial not in Data.BUILDINGS:
   var family=Solids.kind(serial,false,g)
   if family=="tree":
    result.append(["il_laruka_obstacle",Transform3D.IDENTITY,AABB(p-Vector3(.48,0,.48),Vector3(.96,5,.96)),true])
   elif family in ["fence","detail_palisade","wall"]:
    var shape=scenery_mesh(serial,g)
    var anchor=point(id,row)+offset
    var bounds=shape.get_aabb();bounds.position+=Vector3(anchor.x,p.y,anchor.y)
    result.append(["il_laruka_obstacle",Transform3D.IDENTITY,bounds,family=="fence"])
   elif serial in range(12536,12566):
    var span=Vector3(g.footprint[0]*3-.35,8,g.footprint[1]*3-.35)
    result.append(["il_laruka_obstacle",Transform3D.IDENTITY,AABB(p-Vector3(span.x*.5,0,span.z*.5),span)])
   continue
  var extent=Vector3(g.footprint[0]*3-.35,12,g.footprint[1]*3-.35)
  var bounds=AABB(p-Vector3(extent.x*.5,0,extent.z*.5),extent)
  result.append(["il_laruka_building",Transform3D(Basis.IDENTITY,p),bounds,serial])
 return result

static func build_building(root:Node3D,p:Vector3,serial:int):
 if serial==11268:
  load("res://scripts/forest/forest_il_chief.gd").build(root,p)
  return
 if serial in [10607,10603]:
  var civic=load("res://scripts/forest/forest_falan_civic_exterior.gd")
  var spec:Array=civic.SHELLS[Vector2i(-42,-23)].duplicate();spec[3]=Vector2(p.x,p.z)
  var node=civic.build(root,p,spec)
  node.rotation.y=-PI*.5 if serial==10607 else 0.0
  node.name="BlueCGVillageBuilding_"+str(serial);node.set_meta("source_graphic",serial)
 else:
  var node=Geo.mesh(root,building_mesh(serial),p,null)
  node.name="BlueCGVillageBuilding_"+str(serial);node.set_meta("source_graphic",serial)
  if serial==11268:
   var vane=Sprite3D.new();vane.texture=preload("res://assets/maps/falan/il_laruka/chief-rooster.png")
   vane.pixel_size=.028;vane.position=p+Vector3.UP*13.70;vane.rotation.y=-PI*.25
   vane.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;root.add_child(vane)

static func build_exterior(root:Node3D,model,area:String,offset:Vector2=Vector2.ZERO,approach:bool=false):
 var id:int=IDS[area];var groups={};var trees={}
 for row in IlSource.rows(id,Data.MAPS[id]):
  var serial:int=row[2]
  if IlSource.owns_bank(id,row) or (Regions.private_source_context!=null and Regions.private_source_context.owns(model) and serial in range(12500,12536)):continue
  if shared_gate(area,row):continue
  if serial in Data.BUILDINGS:continue
  var at=point(id,row)
  if approach and (at.x< -12 or absf(at.y+18)>36):continue
  at+=offset
  var g=graphic(serial);var family=Solids.kind(serial,false,g)
  if family=="void":continue
  var p=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
  if family=="tree":
   var asset=Assets.crossgate_tree(serial)
   if not trees.has(asset):trees[asset]=[]
   trees[asset].append(Transform3D(Basis.IDENTITY,p))
   continue
  if not groups.has(serial):groups[serial]=[]
  groups[serial].append(Transform3D(Basis.IDENTITY,p))
 batch(root,groups,area)
 IlSource.build_banks(root,model,area,offset,approach)
 if Regions.private_source_context!=null and Regions.private_source_context.owns(model):Regions.private_source_context.build_banks(root,model)
 for asset in trees:Assets.batch(root,asset,trees[asset],true)
 if area=="laruka" and not approach:build_quay(root,model)

static func paved(at:Vector2)->bool:
 var cell=Vector2i((at/3.0+Vector2(Data.SIZES[2300]/2)).round())
 return Quay.CELLS.has(cell) or Quay.CAPS.has(cell)

static func quay_triangle(skin,points:Array,paint:String):
 var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
 for p:Vector3 in points:
  skin.surface.set_normal(normal)
  skin.surface.set_uv2(Buildings.Surfaces.TILES[paint])
  var uv=Vector2(p.x,-p.z)/3.0 if paint=="quay_paving" else Vector2(p.z if absf(normal.x)>absf(normal.z) else p.x,-p.y)/2.6
  skin.surface.set_uv(uv);skin.surface.add_vertex(p+normal*.025)

static func build_quay(root:Node3D,model):
 var skin=Source.new([],Buildings.Atlas,.045);skin.tiles=Buildings.Surfaces.TILES
 var blocks={}
 for cell:Vector2i in Quay.CAPS:
  for off in [Vector2i(-1,-1),Vector2i(-1,0),Vector2i(0,-1),Vector2i.ZERO]:blocks[cell+off]=true
 for cell:Vector2i in Quay.CELLS:
  for off in [Vector2i(-1,-1),Vector2i(-1,0),Vector2i(0,-1),Vector2i.ZERO]:blocks[cell+off]=true
  # Quarter cells follow the existing terrain triangles, without flattening collision.
  var center=(Vector2(cell)-Vector2(Data.SIZES[2300]/2))*3.0
  for x in [-1,0]:
   for z in [-1,0]:
    var points=[]
    for off in [Vector2(x,z),Vector2(x+1,z),Vector2(x,z+1),Vector2(x+1,z+1)]:
     var at=center+off*1.5;points.append(Vector3(at.x,model.surface_height(at.x,at.y),at.y))
    for tri in [[0,1,2],[1,3,2]]:
     var p=[points[tri[0]],points[tri[1]],points[tri[2]]]
     if maxf(p[0].y,maxf(p[1].y,p[2].y))-minf(p[0].y,minf(p[1].y,p[2].y))<.05:quay_triangle(skin,p,"quay_paving")
 for cell:Vector2i in blocks:
  var points=[]
  for off in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
   var at=(Vector2(cell+off)-Vector2(Data.SIZES[2300]/2))*3.0
   points.append(Vector3(at.x,model.surface_height(at.x,at.y),at.y))
  for tri in [[0,1,2],[1,3,2]]:
   var p=[points[tri[0]],points[tri[1]],points[tri[2]]]
   if maxf(p[0].y,maxf(p[1].y,p[2].y))-minf(p[0].y,minf(p[1].y,p[2].y))>.05:quay_triangle(skin,p,"quay_brick")
 var node=Geo.mesh(root,skin.finish(),Vector3.ZERO,null);node.name="LarukaQuaySurfaces"
 node.set_meta("source_paving_cells",Quay.CELLS.size())

static func batch(root:Node3D,groups:Dictionary,area:String=""):
 var owner=Node3D.new();owner.name="ArchivedIlGardens" if area=="il_village" else "IlLarukaSourceScenery";root.add_child(owner)
 var native_props={}
 var east_props=load("res://scripts/forest/forest_east_village_props.gd") if area=="il_village" else null
 for serial in groups:
  if east_props!=null and east_props.owns(serial):native_props[serial]=groups[serial];continue
  var g=graphic(serial);var family=Solids.kind(serial,false,g)
  if family=="void":continue
  var mesh=scenery_mesh(serial,g)
  var node=MultiMeshInstance3D.new();node.name="NativeGraphic_"+str(serial);node.set_meta("source_graphic",serial)
  if serial==11078 and area in IDS:node.name="IlVillageTimberGate" if area=="il_village" else "LarukaOpenGate"
  node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
  node.multimesh.mesh=mesh;node.multimesh.instance_count=groups[serial].size()
  for i in groups[serial].size():node.multimesh.set_instance_transform(i,groups[serial][i])
  owner.add_child(node)
 if east_props!=null:east_props.batch(owner,native_props)

static func build_room(root:Node3D,id:int,origin:Vector2)->Dictionary:
 var cells={};var groups={}
 for row in Data.MAPS[id]:
  var serial:int=row[2];var g=graphic(serial)
  if g.family=="void":continue
  for z in g.footprint[1]:
   for x in g.footprint[0]:cells[Vector2i(row[0]+x,row[1]-z)]=true
  var p=origin+Vector2(row[0],row[1])*3
  if not groups.has(serial):groups[serial]=[]
  var y=-scenery_mesh(serial,g).get_aabb().end.y+.02 if serial in [16594,16595] else 0.0
  groups[serial].append(Transform3D(Basis.IDENTITY,Vector3(p.x,y,p.y)))
 batch(root,groups)
 root.set_meta("il_laruka_source_objects",Data.MAPS[id].size())
 return cells

static func stair_openings(id:int)->Dictionary:
 var cells={}
 for row in Data.MAPS.get(id,[]):
  if row[2] not in [16594,16595]:continue
  var g:Dictionary=Data.GRAPHICS[str(row[2])]
  for z in g.footprint[1]:
   for x in g.footprint[0]:cells[Vector2i(row[0]+x,row[1]-z)]=true
 return cells
