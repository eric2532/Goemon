extends RefCounted
## The archive owns the garden grid. Goemon supplies its foliage and materials.
const Data=preload("res://assets/maps/falan/city_street_data.gd")
const Streets=preload("res://scripts/forest/forest_falan_streets.gd")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Statues=preload("res://scripts/forest/forest_falan_garden_statues.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const TravelArt=preload("res://scripts/forest/forest_travel_stone_art.gd")
const DIRECTIONS=[Vector3.LEFT,Vector3.RIGHT,Vector3.BACK,Vector3.FORWARD]
const POND_WATER=[Vector2(-345,36),Vector2(-348,39),Vector2(-345,39)] # Original map 1000, ground graphic 5002.

static func is_legacy(item:Dictionary,signatures:Dictionary)->bool:
 if item.get("height",0)!=0:return false
 var cell=Vector2i(item.x,item.z)
 return signatures.get(cell)==Vector2(item.scale,item.get("rotation",0))

static func plan(model)->Dictionary:
 var tour=load("res://scripts/forest/forest_falan_tour.gd")
 var protected:Array[Vector2]=[]
 for link in tour.links(model,null):protected.append(link.at)
 for npc in tour.NPCS.AREAS.city:protected.append(npc[0])
 var result={"trees":[],"hedges":[],"rails":[],"statues":[],"ornaments":[],"obstacles":[]}
 var mansion_cell=Vector2i(8,-14)
 if model.CivicExterior.shell(mansion_cell,model.props.get(mansion_cell,{})).size()>0:
  for at:Vector2 in model.CivicExterior.Mansion.PAVILIONS:
   add_obstacle(result,Vector3(at.x,model.surface_height(at.x,at.y),at.y),Vector3(9.6,9.0,9.6),"stone")
 for row in Data.GARDEN_TREES:
  var p=Streets.ground(model,row[0])
  if not Streets.fits(model,p,.64,protected):continue
  result.trees.append([p,row[1]])
  add_obstacle(result,p,Vector3(1.08,4.8,1.08),"wood")
 for hedge in [true,false]:
  for row in (Data.GARDEN_HEDGES if hedge else Data.GARDEN_RAILS):
   var p=Streets.ground(model,row[0])
   var height=2.28 if hedge else (2.65 if row[1]>=10670 else 1.86)
   var pieces=[]
   for i in 4:
    if (int(row[2]) & (1<<i))==0:continue
    var at=p+DIRECTIONS[i]*.75
    if not Streets.fits(model,at,.80,protected):continue
    var width=1.25 if hedge else .23
    var extent=Vector3(1.52,height,width) if i<2 else Vector3(width,height,1.52)
    add_obstacle(result,at,extent,"leaves" if hedge else "metal")
    pieces.append(i)
   if not pieces.is_empty():
    result["hedges" if hedge else "rails"].append([p,height,pieces])
   elif row[2]==0 and Streets.fits(model,p,.63,protected):
    add_obstacle(result,p,Vector3(.83,height,.83) if hedge else Vector3(.27,height,.27),"leaves" if hedge else "metal")
    result["hedges" if hedge else "rails"].append([p,height,[]])
 for row in Data.GARDEN_STATUES:
  var p=Streets.ground(model,row[0])
  var rider=row[1]==10462
  if not Streets.fits(model,p,2.18 if rider else .98,protected):continue
  result.statues.append([p,row[1]])
  add_obstacle(result,p,Vector3(2.5,1.35,4.28) if rider else Vector3(1.97,1.36,1.97),"stone")
 for row in Data.GARDEN_ORNAMENTS:
  var p=Streets.ground(model,row[0])
  var large=row[1] in [10028,10035,10036]
  if Streets.fits(model,p,1.2 if large else .47,protected):result.ornaments.append([p,row[1]])
 return result

static func add_obstacle(result:Dictionary,p:Vector3,size_:Vector3,material:String):
 result.obstacles.append([AABB(p-Vector3(size_.x*.5,0,size_.z*.5),size_),material])

static func build(parent:Node3D,model):
 var root=Node3D.new()
 root.name="ArchivedFalanGardens"
 root.set_meta("garden_plan",model.falan_garden_plan)
 parent.add_child(root)
 var boxes=Boxes.new()
 var pale=Fort.material(Color("d7ccb1"),false)
 var plinth=Fort.material(Color("a4a184"))
 var iron=Geo.mat("35453f",.34)
 var caps=Geo.mat("62736b",.36)
 var dark_leaves=Fort.material(Color("405a33"),false)
 var garden:Dictionary=model.falan_garden_plan
 var shrubs={}
 for item in garden.hedges:
  var p:Vector3=item[0]
  var arms:Array=item[2]
  if arms==[0,1] or arms==[2,3]:
   hedge_segment(boxes,shrubs,p,arms[0]==2,3.01,plinth,pale,dark_leaves)
  else:
   hedge_segment(boxes,shrubs,p,false,1.30,plinth,pale,dark_leaves)
   for direction in arms:
    var at=p+DIRECTIONS[direction]*1.075
    hedge_segment(boxes,shrubs,at,direction>=2,.86,plinth,pale,dark_leaves)
 for item in garden.rails:
  var p:Vector3=item[0]
  var height:float=item[1]
  boxes.add(p+Vector3.UP*(height*.5),Vector3(.19,height,.19),iron)
  boxes.add(p+Vector3.UP*(height+.05),Vector3(.25,.20,.25),caps)
  boxes.add(p+Vector3.UP*.13,Vector3(.28,.23,.28),caps)
  for direction in item[2]:
   rail_half(boxes,p,DIRECTIONS[direction],direction>=2,height,iron,caps)
 for item in garden.statues:Statues.build(root,boxes,item[0],item[1])
 for item in garden.ornaments:ornament(root,boxes,item[0],item[1],shrubs)
 for poses in shrubs.values():Assets.batch(root,"leafy_shrub",poses)
 plant_trees(root,garden.trees)
 lily_pond(root)
 boxes.build(root)
 var collision={}
 for row in garden.obstacles:
  var box:AABB=row[0]
  var center=box.get_center()
  var key=[floori(center.x/48),floori(center.z/48),row[1]]
  if not collision.has(key):
   var body=StaticBody3D.new()
   body.collision_layer=1
   body.collision_mask=0
   body.set_meta("halo_material",row[1])
   root.add_child(body)
   collision[key]=body
  var shape=CollisionShape3D.new()
  var volume=BoxShape3D.new()
  volume.size=box.size
  shape.shape=volume
  shape.position=center
  collision[key].add_child(shape)

static func plant_trees(root:Node3D,trees:Array):
 var chunks={}
 for item in trees:
  var p:Vector3=item[0]
  var serial:int=item[1]
  var key=Vector2i(floori(p.x/72),floori(p.z/72))
  if not chunks.has(key):chunks[key]=[[],[],[]]
  var family=0 if serial<10074 else (2 if serial>=10088 else 1)
  var variation=posmod(roundi(p.x*2+p.z*3)+serial,11)*.016
  var size=Vector3(1.20,1.29,1.20) if family==0 else Vector3(1.30,1.43,1.30)
  size+=Vector3.ONE*variation
  if family==2:size*=Vector3(.93,1.01,.93)
  var angle=posmod(roundi(p.x-p.z)*13,360)
  chunks[key][family].append(Transform3D(Basis(Vector3.UP,deg_to_rad(angle)).scaled_local(size),p))
 for key in chunks:
  var groups:Array=chunks[key]
  Assets.batch(root,Assets.crossgate_tree(10058),groups[0],true)
  Assets.batch(root,Assets.crossgate_tree(10085),groups[1],true)
  Assets.batch(root,Assets.crossgate_tree(10088),groups[2],true)

static func hedge_segment(boxes,shrubs:Dictionary,p:Vector3,turned:bool,length_:float,base:Material,trim:Material,leaves:Material):
 Court.part(boxes,p,turned,Vector3(0,.14,0),Vector3(length_,.28,1.30),base)
 Court.part(boxes,p,turned,Vector3(0,.31,0),Vector3(length_,.12,1.38),trim)
 Court.part(boxes,p,turned,Vector3(0,1.10,0),Vector3(length_,1.55,.72),leaves)
 var basis=Basis(Vector3.UP,PI*.5 if turned else 0).scaled_local(Vector3(.60,1.19,.52))
 var count=2 if length_>2.0 else 1
 for i in count:
  var shift=(i-(count-1)*.5)*1.47
  shrub(shrubs,Transform3D(basis,p+Vector3.UP*.04+(Vector3.BACK if turned else Vector3.RIGHT)*shift))

static func shrub(chunks:Dictionary,pose:Transform3D):
 var p=pose.origin
 var key=Vector2i(floori(p.x/48),floori(p.z/48))
 if not chunks.has(key):chunks[key]=[]
 chunks[key].append(pose)

static func rail_half(boxes,p:Vector3,axis:Vector3,turned:bool,height:float,iron:Material,caps:Material):
 var at=p+axis*.75
 for level in [.44,height-.34]:
  Court.part(boxes,at,turned,Vector3.UP*level,Vector3(1.52,.11,.12),iron)
 for d in [.28,.73,1.19]:
  var foot=p+axis*d
  boxes.add(foot+Vector3.UP*(height*.47),Vector3(.077,height*.93,.077),iron)
  boxes.add(foot+Vector3.UP*(height*.94),Vector3(.15,.12,.15),caps)

static func ornament(root:Node3D,boxes,p:Vector3,serial:int,shrubs:Dictionary):
 var clay=Geo.mat("915139")
 if serial==10028:
  Geo.cylinder(root,p+Vector3.UP*.38,.48,.76,clay,false,.69)
  Geo.cylinder(root,p+Vector3.UP*.74,.71,.13,clay)
  shrub(shrubs,Transform3D(Basis.IDENTITY.scaled(Vector3(.42,1.06,.42)),p+Vector3.UP*.53))
 elif serial in [10035,10036]:
  var wood=Fort.material(Color("93714a"),false)
  var turned=serial==10036
  Court.part(boxes,p,turned,Vector3.UP*.91,Vector3(2.37,.14,.79),wood)
  for x in [-1.04,1.04]:
   for z in [-.29,.29]:
    Court.part(boxes,p,turned,Vector3(x,.46,z),Vector3(.12,.92,.12),wood)
  for i in range(-1,2):
   var pot=p+Vector3(0,1.18,i*.74) if turned else p+Vector3(i*.74,1.18,0)
   Geo.cylinder(root,pot,.17,.39,clay,false,.26)
   Assets.batch(root,["flowers_coral","flowers_ivory","flowers_blue"][i+1],
    [Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.63),pot+Vector3.UP*.13)])
 else:
  TravelArt.ornament(root,p,serial)

static func lily_pond(root:Node3D):
 var room=preload("res://scripts/forest/forest_falan_room_art.gd")
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for at:Vector2 in Data.LILY_TILES+POND_WATER:
  var tile=0 if at in Data.LILY_TILES else 1
  for corner:Vector2 in room.TILE_TRIANGLES:
   var p=at+(corner-Vector2.ONE*.5)*3.0
   surface.set_normal(Vector3.UP)
   surface.set_uv((Vector2(tile*36+2.5,2.5)+corner*31)/Vector2(72,36))
   surface.add_vertex(Vector3(p.x,Terrain.CITY_POND_WATER+.027,p.y))
 var material=room.painted_atlas(preload("res://assets/maps/falan/city_pond_atlas.png"))
 material.set_shader_parameter("original_palette",true)
 var pond=Geo.mesh(root,surface.commit(),Vector3.ZERO,material)
 pond.name="OriginalFalanPond"
 pond.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
