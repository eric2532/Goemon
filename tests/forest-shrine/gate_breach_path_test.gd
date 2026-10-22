extends SceneTree
## Exercises real broad soldiers, retained masonry and the ordinary simulation slice.
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func fixture():
 var data={"buildings":[{"kind":"gate","x":0,"z":7,"rotation":0},{"kind":"gate","x":7,"z":0,"rotation":1},{"kind":"gate","x":0,"z":-7,"rotation":2},{"kind":"gate","x":-7,"z":0,"rotation":3}],"trees":[],"deposits":[]}
 for z in [-7,7]:
  data.buildings.append({"kind":"wall","x":-7,"z":z,"rotation":0,"span":7})
  data.buildings.append({"kind":"wall","x":2,"z":z,"rotation":0,"span":6})
 for x in [-7,7]:
  data.buildings.append({"kind":"wall","x":x,"z":-6,"rotation":1,"span":6})
  data.buildings.append({"kind":"wall","x":x,"z":2,"rotation":1,"span":5})
 var model=Model.new();model.reset(42,{},data,false);model.workers.clear();model.defenders.clear();model.hero_targetable=false;model.phase="wave"
 return model
func run():
 # A whole-footprint breach collider or ordinary grid centers cannot admit
 # a radius-3.9 soldier through this centered 9.6m opening.
 for rotation in 4:
  for variant in [0,1,3]:
   var m=fixture();var nav=m.waves.navigation;var door={}
   for b in m.buildings.values():
    if b.kind=="gate" and b.rotation==rotation:door=b
   var normal:Vector3=nav.gate_outward(door);var side=Vector3(-normal.z,0,normal.x);var center:Vector3=m.center(door)
   var actor=m.waves.spawn_enemy(variant,center+normal*24+side*3)
   check(m.waves.routes.gate_target(actor)==door.id,"Role %d selects gate %d before breach"%[variant,rotation])
   m.damage_building(door.id,100000)
   door.hp=door.max_hp*.25
   check(not m.waves.valid_target("building",door.id,Vector3.ZERO),"A partially repaired open gate %d never becomes a masonry attack target"%rotation)
   check(nav.blocker(center,3.9)<0,"Breach %d admits an ordinary body at center"%rotation)
   check(nav.blocker(center+side*5.4,.2)==door.id,"Breach %d retains the stone pillar"%rotation)
   check(nav.line_clear(center+normal*8+Vector3.UP*2,center-normal*8+Vector3.UP*2),"Breach %d exposes sight through the opening"%rotation)
   check(not nav.line_clear(center+normal*8+side*5.4+Vector3.UP*2,center-normal*8+side*5.4+Vector3.UP*2),"Breach %d still occludes sight through masonry"%rotation)
   var safe=true;var retargeted=false;var entered=false;var interrupted=false
   for frame in 1200:
    if rotation==0 and variant==0 and actor.get("crossing_aligned",false) and normal.dot(actor.pos-center)<4 and not interrupted:
     m.defenders[90001]={"id":90001,"pos":center+normal*20+side*20,"hp":1e9,"targetable":true,"taunting":true};interrupted=true
    m.waves.flow.begin_tick();m.waves.tick_enemy(actor,.05,Vector3.ZERO)
    safe=safe and nav.fitted_blocker(actor,actor.pos)<0
    if actor.target_kind=="building" and actor.target_id!=door.id and m.buildings.get(actor.target_id,{}).get("kind","")=="gate":retargeted=true
    if normal.dot(actor.pos-center)<-5.9:entered=true;break
   check(entered and safe and not retargeted,"Role %d crosses gate %d centered, without pillar overlap or another gate (%s)"%[variant,rotation,str(actor.pos)])
   if interrupted:
    m.waves.tick_enemy(actor,.05,Vector3.ZERO)
    check(entered and actor.target_kind=="defender","A crossing soldier clears masonry before resuming a newly taunting defender")
   # Both collision and line-of-sight caches must observe a repaired leaf.
   door.hp=door.max_hp;door.breached=false;m.rebuild_navigation()
   check(nav.blocker(center,3.9)==door.id and not nav.line_clear(center+normal*8+Vector3.UP*2,center-normal*8+Vector3.UP*2),"Gate %d restoration closes collision and sight"%rotation)
 taunted_entry()
 outward_pursuit()
 actual_castle()
 native_corridors()
 var m=fixture();var wall=m._make_building("wall",Vector2i(-1,12),0,4);m.rebuild_navigation()
 var actor=m.waves.spawn_enemy(0,Vector3(0,0,90));var attacked_wall=false
 for frame in 600:
  m.waves.flow.begin_tick();m.waves.tick_enemy(actor,.05,Vector3.ZERO)
  if actor.strike_kind=="building" and actor.strike_id==wall.id:attacked_wall=true
 check(not attacked_wall and actor.pos.z<70,"An indestructible wall causes a detour toward the door, without attacks (%s)"%str(actor.pos))
 print("GATE_BREACH_PATH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func actual_castle():
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_blood_gulch.json"))
 for rotation in 4:
  for variant in [0,1,3]:
   var m=Model.new();m.reset(42,{},data,false);m.workers.clear();m.defenders.clear();m.hero_targetable=false;m.phase="wave"
   var door={};var nav=m.waves.navigation
   for b in m.buildings.values():
    if b.kind=="gate" and b.rotation==rotation:door=b
   var normal:Vector3=nav.gate_outward(door);var center:Vector3=m.center(door);var side=Vector3(-normal.z,0,normal.x)
   var point=center+normal*24+side*3;point.y=m.surface_height(point.x,point.z)
   var actor=m.waves.spawn_enemy(variant,point);m.damage_building(door.id,100000);var safe=true;var entered=false
   for frame in 1200:
    var previous:Vector3=actor.pos;m.waves.flow.begin_tick();m.waves.tick_enemy(actor,.05,Vector3.ZERO)
    safe=safe and nav.fitted_blocker(actor,actor.pos)<0 and m.terrain.step_clear(previous,actor.pos)
    if normal.dot(actor.pos-center)<-5.9:entered=true;break
   check(entered and safe,"Blood Gulch role %d crosses its breached gate %d on supported terrain (%s)"%[variant,rotation,str(actor.pos)])
func native_corridors():
 var m=fixture();var terrain=preload("res://scripts/forest/forest_kai_terrain.gd").new()
 terrain.width=161;terrain.spacing=3;terrain.heights.resize(25921);terrain.heights.fill(0);terrain.covered.resize(25921);terrain.covered.fill(1)
 m.terrain=terrain;m.rebuild_navigation()
 var door={}
 for b in m.buildings.values():
  if b.kind=="gate" and b.rotation==0:door=b
 var nav=m.waves.navigation;var center:Vector3=m.center(door)
 var samples=PackedVector3Array([center+Vector3(0,0,8),center,center-Vector3(0,0,8)])
 check(not nav.corridor_walls_clear(samples,3.9),"Native corridor cache initially blocks a closed gate")
 check(nav.terrain_corridors.native_sampler!=null,"The corridor fixture exercises the native obstacle cache")
 m.damage_building(door.id,100000)
 check(nav.corridor_walls_clear(samples,3.9),"Native corridor cache admits the breach after its navigation revision")
 var pillar_samples=PackedVector3Array([center+Vector3(5.4,0,0)])
 check(not nav.corridor_walls_clear(pillar_samples,.2),"Native corridor cache retains permanent pillars")
 door.hp=door.max_hp;door.breached=false;m.rebuild_navigation()
 check(not nav.corridor_walls_clear(samples,3.9),"Native corridor cache blocks the repaired leaf after its navigation revision")
func taunted_entry():
 var m=fixture();var door={}
 for b in m.buildings.values():
  if b.kind=="gate" and b.rotation==0:door=b
 var center:Vector3=m.center(door)
 m.damage_building(door.id,100000)
 m.defenders[90001]={"id":90001,"pos":Vector3(0,0,18),"hp":1e9,"targetable":true,"taunting":true}
 var actor=m.waves.spawn_enemy(0,center+Vector3(3,0,24));var entered=false;var safe=true
 for frame in 1200:
  m.waves.flow.begin_tick();m.waves.tick_enemy(actor,.05,Vector3.ZERO)
  safe=safe and m.waves.navigation.fitted_blocker(actor,actor.pos)<0
  if actor.pos.z<center.z-5.9:entered=true;break
 check(entered and safe,"An existing interior taunt routes through the centered breach without attacking permanent pillars (%s)"%str(actor.pos))
func outward_pursuit():
 for rotation in 4:
  for variant in [0,1,3]:
   var m=fixture();var door={}
   for b in m.buildings.values():
    if b.kind=="gate" and b.rotation==rotation:door=b
   var nav=m.waves.navigation;var center:Vector3=m.center(door);var normal:Vector3=nav.gate_outward(door);var side=Vector3(-normal.z,0,normal.x)
   m.damage_building(door.id,100000)
   var hero=center+normal*24
   if variant==0:m.hero_targetable=true
   else:m.defenders[90001]={"id":90001,"pos":hero,"hp":1e9,"targetable":true,"taunting":true}
   # The player now draws pursuit by attacking, within retaliation range.
   if variant==0:hero=center+normal*12
   var actor=m.waves.spawn_enemy(variant,center-normal*(12 if variant==0 else 24)+side*3);var exited=false;var safe=true
   if variant==0:actor.retaliation=1000.0
   for frame in 1200:
    m.waves.flow.begin_tick();m.waves.tick_enemy(actor,.05,hero)
    safe=safe and nav.fitted_blocker(actor,actor.pos)<0
    if normal.dot(actor.pos-center)>5.9:exited=true;break
   check(exited and safe,"Role %d pursues combat outside through breached gate %d without clipping pillars (%s)"%[variant,rotation,str(actor.pos)])
