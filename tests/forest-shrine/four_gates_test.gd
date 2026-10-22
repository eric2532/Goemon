extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Document=preload("res://scripts/forest/forest_map_document.gd")
const PRESET="res://assets/maps/forest_four_gates.json"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func rotated(cell:Vector2i)->Vector2i:return Vector2i(-cell.y,cell.x)
func run():
 var doc=Document.new();var error=doc.read_file(PRESET)
 check(error.is_empty(),"Four Gates preset loads: "+error)
 if not error.is_empty():finish();return
 check(doc.play_error().is_empty(),"Every portal has giant clearance and an approach to the base")
 var data=doc.data
 var m=Model.new();m.reset(42,{},data)
 check(m.portals.size()==8 and m.ramparts.size()==20,"Two matching portals and five wall segments per side")
 var gates=m.buildings.values().filter(func(b):return b.kind=="gate")
 var towers=m.buildings.values().filter(func(b):return b.kind=="tower")
 check(gates.size()==4 and towers.size()==8,"One gate and two defending towers per side")
 if gates.size()!=4:finish();return
 for rotation in range(4):
  check(gates.filter(func(b):return b.rotation==rotation).size()==1,"Exactly one gate on side %d"%rotation)
 for gate in gates:
  var outward=[Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT][gate.rotation]
  check(not m.route(m.shrine_entry(),gate.cell).is_empty() and not m.route(gate.cell,gate.cell+outward).is_empty(),"Gate %d connects the courtyard to the outside"%gate.id)
 var fort={}
 for b in m.buildings.values():
  if b.kind not in ["wall","gate","tower"]:continue
  for cell in m.footprint(b.kind,b.cell,b.rotation,b.get("span",0)):fort[cell]=b.kind
 check(fort.keys().all(func(c):return fort.get(rotated(c),"")==fort[c]),"Fort footprints match after a quarter turn")
 check(m.roads.keys().all(func(c):return m.roads.has(rotated(c))),"Roads are identical on all four sides")
 check(m.portals.all(func(p):return m.portals.any(func(q):return q.x==-p.z and q.z==p.x and q.rotation==(p.rotation+1)%4)),"Portal positions and inward exit orientations rotate together")
 for portal_index in 8:
  for variant in 4:
   m=Model.new();m.reset(42,{},data);m.start_wave()
   var point=m.waves.routes.exit_point(m.portals[portal_index],variant);point.y=m.surface_height(point.x,point.z)
   var e=m.waves.spawn_enemy(variant,point);e.road_path=m.waves.routes.guidance(point,variant)
   e.facing=atan2(-m.waves.routes.direction(m.portals[portal_index]).x,-m.waves.routes.direction(m.portals[portal_index]).z)
   var supported=true
   for step in 3400:
    var previous:Vector3=e.pos;m.waves.tick_enemy(e,.2,Vector3(0,0,18))
    supported=supported and absf(e.pos.y-m.surface_height(e.pos.x,e.pos.z))<.001 and m.terrain.step_clear(previous,e.pos)
    if maxf(absf(e.pos.x),absf(e.pos.z))<68:break
   check(maxf(absf(e.pos.x),absf(e.pos.z))<68 and e.pos.y<5 and supported,"Role %d walks from portal %d along the wall and down its ramp (%s)"%[variant,portal_index,str(e.pos)])
 m=Model.new();m.reset(42,{"bosses_per_portal":0,"waves":[[16,8,8,16]]},data);m.start_wave()
 var counts=[0,0,0,0];var used={}
 for attempt in 32:
  m.waves.spawn_batch()
  for e in m.enemies.values():counts[e.variant]+=1;used[e.portal_index]=true
  m.enemies.clear()
  if m.waves.pending==0:break
 check(counts==[16,8,8,16] and used.size()==8 and m.waves.pending==0,"All eight portals release the exact scheduled wave composition")
 var legacy=Document.new()
 check(legacy.load_ramparts().is_empty() and legacy.data.portals.size()==2,"Previous Twin Ramparts remains available")
 check(legacy.load_original().is_empty() and legacy.data.ramparts.is_empty(),"Protected Original Map remains available")
 finish()
func finish():
 print("FOUR_GATES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
