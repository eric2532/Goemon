extends SceneTree
class FormationGame extends Node:
 var model
class FormationActor extends Node3D:
 var forest_id=999
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func run():
 var path="res://assets/maps/forest_kai_highway.json"
 check(FileAccess.file_exists(path),"Kai Highway Castle is an authored playable map")
 if not FileAccess.file_exists(path):finish();return
 var layout=JSON.parse_string(FileAccess.get_file_as_string(path))
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{},layout)
 check(model.terrain_source=="kai_highway" and model.has_elevation(),"The map selects original raised Kai terrain")
 check(model.portals.size()==8,"All eight enemy portals are retained")
 check(model.buildings.values().filter(func(b):return b.kind=="gate").size()==4,"The middle fort retains four working gates")
 for x in [-54,-30,0,30,54]:
  for z in [-54,-30,0,30,54]:check(absf(model.surface_height(x,z))<.001,"The castle courtyard and wall foundations are level")
 check(model.surface_height(-120,-174)>8,"Kai's raised terraces remain outside the castle")
 check(model.terrain.cliff_cell(Vector2i(-34,-34)),"The edge cutout cannot become an AI shortcut")
 var routes=load("res://scripts/forest/forest_routes.gd").new(model)
 var nav=model.waves.navigation
 var crowd=load("res://scripts/forest/forest_enemy_crowd.gd").new()
 var origin=Vector3(-72,5.4,-132);var candidate=Vector3(-67,999,-132)
 var ground=crowd._member_ground(candidate,origin,1.0,model.terrain)
 check(ground!=null and absf(ground.y-model.surface_height(candidate.x,candidate.z))<.001,"Companion combat bodies use Kai's exact height sampler")
 check(crowd._support_certificate(origin,candidate,1.0,model.terrain).is_empty(),"A height field cannot reuse an authored flat-ground certificate")
 check(crowd._member_ground(Vector3(-204,0,-204),origin,1.0,model.terrain)==null,"Companion bodies cannot stand in the source terrain cutout")
 var formation_game=FormationGame.new();formation_game.model=model;crowd.game=formation_game
 var actor=FormationActor.new();root.add_child(actor);actor.position=origin
 var data={"pos":origin,"variant":0,"facing":0.0}
 for tick in 2:
  var formation=crowd.primitive_formation(actor,data,1.0/60,0.0)
  var grounded=true
  for pose in formation.roots:
   if not pose.basis.x.is_zero_approx() and absf(pose.origin.y-model.surface_height(pose.origin.x,pose.origin.z))>.001:grounded=false
  check(grounded,"Visible companion roots and combat contacts stay on terrain on frame %d"%tick)
 actor.free();crowd.free();formation_game.free()
 var raised_gate={"id":999,"kind":"gate","cell":Vector2i(-25,-20),"rotation":0,"span":0}
 var raised_center=model.center(raised_gate)
 check(raised_center.y>8 and absf(nav.building_point(raised_gate,raised_center).y-raised_center.y)<.001,"Ground-level building contacts follow a raised terrace foundation")
 model.buildings[999]=raised_gate
 for cell in model.footprint("gate",raised_gate.cell,0):model.occupancy[cell]=999
 model.navigation_revision+=1
 check(nav.blocker(raised_center,1.0)==999,"A raised building blocks enemy movement at its physical foundation")
 var top=raised_center+Vector3.UP*(load("res://scripts/forest/forest_structure_profile.gd").height("gate")-1)
 check(not nav.line_clear(top-Vector3(24,0,0),top+Vector3(24,0,0)),"Raised gate cover blocks attacks through its upper body")
 model.buildings.erase(999)
 for cell in model.footprint("gate",raised_gate.cell,0):model.occupancy.erase(cell)
 model.navigation_revision+=1
 for index in model.portals.size():
  var portal=model.portals[index];var spawn=routes.exit_point(portal,2);spawn.y=model.surface_height(spawn.x,spawn.z)
  check(nav.terrain_clear(spawn,8.5),"Portal %d has a full giant clearance envelope"%index)
  var path_=routes.guidance(spawn,2)
  check(path_.size()>8 and model.point(path_.back()).length()<65,"Portal %d has a connected road to the fort"%index)
  var clear=true;var previous=spawn
  for cell in path_:
   var point=model.point(cell)
   if not model.terrain.disk_clear(point,14.75) or not model.terrain.step_clear(previous,point):clear=false
   previous=point
  check(clear,"Portal %d road supports giants through ramps and bends"%index)
  for variant in range(5):
   model.enemies.clear()
   check(routes.spawn(variant,[],index),"Portal %d releases enemy variant %d"%[index,variant])
   if model.enemies.is_empty():continue
   var enemy=model.enemies.values()[0];var before=enemy.pos
   enemy.target_kind="building";enemy.target_id=1
   var deadline=ceili(((PI*.5+.25)/model.waves.role_stats(variant).turn_speed+1.5)*60) if variant==2 else 90
   for tick in deadline:
    model.waves.tick_enemy(enemy,1.0/60,Vector3.ZERO)
    if enemy.pos.distance_to(before)>1.1:break
   check(enemy.pos.distance_to(before)>1,"Portal %d variant %d advances from its spawn"%[index,variant])
   check(absf(enemy.pos.y-model.surface_height(enemy.pos.x,enemy.pos.z))<.02,"Portal unit follows the same terrain as collision")
 model.enemies.clear()
 check(load("res://scripts/forest/forest_routes.gd").validate_portals(model).is_empty(),"All portals retain a breach approach to the defended base")
 finish()
func finish():
 print("KAI_HIGHWAY_TERRAIN_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
