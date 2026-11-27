extends SceneTree
## Reports actual walk components and exposed links; it never treats catalog presence as completion.
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const ROOT="res://build/Other Files/Asset Toolkit/University Region/"
var components={}
var report=[]

func _initialize():run.call_deferred()

func labels(id:int)->Dictionary:
 if components.has(id):return components[id]
 var row=Original.state(id,341);var regions={};var sizes=[]
 for z in row.size.y:
  for x in row.size.x:
   var cell=Vector2i(x,z)
   if regions.has(cell) or not Original.open(row.bits,row.size,cell):continue
   var index=sizes.size();var queue=[cell];regions[cell]=index;var cursor=0
   while cursor<queue.size():
    var at:Vector2i=queue[cursor];cursor+=1
    for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
     var next=at+direction
     if not regions.has(next) and Original.open(row.bits,row.size,next):regions[next]=index;queue.append(next)
   sizes.append(queue.size())
 components[id]={"regions":regions,"sizes":sizes}
 return components[id]

func region_at(id:int,at:Vector2)->int:
 var cell=Vector2i(((at-Original.state(id,341).origin)/3).round())
 return labels(id).regions.get(cell,-1)

func run():
 var scope=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"scope.json"))
 var rows:Dictionary={};var edges={};var source_ids={}
 for entry in scope.fixed:
  rows[int(entry.runtime)]=entry;source_ids[int(entry.source)]=true
 for id in range(51201,51213):rows[id]={"source":null,"runtime":id,"title":"Bezlheim %dF"%(id-51200)}
 for branch_ in Original.generated().SPECS:
  for n in range(1,Original.generated().count(branch_,341)+1):
   var id:int=Original.generated().floor_id(branch_,n)
   rows[id]={"source":null,"runtime":id,"title":Original.title(id)}
 var missing=0;var broken=0;var dropped=[];var geometry={}
 for id:int in rows:
  var entry:Dictionary=rows[id].duplicate();entry["loaded"]=Original.owns(id);entry["links"]=[]
  if not entry.loaded:
   entry["blocker"]="No recovered runtime map; catalog/source-layout work required";missing+=1;report.append(entry);continue
  var data=labels(id);entry["walk_components"]=data.sizes
  var state=Original.state(id,341);var cells:int=state.size.x*state.size.y
  for i in cells:
   if id==59752 and not (Rect2i(94,106,13,13).has_point(Vector2i(i%state.size.x,i/state.size.x)) or Rect2i(126,138,13,13).has_point(Vector2i(i%state.size.x,i/state.size.x))):continue
   var serial:int=state.raw.decode_u16(20+(cells+i)*2)
   if serial<1000:continue
   var graphic:Dictionary=Original.Art.data().graphics[str(serial)]
   var family=Original.Forms.kind(serial,false,graphic)
   if not geometry.has(serial):geometry[serial]={"serial":serial,"family":family,"count":0,"maps":[],"source_pixels":[graphic.rect[2],graphic.rect[3]],"footprint":graphic.footprint}
   geometry[serial].count+=1
   if id not in geometry[serial].maps:geometry[serial].maps.append(id)
  for link in Original.links(id,341):
   var from=Vector2i(id,region_at(id,link.at));var target=int(link.get("floor",-1))
   var to=Vector2i(target,region_at(target,link.arrival)) if target>0 and Original.owns(target) else Vector2i(target,-1)
   if not edges.has(from):edges[from]=[]
   edges[from].append(to)
   if link.get("region_hall_variant",false):
    edges[from].append(Vector2i(32269,region_at(32269,link.arrival)))
   var row={"at":[link.at.x,link.at.y],"target":target,"kind":link.to,"component":from.y,"arrival_component":to.y,"gate":link.get("decree_needs_blade",false) or link.get("decree_guardians",false) or link.get("beast_guardian",false) or link.has("region_battle") or link.has("region_stamps") or not link.get("region_needs","").is_empty()}
   if link.has("arrival"):row["arrival"]=[link.arrival.x,link.arrival.y]
   if link.get("region_hall_variant",false):row["item_conditioned_alternate_target"]=32269
   if from.y<0 or target>0 and to.y<0:broken+=1
   entry.links.append(row)
  report.append(entry)
 # F actions are real crossings too. Keep them distinguished from exposed walk-in warps.
 var transfers={"6399":[4331,7,3],"6397":[4332,10,5],"6407":[4335,14,7],"6450":[402,53,162],"6735":[4403,31,38],"6331":[16510,25,20],"6334":[16511,26,65],"6453":[14003,9,42],"5202":[402,81,191],"5268":[15536,15,15],"5272":[15531,50,32],"5247":[15531,29,51],"5252":[15531,22,35],"5248":[400,280,364],"6470":[20508,45,47],"6458":[401,26,186],"6466":[20001,26,32],"6740":[4432,24,12],"6342":[16515,10,17],"6345":[16514,12,17],"6343":[16512,39,52]}
 for key in preload("res://assets/maps/falan/university_region/ice_events.gd").EVENTS:
  var event:Dictionary=preload("res://assets/maps/falan/university_region/ice_events.gd").EVENTS[key]
  if event.kind=="candle":transfers[key]=event.target
 transfers.merge({"6736":[4402,21,13],"6933":[5014,8,6],"6934":[24074,20,26],"6920":[402,53,162],"807220":[402,53,162],"6154":[15006,31,22],"6159":[15011,10,19],"6378":[14010,7,34],"1102658":[32183,26,33],"1102730":[4200,38,46]})
 var region=preload("res://scripts/forest/forest_university_region.gd")
 for key in region.BOSSES:
  var spec:Dictionary=region.BOSSES[key]
  if key in ["azure","sylph"] or spec.win.is_empty() or spec.actors.is_empty():continue
  transfers[spec.actors[0]]=spec.win
 var population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/university_region/population.json"))
 population.npcs.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/snow_region/population.json")).npcs)
 var events=[]
 for actor in population.npcs:
  if not transfers.has(actor.id):continue
  var id:int=actor.floor;var transfer:Array=transfers[actor.id];var target:int=Original.runtime_id(transfer[0])
  var cell=Vector2i(actor.cell[0],actor.cell[1])-Original.crop(id).position
  var approaches=[]
  # A source candle/counter can be talked to from either side of its own blocked cell.
  for step in [Vector2i.ZERO,Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT]:
   var component=region_at(id,Original.point(id,cell+step,341))
   if component>=0 and component not in approaches:approaches.append(component)
  var to=region_at(target,Original.source_point(target,Vector2i(transfer[1],transfer[2]))) if Original.owns(target) else -1
  for from:int in approaches:
   var start_=Vector2i(id,from)
   if to>=0:
    if not edges.has(start_):edges[start_]=[]
    edges[start_].append(Vector2i(target,to))
  events.append({"actor":actor.id,"action":actor.get("quest_action",""),"source":id,"approach_components":approaches,"target":target,"arrival_component":to,"conditional":true})
  if actor.id=="6159":
   var qualified=region_at(15012,Original.source_point(15012,Vector2i(10,19)))
   for from:int in approaches:
    var start_=Vector2i(id,from)
    if qualified>=0:edges.get_or_add(start_,[]).append(Vector2i(15012,qualified))
   events.append({"actor":actor.id,"action":"curse_master_entry: qualified job or recommendation","source":id,"approach_components":approaches,"target":15012,"arrival_component":qualified,"conditional":true})
 for warp in Original.Art.data().warps:
  var source=int(warp[0]);var target=int(warp[3]);var id=Original.runtime_id(source)
  if not source_ids.has(source) or not source_ids.has(target):continue
  var at=Vector2i(warp[1],warp[2]);var landing=Vector2i(warp[4],warp[5])
  if source==4100 and not Original.crop(id).has_point(at):continue # Independent town exits lie beyond the gateway boundary.
  if source==400 and target==16510:continue # Source priest6331 owns the keyed NPC transfer above.
  if source==59752 and not (Rect2i(94,106,13,13).has_point(at) or Rect2i(126,138,13,13).has_point(at)):continue # Unrelated holding-map room.
  var reason=""
  if source==400 and target==4300:reason="Superseded source-version entrance: client geography and reciprocal Abanis exits corroborate402 (182–184,161), not400 (248–250,247)"
  elif not Original.owns(id):reason="origin map absent"
  elif not Original.owns(Original.runtime_id(target)):reason="destination map absent"
  elif not Original.crop(id).has_point(at):reason="source entrance excluded by current map crop"
  elif not Original.crop(Original.runtime_id(target)).has_point(landing):reason="destination excluded by current map crop"
  else:
   var expected=Original.source_point(id,at)
   var present=Original.links(id,341).any(func(link):return link.get("floor",-1)==Original.runtime_id(target) and (link.at.distance_to(expected)<.1 or link.get("source_gate",Vector2.INF).distance_to(expected)<.1))
   if not present:reason="fixed source warp dropped by runtime link builder"
  if not reason.is_empty():dropped.append({"warp":warp,"reason":reason})
 var start=Vector2i(51004,region_at(51004,Original.source_point(51004,Vector2i(44,33))))
 var visited={start:true};var queue=[start];var cursor=0
 while cursor<queue.size():
  var at:Vector2i=queue[cursor];cursor+=1
  for next:Vector2i in edges.get(at,[]):
   if next.y<0 or visited.has(next):continue
   visited[next]=true;queue.append(next)
 var reachable=0
 for entry in report:
  var id=int(entry.runtime);var reached=[]
  for key:Vector2i in visited:
   if key.x==id:reached.append(key.y)
  entry["components_reachable_from_jenova_ignoring_quest_gates"]=reached
  if not reached.is_empty():reachable+=1
 var result={"seed":341,"maps":report,"conditional_npc_transfers":events,"missing_maps":missing,"broken_exposed_links":broken,"dropped_source_warps":dropped,"reachable_maps_ignoring_quest_gates":reachable,"limits":"Data graph only; quest prerequisites, normal movement/combat and visual quality require separate verification. Azure's withheld trigger is a missing post-fight layout blocker, not an exposed working warp."}
 var stage="baseline" if "--baseline" in OS.get_cmdline_user_args() else "current"
 var geometry_file=FileAccess.open(ROOT+"geometry-inventory.json",FileAccess.WRITE);geometry_file.store_string(JSON.stringify(geometry.values(),"  "));geometry_file.close()
 var file=FileAccess.open(ROOT+"inventory-"+stage+".json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
 print("UNIVERSITY_INVENTORY maps=",report.size()," missing=",missing," broken_exposed_links=",broken," dropped_source_warps=",dropped.size()," reachable=",reachable)
 quit(0)
