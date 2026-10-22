extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Document=preload("res://scripts/forest/forest_map_document.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func fresh():
 var m=Model.new();m.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false)
 return m
func add(m,kind:String,cell:Vector2i,rotation:int=0,span:int=0):
 return m._make_building(kind,cell,rotation,span)
func run():
 var m=fresh()
 check(m.placement_error("tower",Vector2i(-30,-30),0).is_empty(),"Clear flat land outside the old settlement and sight bounds is buildable")
 check(not m.build("tower",Vector2i(-30,-30),0).is_empty(),"A distant clear site commits a real purchase")
 check(not m.placement_error("tower",Vector2i(-39,38),0).is_empty(),"The entire footprint still stays inside the navigable map margin")
 m=fresh();m.hero_position=m.point(Vector2i(10,10))
 var worker=m.workers.values()[0];worker.pos=m.point(Vector2i(11,10))
 m.defenders[-10]={"hp":100.0,"pos":m.point(Vector2i(10,11))};m.fighter_posts[-20]=m.point(Vector2i(11,11))
 check(m.placement_error("tower",Vector2i(10,10),0).is_empty(),"Temporary actors and assigned guard posts do not reserve otherwise clear land")
 m=fresh();add(m,"tower",Vector2i(20,20))
 for c in [Vector2i(20,22),Vector2i(21,22),Vector2i(22,21),Vector2i(22,20),Vector2i(19,20),Vector2i(19,21),Vector2i(20,19),Vector2i(21,19)]:m.trees[c]=1.0
 m.workers.values()[0].pos=m.point(Vector2i(20,22));m.rebuild_navigation()
 check(m.placement_error("barracks",Vector2i(10,-10),0).is_empty(),"An already unreachable workplace or worker does not veto unrelated clear ground")
 check(m.placement_error("tower",Vector2i(10,-10),2).is_empty(),"A new building does not require a worker route to its entrance")
 m=fresh();check(not m.build("tower",Vector2i(-1,2),0).is_empty(),"The original hero standing point and shrine entry are usable land")
 var doc=Document.new(false);doc.capture(m)
 check(Document.validate(doc.data).is_empty(),"A legal structure at the original hero point validates for saving")
 var loaded=Document.new(false)
 check(loaded.decode(doc.encode()).is_empty() and loaded.play_error().is_empty(),"A legal clear-ground layout reloads and can be played")
 for rotation in range(4):
  m=fresh();add(m,"gate",Vector2i(10,10),rotation);m.rebuild_navigation()
  var approaches=[Vector2i(10,8),Vector2i(10,11)] if rotation%2==0 else [Vector2i(8,10),Vector2i(11,10)]
  for c in approaches:check(not m.placement_error("tower",c,0).is_empty(),"Gate rotation %d protects its immediate passage at %s"%[rotation,c])
  var nearby=Vector2i(12,10) if rotation%2==0 else Vector2i(10,12)
  check(m.placement_error("tower",nearby,0).is_empty(),"Gate rotation %d leaves clear ground beside its frame buildable"%rotation)
  doc=Document.new(false);doc.capture(m);doc.data.buildings.append({"kind":"tower","x":approaches[0].x,"z":approaches[0].y,"rotation":0,"span":0})
  check(not Document.validate(doc.data).is_empty(),"Saved layouts also protect gate approach ground, rotation %d"%rotation)
 m=fresh();add(m,"gate",Vector2i(0,10))
 for z in range(3,20):
  add(m,"wall",Vector2i(-1,z),0,1);add(m,"wall",Vector2i(2,z),0,1)
 m.rebuild_navigation()
 check(not m.route(Vector2i(0,2),Vector2i(0,10)).is_empty(),"Gate corridor starts connected to the shrine")
 var route_before=m.route(Vector2i(0,2),Vector2i(0,10));var gold_before=m.gold;var revision_before=m.navigation_revision
 check(not m.placement_error("tower",Vector2i(0,6),0).is_empty(),"A clear footprint cannot newly sever the existing gate route inside its approach corridor")
 check(not m.placement_error("tower",Vector2i(0,14),0).is_empty(),"A clear footprint cannot newly seal the outer end of an existing gate corridor")
 check(m.route(Vector2i(0,2),Vector2i(0,10))==route_before and m.gold==gold_before and m.navigation_revision==revision_before,"Rejected previews restore navigation and never charge or change revisions")
 doc=Document.new(false);doc.capture(m)
 check(not doc.placement_error("tower",Vector2i(0,14),0).is_empty(),"The map editor preserves the same existing gate routes as live construction")
 var before_doc=doc.encode()
 check(not doc.place("tower",Vector2i(0,14),0).is_empty() and doc.encode()==before_doc,"A blocked gate edit cannot change the saved layout")
 add(m,"tower",Vector2i(0,6));m.rebuild_navigation()
 check(m.placement_error("tower",Vector2i(15,-10),0).is_empty(),"A gate route already closed by an authored layout does not veto unrelated clear land")
 m=fresh();m.portals.append({"x":20,"z":20,"rotation":2})
 check(not m.placement_error("gate",Vector2i(20,17),0).is_empty(),"A new gate cannot open directly into reserved physical portal space")
 check(not m.build("gate",Vector2i(20,16),0).is_empty(),"Nearby gate ground stays buildable when both approach rows clear the portal")
 doc=Document.new(false);doc.capture(m)
 check(Document.validate(doc.data).is_empty() and Document.new(false).decode(doc.encode()).is_empty(),"A legal gate beside a portal survives validation and reload")
 m=fresh();m.deposits[Vector2i(20,20)]=1200
 check(not m.placement_error("gate",Vector2i(20,19),0).is_empty(),"A new gate cannot open directly into a mine deposit footprint")
 m=fresh();m.trees[Vector2i(10,10)]=1.0;m.rebuild_navigation()
 check(not m.placement_error("tower",Vector2i(10,10),0).is_empty(),"Physical trees remain obstacles")
 check(not m.placement_error("tower",Vector2i(2,2),0).is_empty(),"The training dummy remains physical occupied space")
 check(m.placement_error("mine",Vector2i(10,10),0)=="Gold mines are unavailable","Disabled mines retain their separate rules")
 m=fresh();var built=m.build("tower",Vector2i(10,10),0)
 check(not built.is_empty() and not m.placement_error("tower",Vector2i(10,10),0).is_empty(),"An actual building footprint prevents overlap")
 m.phase="wave";check(not m.placement_error("tower",Vector2i(20,10),0).is_empty(),"Construction still waits for preparation")
 m.phase="preparing";m.gold=0;check(not m.placement_error("tower",Vector2i(20,10),0).is_empty(),"Construction still requires its price")
 print("BUILD_ANY_CLEAR_GROUND_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
