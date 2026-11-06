extends RefCounted
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Scenery=preload("res://scripts/forest/forest_scenery.gd")
const Layout=preload("res://scripts/forest/forest_wind_meadow_layout.gd")
static func pose(world,p:Vector2,scale_:float,angle:float=0)->Transform3D:
 return Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale_),Vector3(p.x,world.model.surface_height(p.x,p.y),p.y))
static func trees(world,parent:Node3D):
 parent.set_meta("native_terrain",true)
 var groups={}
 var sources={"tree":world.model.trees,"rock":world.model.rocks,"props":world.model.props}
 for group in sources:
  for cell in sources[group]:
   var kind:String=world.model.props[cell].kind if group=="props" else group
   var p=Vector2(cell.x*6,cell.y*6);var key=Vector2i(floori(p.x/96),floori(p.y/96))
   if not groups.has(key):groups[key]={}
   if not groups[key].has(kind):groups[key][kind]=[]
   var scale_:float=(world.model.trees[cell] if group=="tree" else sources[group][cell].scale)*Scenery.visual_scale(kind)
   if kind=="tree" and is_same(cell,Layout.LANDMARK):scale_*=1.5
   var angle:float=(deg_to_rad(world.model.tree_rotations[cell]) if world.model.tree_rotations.has(cell) else cell.x*.79+cell.y*1.73) if group=="tree" else deg_to_rad(sources[group][cell].rotation)
   groups[key][kind].append([cell,scale_,angle,world.model.scenery_obstacles[cell]])
 # Rebuild only changed 96-metre scenery chunks; terrain and other trees stay put.
 for key in world.scenery_chunks.keys():
  if not groups.has(key):
   var old:Node3D=world.scenery_chunks[key];parent.remove_child(old);old.queue_free();world.scenery_chunks.erase(key)
 for key in groups:
  if world.scenery_chunks.has(key):
   var old:Node3D=world.scenery_chunks[key]
   if old.get_meta("scenery_signature")==groups[key]:continue
   parent.remove_child(old);old.queue_free()
  var chunk=Node3D.new();chunk.name="Scenery_%d_%d"%[key.x,key.y];chunk.set_meta("scenery_signature",groups[key]);parent.add_child(chunk);world.scenery_chunks[key]=chunk
  for kind in groups[key]:
   var poses=[]
   for item in groups[key][kind]:
    var cell=item[0];var transform_=pose(world,Vector2(cell.x*6,cell.y*6),item[1],item[2]);transform_.origin.y+=world.model.scenery_heights.get(cell,0);poses.append(transform_)
    var box:AABB=item[3]
    preload("res://scripts/forest/forest_art.gd").solid(chunk,box.get_center(),box.size,1,Scenery.material(kind)).set_meta("map_scenery_cell",cell)
   Assets.batch(chunk,Scenery.asset(kind),poses,Scenery.wind(kind))
 for material in Assets.wind_materials.values():
  if material.get_shader_parameter("canopy")==true and material not in world.fog_materials:world.fog_materials.append(material)
static func build(world,parent:Node3D):
 var root=Node3D.new();root.name="WindMeadowValley";root.set_meta("native_terrain",true);parent.add_child(root)
 var scale_:float=world.model.terrain_scale
 var field=preload("res://scripts/forest/forest_wind_meadow_terrain.gd")
 var mesh=world.model.terrain.mesh()
 var terrain=MeshInstance3D.new();terrain.mesh=mesh;root.add_child(terrain)
 var mat=ShaderMaterial.new();mat.shader=preload("res://scripts/forest/wind_meadow_ground.gdshader");mat.set_shader_parameter("roads",load(field.asset_path("roads.png",scale_)));mat.set_shader_parameter("map_extent",240*scale_);mat.set_shader_parameter("cliff",preload("res://assets/textures/wind_meadow/cliff_paint.png"));terrain.material_override=mat;world.kai_materials.append(mat);world.attack_materials.append(mat)
 mat.set_shader_parameter("castle_stone_texture",preload("res://assets/models/environments/wind_meadow/buildings/wall_section_architecture_paint.png"));mat.set_shader_parameter("castle_half_size",Layout.CASTLE_HALF_SIZE if world.model.raised_castle else 0.0)
 mat.set_shader_parameter("castle_stairs",Vector2(Layout.STAIR_HALF_WIDTH+absf(Layout.CASTLE_GATES[0].x)+3.0,Layout.STAIR_BOTTOM+3.0))
 if world.model.map_expansion!=1.0:
  var apron=MeshInstance3D.new();var source=load(field.asset_path("terrain.res",scale_));var edge=ArrayMesh.new()
  edge.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(1));apron.mesh=edge;apron.scale=Vector3(world.model.map_expansion,1,world.model.map_expansion);apron.material_override=mat;root.add_child(apron)
 var body=StaticBody3D.new();body.name="ValleyTerrainCollision";body.collision_layer=1;body.collision_mask=0;root.add_child(body)
 var shape=CollisionShape3D.new();shape.shape=world.model.terrain.collision();body.add_child(shape)
 load("res://scripts/halo_impact_material.gd").tag_terrain(body,world.model,mesh)
 if world.model.raised_castle:stairs(root,world)
 var rng=RandomNumberGenerator.new();rng.seed=71023
 var camp_positions=[]
 for camp in world.model.portals:camp_positions.append(Vector2(camp.x*6,camp.z*6))
 var camp_clearance=70.0 if world.model.has_enemy_castles() else 14.0
 # Spatial batches let the renderer discard plants outside the camera's lawn.
 for cz in range(int(-6*scale_),int(6*scale_)):
  for cx in range(int(-6*scale_),int(6*scale_)):
   foliage_chunk(world,root,cx,cz,rng,camp_positions,camp_clearance)
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

