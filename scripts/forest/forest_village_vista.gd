extends RefCounted
## Static views of the adjoining region; the visited village retains gameplay ownership.
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Entrances=preload("res://scripts/forest/forest_freyja_destination_art.gd")
const TRIANGLES=[Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]

static func build(parent:Node3D,model,ground:ShaderMaterial):
 var area:String=model.falan_area
 if area not in ["il_village","alyut"]:return
 var region="east_coast" if area=="il_village" else "north_coast"
 var offset:Vector2=Regions.IL_TO_ROAD if area=="il_village" else Regions.ALYUT_TO_ROAD
 var village:Rect2=model.terrain.mask_bounds()
 var village_mask:Image=model.terrain.mask_texture().get_image()
 var village_origin:Vector2=model.terrain.mask_origin()
 var bounds=village.grow(210.0)
 var terrain=Terrain.new()
 terrain.variant=region
 terrain.horizontal_scale=2.0
 terrain.configure([])
 var root=Node3D.new()
 root.name="VillageCountrysideView"
 parent.add_child(root)
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var mask:Image=terrain.mask_texture().get_image()
 var origin:Vector2=terrain.mask_origin()
 for z in range(floori(bounds.position.y/3),ceili(bounds.end.y/3)):
  for x in range(floori(bounds.position.x/3),ceili(bounds.end.x/3)):
   var at=Vector2(x,z)*3.0
   if village_land(village_mask,village_origin,at+Vector2.ONE*1.5):continue
   var pixel=Vector2i(((at+offset+Vector2.ONE*1.5-origin)/3.0).round())
   if not Rect2i(Vector2i.ZERO,mask.get_size()).has_point(pixel):continue
   var tile=mask.get_pixelv(pixel)
   if tile.a<.5 or tile.r>.5:continue
   for corner:Vector2 in TRIANGLES:
    var p=at+corner*3.0
    var outside=p+offset
    surface.add_vertex(Vector3(p.x,terrain.height(outside.x,outside.y),p.y))
 surface.generate_normals()
 var material:ShaderMaterial=ground.duplicate()
 material.set_shader_parameter("clip_village",false)
 preload("res://scripts/forest/forest_freyja_art.gd").archive_surface(material,terrain)
 var frame:Transform2D=Regions.frame(region)
 var source=frame.origin+offset
 material.set_shader_parameter("freyja_frame",Vector4(source.x,source.y,1,0))
 material.set_shader_parameter("detail_mask",terrain.mask_texture())
 var outside_bounds:Rect2=terrain.mask_bounds()
 material.set_shader_parameter("detail_bounds",Vector4(outside_bounds.position.x-offset.x,outside_bounds.position.y-offset.y,outside_bounds.size.x,outside_bounds.size.y))
 Geo.mesh(root,surface.commit(),Vector3.ZERO,material).name="AdjoiningLandscape"
 var trees={}
 for row in Regions.Data.TREES[region]:
  var at:Vector2=row[0]-offset
  if village_land(village_mask,village_origin,at) or not bounds.has_point(at):continue
  var serial:int=row[1]
  var kind="cedar_tree" if serial<=10065 else "pine_tree" if serial<=10073 else "broadleaf_tree"
  if not trees.has(kind):trees[kind]=[]
  var p:Vector2=row[0]
  trees[kind].append(Transform3D(Basis(Vector3.UP,p.x*.13).scaled(Vector3.ONE*1.6),Vector3(at.x,terrain.height(p.x,p.y),at.y)))
 for kind in trees:Assets.batch(root,kind,trees[kind],true)
 var plants={}
 for row in preload("res://assets/maps/falan/east_gate_scenery_data.gd").DETAILS:
  var outside:Vector2=Regions.frame(region).inverse()*(row[0]*3.0)
  var at:Vector2=outside-offset
  if village_land(village_mask,village_origin,at) or not bounds.has_point(at):continue
  var pixel=Vector2i(((outside-origin)/3.0).round())
  if not Rect2i(Vector2i.ZERO,mask.get_size()).has_point(pixel):continue
  var tile=mask.get_pixelv(pixel)
  if tile.a<.5 or tile.r>.5 or tile.g>.2 or tile.b>.5:continue
  var asset:String=row[2]
  if not plants.has(asset):plants[asset]=[]
  plants[asset].append(Transform3D(Basis(Vector3.UP,row[1]*.71).scaled(Vector3.ONE*row[3]),Vector3(at.x,terrain.height(outside.x,outside.y),at.y)))
 for asset in plants:Assets.batch(root,asset,plants[asset])
 root.set_meta("archived_detail_count",plants.values().reduce(func(total,rows):return total+rows.size(),0))
 var ridges=SurfaceTool.new()
 ridges.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in Regions.Data.RIDGES[region]:
  var at:Vector2=row[0]-offset
  if village_land(village_mask,village_origin,at) or not bounds.has_point(at):continue
  var y:float=terrain.height(row[0].x,row[0].y)
  Entrances.ridge(ridges,Vector3(at.x,y,at.y),row[2],row[3],row[1],row[4])
 ridges.generate_normals()
 var rocks=ridges.commit()
 if rocks.get_surface_count()>0:Geo.mesh(root,rocks,Vector3.ZERO,Entrances.cliff_material(false)).name="AdjoiningRidges"

static func village_land(mask:Image,origin:Vector2,at:Vector2)->bool:
 var pixel=Vector2i(((at-origin)/3.0).round())
 if not Rect2i(Vector2i.ZERO,mask.get_size()).has_point(pixel):return false
 var tile=mask.get_pixelv(pixel)
 return tile.a>.5 and tile.r<.5
