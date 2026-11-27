extends SceneTree
## Source contracts and every Cape floor; generated topology is explicitly adapted.
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const South=preload("res://scripts/forest/forest_south_kili_population.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Cape caves/"
var checks=0
var failures=0
var records=[]
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("SOKIA_CAPE_FAIL "+message)
func reached(row:Dictionary,start:Vector2i)->Dictionary:
 var queue=[start];var seen={start:true};var cursor=0
 while cursor<queue.size():
  var at:Vector2i=queue[cursor];cursor+=1
  for step in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next:Vector2i=at+step
   if not seen.has(next) and Maps.open(row.bits,row.size,next):seen[next]=true;queue.append(next)
 return seen
func run():
 var generated=Maps.generated();var seed_=41829558
 var source:Dictionary=South.cape_data()
 for key in ["cape_descent","cape_ascent"]:
  var spec:Dictionary=generated.SPECS[key]
  check(generated.count(key,seed_)==10,"Exact ten-floor count "+key)
  check(spec.box_amount==(5 if key=="cape_descent" else 6),"Original generated chest count "+key)
  check(spec.enemy_rate==[1,4],"Raw original encounter rate interval "+key)
  var widths={};var heights={}
  var branch_boxes=0
  for n in range(1,11):
   var id:int=generated.floor_id(key,n);var row:Dictionary=Maps.state(id,seed_)
   var cells:int=row.size.x*row.size.y
   check(Maps.owns(id) and South.cape(id) and generated.number(id)==n,"Existing original/native owners "+str(id))
   check(row.raw.size()==20+6*cells and row.raw.decode_u32(12)==row.size.x and row.raw.decode_u32(16)==row.size.y,"Complete native map planes "+str(id))
   check(row.size.x>=spec.size[0] and row.size.x<=spec.size[1] and row.size.y>=spec.size[2] and row.size.y<=spec.size[3],"Exact source dimension intervals "+str(id))
   check(not widths.has(row.size.x) and not heights.has(row.size.y),"Dimension bags draw without replacement "+str(id))
   widths[row.size.x]=true;heights[row.size.y]=true
   var connected=reached(row,row.doors[0])
   check(connected.has(row.doors[1]),"Both source stairs connected in adapted topology "+str(id))
   var serials:Array=generated.stair_serials(id,seed_)
   for index in 2:
    var at:Vector2i=row.doors[index]
    check(row.raw.decode_u16(20+(cells+at.y*row.size.x+at.x)*2)==serials[index],"Source stair graphic "+str(id)+" "+str(index))
   var zone:Dictionary=South.zone_at(id,row.doors[0])
   check(zone.config==spec.config and zone.groups==source.generated[key].groups,"Distinct source group pool on every floor "+str(id))
   var level=int(spec.levels[0])+n*(int(spec.levels[1])-int(spec.levels[0]))/10
   check(zone.levels==[level,level],"Qualified reference-generator floor level "+str(id))
   var links:Array=Maps.links(id,seed_)
   check(links.size()==2,"Two existing travel links, no floor shortcuts "+str(id))
   var expected_back:int=spec.entry[0] if n==1 else id-1
   var expected_ahead:int=spec.end[0] if n==10 else id+1
   check(links[0].floor==expected_back and links[1].floor==expected_ahead,"Complete original directed chain "+str(id))
   var bags={};var rng=RandomNumberGenerator.new();rng.seed=341
   for choice in zone.groups:
    var one:Dictionary=zone.duplicate(true);one.groups=[choice]
    var party:Array=South.group(one,bags,rng)
    check(not party.is_empty() and party.all(func(member):return member[1]==level),"Direct source group and level selection "+str(id)+" "+choice[0])
   var boxes:int=generated.box_count(id,seed_);branch_boxes+=boxes
   check(generated.box_count(id,seed_)==boxes,"Source branch box allocation replays without redrawing "+str(id))
   records.append({"config":spec.config,"floor":n,"runtime_id":id,"size":[row.size.x,row.size.y],"levels":zone.levels,"groups":zone.groups,"box_amount_branch_total":spec.box_amount,"box_allocation":boxes,"back":expected_back,"ahead":expected_ahead,"layout":"existing seeded room-graph adaptation; no original procedural snapshot"})
  check(branch_boxes==spec.box_amount,"Exactly five/six source boxes across all ten floors "+key)
 for id in [15525,15526,15530]:
  var row:Dictionary=Maps.state(id)
  check(Maps.owns(id) and row.raw==Maps.Art.raw_map(Maps.path_for(id)),"Fixed source planes exact "+str(id))
 var princess:Dictionary=Maps.state(15525)
 check(not reached(princess,Vector2i(16,19)).has(Vector2i(23,5)),"Native princess barrier prevents a free approach to descent")
 check(reached(princess,Vector2i(21,6)).has(Vector2i(23,5)),"Original princess script landing reaches the source descent stair")
 var corridor:Dictionary=Maps.state(15526)
 check(not reached(corridor,Vector2i(8,7)).has(Vector2i(91,7)),"Native Lorens barrier prevents a free corridor bypass")
 check(reached(corridor,Vector2i(47,7)).has(Vector2i(91,7)),"Original Lorens victory landing reaches source ascent stair")
 var back=Maps.links(15526,seed_)
 check(back.filter(func(link):return int(link.get("floor",0))==generated.floor_id("cape_descent",10)).size()==1,"Original corridor descent return port restored")
 check(back.filter(func(link):return int(link.get("floor",0))==generated.floor_id("cape_ascent",1)).size()==1,"Original corridor ascent entry port restored")
 var file=FileAccess.open(OUT+"floor-inventory.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"floors":records,"limits":source.limits,"goal_complete":false},"  "));file.close()
 print("SOKIA_CAPE_CONTRACT_RESULT checks=",checks," failures=",failures," floors=",records.size())
 quit(1 if failures else 0)