static func refresh_foliage(world,previous:Dictionary,regions:Array=[]):
 var root=world.map_features.get_node_or_null("WindMeadowValley")
 if root==null:return
 var changed=previous.duplicate();changed.merge(world.model.occupancy)
 var chunks={}
 for bounds:Rect2 in regions:
  var area=bounds.grow(2)
  for x in range(floori(area.position.x/36),floori(area.end.x/36)+1):
   for z in range(floori(area.position.y/36),floori(area.end.y/36)+1):chunks[Vector2i(x,z)]=true
 for cell in changed:
  if previous.has(cell)==world.model.occupancy.has(cell):continue
  for x in range(floori((cell.x*6-3)/36.0),floori((cell.x*6+3)/36.0)+1):
   for z in range(floori((cell.y*6-3)/36.0),floori((cell.y*6+3)/36.0)+1):chunks[Vector2i(x,z)]=true
 var camps=[]
 for camp in world.model.portals:camps.append(Vector2(camp.x*6,camp.z*6))
 for key in chunks:
  var chunk=root.get_node_or_null("Foliage_%d_%d"%[key.x,key.y])
  if chunk==null:continue
  var rng=RandomNumberGenerator.new();rng.seed=71023;rng.state=chunk.get_meta("rng_state")
  root.remove_child(chunk);chunk.queue_free()
  foliage_chunk(world,root,key.x,key.y,rng,camps,70.0 if world.model.has_enemy_castles() else 14.0)
static func foliage_chunk(world,root:Node3D,cx:int,cz:int,rng:RandomNumberGenerator,camp_positions:Array,camp_clearance:float):
 var chunk=Node3D.new();chunk.name="Foliage_%d_%d"%[cx,cz];chunk.position=Vector3(cx*36,0,cz*36);root.add_child(chunk)
 chunk.set_meta("rng_state",rng.state)
 var groups={"grass_short":[],"flowers_blue":[],"flowers_ivory":[],"flowers_coral":[],"leafy_shrub":[],"mossy_boulder":[]}
 var roads=foliage_roads(Vector2(cx*36,cz*36),world.model.terrain_scale)
 var camps=[]
 for camp in camp_positions:
  if Rect2(Vector2(cx*36,cz*36),Vector2(36,36)).grow(camp_clearance).has_point(camp):camps.append(camp)
 for i in 1800:
  var p=Vector2(cx*36+rng.randf_range(0,36),cz*36+rng.randf_range(0,36));var cell:Vector2i=world.model.cell_of(Vector3(p.x,0,p.y))
  if p.length()>191*world.model.terrain_scale or (absf(p.x-6)<53 and absf(p.y-6)<42) or world.model.occupancy.has(cell) or near_foliage_road(p,roads):continue
  if world.model.raised_castle and Layout.castle_height(p)>0:continue
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

static func stairs(parent:Node3D,world:Node3D):
 var root=Node3D.new();root.name="CastleSideStairs";root.set_meta("native_terrain",true);parent.add_child(root)
 var boxes=preload("res://scripts/forest/forest_static_boxes.gd").new()
 var stone=preload("res://scripts/forest/forest_stone_fort.gd").material(Color("92998c"),false).duplicate()
 stone.set_shader_parameter("use_castle_stone",true);stone.set_shader_parameter("castle_stone_texture",preload("res://assets/models/environments/wind_meadow/buildings/wall_section_architecture_paint.png"))
 world.attack_materials.append(stone)
 var run=.75*Layout.CASTLE_SCALE;var count=roundi((Layout.STAIR_BOTTOM-Layout.STAIR_TOP)/run)
 for i in 4:
  var normal:Vector2=Layout.CASTLE_DIRECTIONS[i];var gate:Vector2=Layout.CASTLE_GATES[i]
  for step in range(-1,count):
   var distance=(Layout.STAIR_INNER+Layout.STAIR_TOP)*.5 if step<0 else Layout.STAIR_TOP+(step+.5)*run
   var p=gate+normal*(distance-Layout.CASTLE_HALF_SIZE)
   var height_=Layout.castle_height(p-normal*run*.5) if step>=0 else Layout.castle_height(p)
   var depth=Layout.STAIR_TOP-Layout.STAIR_INNER if step<0 else run
   var size_=Vector3(Layout.STAIR_HALF_WIDTH*2,height_,depth) if normal.y!=0 else Vector3(depth,height_,Layout.STAIR_HALF_WIDTH*2)
   # Fine treads sit on the shared smooth stair collision, avoiding per-step bumps.
   boxes.add(Vector3(p.x,height_*.5+.025,p.y),size_,stone)
 boxes.build(root)

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
