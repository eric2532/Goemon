extends RefCounted
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Layout=preload("res://scripts/forest/forest_wind_meadow_layout.gd")
static func pose(world,p:Vector2,scale_:float,angle:float=0)->Transform3D:
 return Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale_),Vector3(p.x,world.model.surface_height(p.x,p.y),p.y))
static func trees(world,parent:Node3D):
 parent.set_meta("native_terrain",true)
 var chunks={}
 for cell in world.model.trees:
  var p=Vector2(cell.x*6,cell.y*6);var scale_:float=world.model.trees[cell]*2.0
  if cell==Layout.LANDMARK:scale_*=1.5
  var key=Vector2i(floori(p.x/96),floori(p.y/96))
  if not chunks.has(key):chunks[key]=[]
  chunks[key].append(pose(world,p,scale_,cell.x*.79+cell.y*1.73))
  preload("res://scripts/forest/forest_art.gd").solid(parent,world.model.point(cell)+Vector3.UP*4,Vector3(2.5,8,2.5),1,"wood")
 # A map-wide batch draws every tree whenever any part of the forest is visible.
 for key in chunks:
  var chunk=Node3D.new();chunk.name="Trees_%d_%d"%[key.x,key.y];parent.add_child(chunk)
  Assets.batch(chunk,"broadleaf_tree",chunks[key],true)
 for material in Assets.wind_materials.values():
  if material.get_shader_parameter("canopy")==true:world.fog_materials.append(material)
static func build(world,parent:Node3D):
 var root=Node3D.new();root.name="WindMeadowValley";root.set_meta("native_terrain",true);parent.add_child(root)
 var scale_:float=world.model.terrain_scale
 var field=preload("res://scripts/forest/forest_wind_meadow_terrain.gd")
 var mesh=world.model.terrain.mesh()
 var terrain=MeshInstance3D.new();terrain.mesh=mesh;root.add_child(terrain)
 var mat=ShaderMaterial.new();mat.shader=preload("res://scripts/forest/wind_meadow_ground.gdshader");mat.set_shader_parameter("roads",load(field.asset_path("roads.png",scale_)));mat.set_shader_parameter("map_extent",240*scale_);mat.set_shader_parameter("cliff",preload("res://assets/textures/wind_meadow/cliff_paint.png"));terrain.material_override=mat;world.kai_materials.append(mat)
 if world.model.map_expansion!=1.0:
  var apron=MeshInstance3D.new();var source=load(field.asset_path("terrain.res",scale_));var edge=ArrayMesh.new()
  edge.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(1));apron.mesh=edge;apron.scale=Vector3(world.model.map_expansion,1,world.model.map_expansion);apron.material_override=mat;root.add_child(apron)
 var body=StaticBody3D.new();body.name="ValleyTerrainCollision";body.collision_layer=1;body.collision_mask=0;root.add_child(body)
 var shape=CollisionShape3D.new();shape.shape=world.model.terrain.collision();body.add_child(shape)
 load("res://scripts/halo_impact_material.gd").tag_terrain(body,world.model,mesh)
 var rng=RandomNumberGenerator.new();rng.seed=71023
 var camp_positions=[]
 for camp in world.model.portals:camp_positions.append(Vector2(camp.x*6,camp.z*6))
 var camp_clearance=70.0 if world.model.has_enemy_castles() else 14.0
 # Spatial batches let the renderer discard plants outside the camera's lawn.
 for cz in range(int(-6*scale_),int(6*scale_)):
  for cx in range(int(-6*scale_),int(6*scale_)):
   var chunk=Node3D.new();chunk.position=Vector3(cx*36,0,cz*36);root.add_child(chunk)
   var groups={"grass_short":[],"flowers_blue":[],"flowers_ivory":[],"flowers_coral":[],"leafy_shrub":[],"mossy_boulder":[]}
   var roads=foliage_roads(Vector2(cx*36,cz*36),scale_)
   var camps=[]
   for camp in camp_positions:
    if Rect2(Vector2(cx*36,cz*36),Vector2(36,36)).grow(camp_clearance).has_point(camp):camps.append(camp)
   for i in 1800:
    var p=Vector2(cx*36+rng.randf_range(0,36),cz*36+rng.randf_range(0,36));var cell:Vector2i=world.model.cell_of(Vector3(p.x,0,p.y))
    if p.length()>191*scale_ or (absf(p.x-6)<53 and absf(p.y-6)<42) or world.model.occupancy.has(cell) or near_foliage_road(p,roads):continue
    var blocked=false
    for camp in camps:
     if p.distance_to(camp)<camp_clearance:blocked=true;break
    if blocked:continue
    var h:float=world.model.surface_height(p.x,p.y)
    if absf(h-world.model.surface_height(p.x+1,p.y+1))>.4:continue
    var asset="grass_short"
    var flower=sin(p.x*.055+sin(p.y*.08))*sin(p.y*.066)
    if flower>.65 and rng.randf()<.28:asset=["flowers_blue","flowers_ivory","flowers_coral"][posmod(cx+cz,3)]
    elif i<640 and i%431==0:asset="mossy_boulder"
    elif i<640 and i%199==0:asset="leafy_shrub"
    if asset in ["mossy_boulder","leafy_shrub"] and world.model.roads.has(cell):continue
    var plant_scale=rng.randf_range(.65,1.0) if asset=="grass_short" else rng.randf_range(.75,1.15)
    var transform_=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*plant_scale),Vector3(p.x,h,p.y));transform_.origin-=chunk.position;groups[asset].append(transform_)
   for asset in groups:Assets.batch(chunk,asset,groups[asset],asset!="mossy_boulder",48 if asset=="grass_short" or asset.begins_with("flowers") else 0)
 scale_*=world.model.map_expansion
 var mountains=[]
 for i in 28:
  var angle=i*TAU/28;var radius=rng.randf_range(310,344)*scale_
  mountains.append(Transform3D(Basis(Vector3.UP,angle+rng.randf()).scaled(Vector3.ONE*rng.randf_range(1.6,2.5)),Vector3(cos(angle)*radius,20,sin(angle)*radius)))
 for i in 20:
  var angle=i*TAU/20;var radius=rng.randf_range(340,460)*scale_
  mountains.append(Transform3D(Basis(Vector3.UP,angle+rng.randf()).scaled(Vector3.ONE*rng.randf_range(1.7,3.3)),Vector3(cos(angle)*radius,-15,sin(angle)*radius)))
 Assets.batch(root,"terraced_mountain",mountains)
 var horizon=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2.ONE*maxf(2400,1200*scale_);horizon.mesh=plane;horizon.position.y=-22;horizon.material_override=mat;root.add_child(horizon)

static func foliage_roads(origin:Vector2,scale_:float)->Array:
 var result=[];var bounds=Rect2(origin,Vector2(36,36))
 for route in Layout.routes(scale_):
  for i in range(1,route.size()):
   var a:Vector2=route[i-1];var delta:Vector2=route[i]-a
   # A segment outside the expanded chunk cannot exclude any of its plants.
   if bounds.intersects(Rect2(a,Vector2.ZERO).expand(route[i]).grow(9)):
    result.append([a,delta,delta.length_squared()])
 return result
static func near_foliage_road(p:Vector2,roads:Array)->bool:
 for road in roads:
  var a:Vector2=road[0];var delta:Vector2=road[1]
  if p.distance_to(a+delta*clampf((p-a).dot(delta)/road[2],0,1))<9:return true
 return false
