extends RefCounted
## Original ship/port endpoints, using the existing Explore NPC and travel owners.
const VOYAGE="east_ship_voyage"
static var catalog:Dictionary={}

static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/east_region/harbor.json"))
 return catalog

static func point(game,floor_:int,cell:Vector2i)->Vector2:
 if floor_==2000 and game.FalanTour.Regions.private_source_context!=null:return game.FalanTour.Regions.private_source_context.source_point(2000,cell)
 if floor_==2000:
  var regions=game.FalanTour.Regions
  return regions.village_transform("il_village")*(regions.Sites.VILLAGES.il_village[2]+Vector2(cell)*3.)
 return game.FalanTour.Winter.Recovered.source_point(game.FalanTour.Winter.Recovered.runtime_id(floor_),cell)

static func travel(game,floor_:int,cell:Vector2i):
 var tour=game.FalanTour
 var layout:Dictionary=tour.Regions.layout("east_gate") if floor_==2000 else tour.Indoor.layout(tour.Winter.Recovered.runtime_id(floor_))
 if floor_==2000 and tour.Regions.private_source_context!=null:layout=tour.Regions.private_source_context.layout(2000,cell)
 var at=point(game,floor_,cell)
 game.transitioning=true
 tour.travel.call_deferred(game,layout,{"arrival":at,"yaw":game.camera_rig.yaw,"velocity":Vector3.ZERO})

static func action(game,key:String)->bool:
 if not key.begins_with("east_harbor:"):return false
 var record:Dictionary=data().actions.get(key.trim_prefix("east_harbor:"),{})
 if record.is_empty():return true
 var tree:SceneTree=game.get_tree()
 if record.kind=="status":
  var voyage:Dictionary=tree.get_meta(VOYAGE,{})
  game.toast("航行中 · %d 秒後抵達"%int(ceil(float(voyage.left))) if not voyage.is_empty() and int(voyage.ship)==int(record.ship) else "目前沒有進行中的航程")
  return true
 if tree.has_meta(VOYAGE):game.toast("航行中");return true
 if record.kind=="transfer":
  var target:Array=record.target
  if target[0]!=2000 and not game.FalanTour.Winter.Recovered.owns(int(target[0])):game.toast("目的地的原始地圖尚待恢復");return true
  if game.model.gold<int(record.fare):game.toast("船票需要 500G");return true
  game.model.gold-=int(record.fare)
  travel(game,int(target[0]),Vector2i(target[1],target[2]))
 else:
  var ship:Dictionary=data().ships[str(int(record.ship))]
  var destination:Dictionary=data().ports[str(int(record.arrival))]
  if not game.FalanTour.Winter.Recovered.owns(int(destination.floor)):
   var blockers:Dictionary=tree.get_meta("east_harbor_blockers",{})
   blockers[key]={"ship":int(record.ship),"source":int(destination.floor),"cell":destination.cell,"reason":"The separately owned regional arrival has no current map owner; preserve the connection without rebuilding its region."}
   tree.set_meta("east_harbor_blockers",blockers);game.toast("目的地港口尚未開放");return true
  tree.set_meta(VOYAGE,{"ship":int(record.ship),"departure":int(record.departure),"arrival":int(record.arrival),"left":float(data().voyage_seconds),"started":false,"display":-1})
  travel(game,int(ship.floor),Vector2i(ship.cell[0],ship.cell[1]))
 return true

static func tick(game,delta:float):
 var tree:SceneTree=game.get_tree()
 if not tree.has_meta(VOYAGE):return
 if not game.playing or game.player.hp<=0:tree.remove_meta(VOYAGE);return
 if game.transitioning or game.paused or game.ordinary_pause or is_instance_valid(game.dialogue):return
 var voyage:Dictionary=tree.get_meta(VOYAGE)
 var ship:Dictionary=data().ships[str(int(voyage.ship))]
 var current_source:int=game.FalanTour.Winter.Recovered.source_id(game.model.falan_floor)
 if game.model.falan_area!="interior" or not ship.maps.any(func(floor_):return int(floor_)==current_source):
  tree.remove_meta(VOYAGE);return
 voyage.started=true;voyage.left=maxf(0.,float(voyage.left)-maxf(0.,delta))
 var seconds=int(ceil(voyage.left))
 if seconds!=int(voyage.display) and (seconds==20 or seconds<=5):
  voyage.display=seconds
  if seconds>0:game.toast("航行中 · %d 秒後抵達"%seconds)
 if voyage.left>0:return
 var port:Dictionary=data().ports[str(int(voyage.arrival))]
 tree.remove_meta(VOYAGE)
 game.toast("抵達 "+str(port.name))
 travel(game,int(port.floor),Vector2i(port.cell[0],port.cell[1]))

static func build(root:Node3D,model):
 var tour=load("res://scripts/forest/forest_falan_tour.gd")
 var source:int=tour.Winter.Recovered.source_id(model.falan_floor) if model.falan_area=="interior" else 2000 if model.falan_area=="east_gate" else -1
 if tour.Regions.private_source_context!=null:source=tour.Regions.private_source_context.source_id(model) if model.falan_area!="interior" else source
 var rows=[]
 for original in data().npcs:
  if int(original.floor)!=source:continue
  var record:Dictionary=original.duplicate(true)
  var at=Vector2(record.cell[0],record.cell[1])*3.
  if source==2000:at=tour.Regions.private_source_context.source_point(2000,Vector2i(record.cell[0],record.cell[1])) if tour.Regions.private_source_context!=null else tour.Regions.village_transform("il_village")*(tour.Regions.Sites.VILLAGES.il_village[2]+at)
  else:at+=tour.Indoor.floor_info(model.falan_floor)[1]
  var found=false
  for sprite in root.find_children("*","Sprite3D",true,false):
   var local:Vector3=root.global_transform.affine_inverse()*sprite.global_position
   if Vector2(local.x,local.z).distance_squared_to(at)>.04:continue
   sprite.set_meta("npc_record",record);found=true;break
  if found:continue
  var art:Dictionary=data().art[record.token];var r:Array=art.rect;var o:Array=art.origin
  rows.append([at,Rect2(r[0],r[1],r[2],r[3]),record.name,Vector2(float(o[0])+r[2]*.5,-float(o[1])-r[3]*.5),record])
 if not rows.is_empty():tour.build_npcs(root,model,rows,load("res://assets/maps/falan/east_region/harbor-npcs.png"))
