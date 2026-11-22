extends RefCounted
## Street furniture is visual scenery. The saved city still owns its routes and doors.
const Data=preload("res://assets/maps/falan/city_street_data.gd")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Benches=preload("res://scripts/forest/forest_falan_benches.gd")
const Lamps=preload("res://scripts/forest/forest_falan_lamps.gd")
const Details=preload("res://scripts/forest/forest_falan_street_details.gd")

static func build(parent:Node3D,model,npcs:Array):
 var root=Node3D.new()
 root.name="ArchivedFalanStreets"
 parent.add_child(root)
 var stone=Fort.material(Color("b8b49c"))
 var coping=Fort.material(Color("d8caab"),false)
 var urn_stone=Fort.material(Color("a4b4a6"),false)
 var lamps={}
 var protected:Array[Vector2]=[]
 for link in model.get_meta("falan_links",[]):protected.append(link.at)
 for npc in npcs:protected.append(npc[0])
 for row in Data.LAMPS:
  var p=ground(model,row[0])
  if fits(model,p,.58,protected):
   var key=[row[1],Vector2i(floori(p.x/48),floori(p.z/48))]
   if not lamps.has(key):lamps[key]=[]
   lamps[key].append(Transform3D(Basis.IDENTITY,p))
 for key in lamps:Lamps.batch(root,key[0],lamps[key])
 var benches={}
 for row in Data.BENCHES:
  var p=ground(model,row[0])
  var short_seat=Benches.short_seat(row[1])
  if fits(model,p,.85 if short_seat else 1.47,protected):
   var key=[row[1],Vector2i(floori(p.x/48),floori(p.z/48))]
   if not benches.has(key):benches[key]=[]
   benches[key].append(Transform3D(Basis(Vector3.UP,Benches.yaw(row[1])),p))
 for key in benches:Benches.batch(root,key[0],benches[key])
 var planters={}
 for row in Data.PLANTERS:
  var p=ground(model,row[0])
  if not fits(model,p,1.25,protected):continue
  var key=[row[1],Vector2i(floori(p.x/48),floori(p.z/48))]
  if not planters.has(key):planters[key]=[]
  planters[key].append(Transform3D(Basis.IDENTITY,p))
 for key in planters:Details.batch(root,key[0],planters[key])
 var flowers={}
 for row in Data.FLOWERS:
  var p=ground(model,row[0])
  if not fits(model,p,.46,protected):continue
  var serial:int=row[1]
  var pot=serial in [10403,10404]
  if pot:
   var urn=Geo.mesh(root,Shapes.urn_mesh(),p,urn_stone)
   urn.set_meta("falan_flower_urn",serial)
   p.y+=.62
  var asset="flowers_ivory" if serial in [10404,11691,11696,11697,12169,12170,12171] else "flowers_coral"
  if serial==10040:asset="flowers_blue"
  if not flowers.has(asset):flowers[asset]=[]
  for i in (3 if pot else 2):
   var angle=i*TAU/3.0+serial
   var offset=Vector3(cos(angle),0,sin(angle))*(.25 if pot else .62)
   flowers[asset].append(Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*1.35),p+offset))
 for asset in flowers:Assets.batch(root,asset,flowers[asset])
 for at:Vector2 in Data.FOUNTAINS:
  var p=ground(model,at)
  if not fits(model,p,2.62,protected):continue
  var fountain=Node3D.new()
  fountain.name="FalanPlazaFountain_%d"%roundi(at.x)
  root.add_child(fountain)
  Court.fountain(fountain,p,stone,coping)
  if at.x>0:
   Geo.cylinder(fountain,p+Vector3.UP*1.47,.46,.59,stone,false,.26)
   Geo.sphere(fountain,p+Vector3.UP*1.94,Vector3(.59,.79,.59),coping)

static func ground(model,at:Vector2)->Vector3:
 return Vector3(at.x,model.surface_height(at.x,at.y),at.y)

static func fits(model,p:Vector3,radius:float,protected:Array[Vector2])->bool:
 if not model.terrain.disk_clear(p+Vector3.UP*.1,radius):return false
 var at=Vector2(p.x,p.z)
 for position in protected:
  if at.distance_squared_to(position)<pow(radius+1.35,2):return false
 var cell:Vector2i=model.cell_of(p)
 var bounds=AABB(p-Vector3(radius,0,radius),Vector3(radius*2,1.2,radius*2))
 for x in range(cell.x-1,cell.x+2):
  for z in range(cell.y-1,cell.y+2):
   for anchor in model.scenery_cells.get(Vector2i(x,z),[]):
    if model.scenery_obstacles[anchor].intersects(bounds):return false
 return true

