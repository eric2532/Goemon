extends RefCounted
## Omitted source street fixtures, prepared/batched in the existing outdoor setup.
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Kit=preload("res://scripts/forest/forest_coastal_buildings.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Atlas=preload("res://assets/maps/falan/village_street_props/native.png")
const FLAT=[10410,11003,11005,11103,11104,11114,11127,11213,11214,11226,11227,11228,11299]
static var data:Dictionary={}
static var meshes={}
static var tree_fits={}
static func catalog()->Dictionary:
 if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/village_street_props/data.json"))
 return data
static func flat(serial:int,g:Dictionary)->Mesh:
 var r:Array=g.rect;var origin=Vector2(-g.origin[0],-g.origin[1])
 var skin=Source.new([Rect2(r[0],r[1],r[2],r[3]),origin,Vector2.ONE,0],Atlas,.045)
 var points=[]
 # Fine cloth, notices and bones keep native cutout paint on a fixed plane, with a solid reverse.
 for pixel in [Vector2.ZERO,Vector2(0,r[3]),Vector2(r[2],r[3]),Vector2(r[2],0)]:
  var u=(pixel.x-origin.x)/Fit.HORIZONTAL
  var v=(pixel.y-origin.y)/Fit.FLOOR
  points.append(Vector3((u-v)*.5,.035,(u+v)*.5) if g.ground else Vector3(u*.5,(origin.y-pixel.y)/Fit.VERTICAL,u*.5))
 skin.quad(points[0],points[1],points[2],points[3]);skin.quad(points[3],points[2],points[1],points[0])
 return skin.finish()
static func cart(serial:int,g:Dictionary)->Mesh:
 var r:Array=g.rect;var skin=Source.new([Rect2(r[0],r[1],r[2],r[3]),Vector2(-g.origin[0],-g.origin[1]),Vector2.ONE,0],Atlas,.045)
 skin.box(AABB(Vector3(-.8,.65,-1.1),Vector3(1.6,.14,2.2)))
 for side in [-1,1]:
  skin.box(AABB(Vector3(side*.71,.7,-1.1),Vector3(.09,.20,3.8)))
  var wheel=CylinderMesh.new();wheel.top_radius=.66;wheel.bottom_radius=.66;wheel.height=.14;wheel.radial_segments=16;wheel.rings=1
  Forms.append(skin,wheel,Transform3D(Basis(Vector3.FORWARD,PI*.5),Vector3(side*.93,.66,-.05)))
 var raw=skin.finish();var turn=Basis(Vector3.UP,PI*.5 if serial==11023 else 0.)
 var points=Fit.mesh_points(raw,Transform3D(turn,Vector3.ZERO))
 var target=Rect2(g.origin[0]+g.bounds[0],g.origin[1]+g.bounds[1],g.bounds[2]-g.bounds[0],g.bounds[3]-g.bounds[1])
 return Fit.transformed(raw,Fit.measure(points,"",Basis(Vector3.UP,PI*.5),target)*Transform3D(turn,Vector3.ZERO))
static func mesh(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=catalog().graphics[str(serial)]
 if serial in FLAT:meshes[serial]=flat(serial,g)
 elif serial in [11022,11023]:meshes[serial]=cart(serial,g)
 else:
  var original:Dictionary=Art.data().graphics.get(str(serial),{}).duplicate(true)
  var texture:Texture2D
  if original.is_empty():original=g.duplicate(true);texture=Atlas
  else:texture=Art.solid_texture(int(original.page))
  var family:String=Forms.kind(serial,false,original)
  if serial in [11132,11133,11136,11137,11138]:family="pillar"
  if serial in [10015,10016,10017]:family="barrel"
  if serial in [11017,11018]:family="crate"
  if serial==10036:family="table"
  if serial==10408:family="bench"
  if serial==11141:family="detail_palisade"
  if serial==11144:family="pillar"
  if serial==11170:family="cactus"
  if serial in [16790,16793]:family="coast_pot"
  if serial==16648:family="coast_bird"
  var raw:Mesh=Forms.mesh(serial,family,original,texture)
  var b:Array=g.bounds;var target=Rect2(g.origin[0]+b[0],g.origin[1]+b[1],b[2]-b[0],b[3]-b[1])
  var fitted=Fit.transformed(raw,Fit.measure(Fit.mesh_points(raw),"",Basis(Vector3.UP,PI*.5),target))
  # Reproject after fitting so a tiny source rock never samples a whole tile of shadow.
  var skin=Source.new([Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]),Vector2(-g.origin[0],-g.origin[1]),Vector2.ONE,0],Atlas,1./Fit.VERTICAL)
  for slot in fitted.get_surface_count():
   var arrays=fitted.surface_get_arrays(slot);var indices=arrays[Mesh.ARRAY_INDEX]
   var indexed=indices is PackedInt32Array and not indices.is_empty()
   for j in (indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()):
    var i=indices[j] if indexed else j
    skin.vertex(arrays[Mesh.ARRAY_VERTEX][i],arrays[Mesh.ARRAY_NORMAL][i])
  meshes[serial]=skin.finish()
 return meshes[serial]
static func tree_pose(serial:int)->Transform3D:
 if tree_fits.has(serial):return tree_fits[serial]
 var g:Dictionary=catalog().graphics[str(serial)];var points:Array[Vector3]=[]
 var turn=Transform3D(Basis(Vector3.UP,-PI*.25),Vector3.ZERO)
 for part in Meadow.source(Meadow.crossgate_tree(10085)):points.append_array(Fit.mesh_points(part.mesh,turn*part.transform))
 var b:Array=g.bounds;var target=Rect2(g.origin[0]+b[0],g.origin[1]+b[1],b[2]-b[0],b[3]-b[1])
 tree_fits[serial]=Fit.measure(points,"",Basis(Vector3.UP,PI*.5),target)*turn
 return tree_fits[serial]
static func build(root:Node3D,model):
 var area:String=model.falan_area
 if area not in ["kili","ghana"]:return
 var origin:Vector2=load("res://scripts/forest/forest_freyja_regions.gd").Sites.VILLAGES[area][2]
 var groups={};var trees={};var count=0
 for row in catalog().areas[area]:
  var serial=int(row[2]);var at=origin+Vector2(row[0],row[1])*3.
  var pose=Transform3D(Basis.IDENTITY,Vector3(at.x,model.surface_height(at.x,at.y),at.y))
  var target=trees if serial in range(11150,11160) else groups
  if not target.has(serial):target[serial]=[]
  target[serial].append(pose);count+=1
 for serial in groups:mesh(serial)
 load("res://scripts/forest/forest_kili_art.gd").batch_meshes(root,groups,meshes,"NativeVillageFixture")
 for serial in trees:
  for i in trees[serial].size():trees[serial][i]*=tree_pose(serial)
  var leaf:Array=catalog().graphics[str(serial)].leaf_rgb
  var palette:Array=load("res://scripts/forest/forest_ruby_region_art.gd").catalog().palettes["10085"]
  Meadow.batch(root,Meadow.crossgate_tree(10085),trees[serial],true,0.,Color(leaf[0]/palette[0],leaf[1]/palette[1],leaf[2]/palette[2]))
 root.set_meta("kili_ghana_native_fixtures",count)
