extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Document=preload("res://scripts/forest/forest_map_document.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func flat()->Dictionary:
 return {"format":"forest_shrine_map","schema":1,"title":"Flow fixture","buildings":[],"trees":[],"deposits":[],"roads":[],"portals":[]}
func marching_model(data:Dictionary):
 var model=Model.new();model.reset(42,{"bosses_per_portal":0},data);model.phase="wave";model.waves.pending=0;model.hero_targetable=false
 return model
func road(data:Dictionary,width:int):
 for z in range(9,31):
  for x in range(-width,width+1):data.roads.append({"x":x,"z":z})
func runners(model,count:int,start:Vector3)->Array:
 var result=[]
 for index in count:
  var e=model.waves.spawn_enemy(0,start+Vector3(0,0,index*.04));e.road_path=[]
  for z in range(29,8,-1):e.road_path.append(Vector2i(0,z))
  result.append(e)
 return result
func run():
 # Removing lateral route following must collapse this formation back onto x=0.
 var data=flat();road(data,2);var model=marching_model(data);var group=runners(model,7,Vector3(0,0,180))
 for frame in 180:model.waves.tick(1.0/30,Vector3.ZERO)
 var low=INF;var high=-INF;var min_progress=INF
 for e in group:low=minf(low,e.pos.x);high=maxf(high,e.pos.x);min_progress=minf(min_progress,180-e.pos.z)
 check(high-low>9,"Real ordinary enemies retain a broad approach on a five-tile road (%s..%s)"%[low,high])
 var nearest_pair=INF
 for a in range(group.size()):
  for b in range(a+1,group.size()):nearest_pair=minf(nearest_pair,group[a].pos.distance_to(group[b].pos))
 check(nearest_pair>1.5,"Ordinary enemies fan apart instead of retaining coincident route positions (%s)"%nearest_pair)
 check(min_progress>12,"All lanes advance at normal walking speed instead of orbiting shared cell centers")
 check(group.all(func(e):return e.velocity.length()<=float(model.waves.role_stats(0).speed)+.05 and e.velocity.length()>=float(model.waves.role_stats(0).speed)*.95),"Distributed marching retains its movement budget while rounding route corners")
 check(model.enemies.size()==7 and model.waves.pending==0,"Flow creates no additional gameplay enemies")
 # Actors sharing a lane still need local separation; lanes alone cannot pass this.
 model=marching_model(data);group=[]
 for index in 2:
  var e=model.waves.spawn_enemy(0,Vector3(0,0,180));model.next_id+=6;e.road_path=[]
  for z in range(29,8,-1):e.road_path.append(Vector2i(0,z))
  group.append(e)
 for frame in 90:model.waves.tick(1.0/30,Vector3.ZERO)
 check(group[0].pos.distance_to(group[1].pos)>.7,"Local flow separates ordinary actors assigned the same lane")
 # A painted road on open ground must not force the formation into its width.
 data=flat();road(data,0);model=marching_model(data);group=runners(model,7,Vector3(0,0,180))
 for frame in 150:model.waves.tick(1.0/30,Vector3.ZERO)
 check(group.all(func(e):return e.pos.z<180-float(model.waves.role_stats(0).speed)*2.5 and model.waves.navigation.move_clear(e.pos,Roles.footprint_radius(e.variant))) and group.any(func(e):return absf(e.pos.x)>3),"A narrow painted road permits a safe broad formation on open ground")
 # Continuous edge/step checks matter on all four rotated rampart approaches.
 var doc=Document.new();doc.read_file("res://assets/maps/forest_four_gates.json")
 for portal_index in [0,2,4,6]:
  model=marching_model(doc.data);var portal=model.portals[portal_index];var origin=model.waves.routes.exit_point(portal,0);origin.y=model.surface_height(origin.x,origin.z);group=[]
  for index in 7:
   var e=model.waves.spawn_enemy(0,origin);e.road_path=model.waves.routes.guidance(origin,0);group.append(e)
  var safe=true;var advanced=false
  for frame in 900:
   var previous=[]
   for e in group:previous.append(e.pos)
   model.waves.tick(.1,Vector3.ZERO)
   for index in group.size():
    var e=group[index];safe=safe and absf(e.pos.y-model.surface_height(e.pos.x,e.pos.z))<.001 and model.terrain.step_clear(previous[index],e.pos) and model.waves.navigation.move_clear(e.pos,Roles.footprint_radius(e.variant))
   if group.all(func(e):return maxf(absf(e.pos.x),absf(e.pos.z))<68):advanced=true;break
  check(safe and advanced,"Spread formation stays supported and descends rampart portal %d (%s, safe=%s)"%[portal_index,str(group[0].pos),safe])
 # Existing oversized fitted movement must remain exact and independent of flow.
 model=marching_model(flat())
 for variant in [2,4]:
  var e=model.waves.spawn_enemy(variant,Vector3(0,0,120));e.road_path=[Vector2i(0,19),Vector2i(0,18)]
  for frame in 30:model.waves.tick_enemy(e,1.0/30,Vector3.ZERO)
  check(absf(e.pos.x)<.001 and e.pos.z<120,"Oversized role %d retains its existing center route and fitted movement"%variant)
 print("ENEMY_FLOW_SPREAD_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
