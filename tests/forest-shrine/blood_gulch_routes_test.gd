extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1;print("PASS: " if ok else "FAIL: ",label_)
 if not ok:failures+=1
func run():
 var doc=Document.new(false);var error=doc.load_blood_gulch()
 check(error.is_empty(),"The native castle layout is valid")
 if not error.is_empty():finish();return
 var model=Model.new();model.reset(42,{},doc.data,false);model.workers.clear();model.defenders.clear();model.hero_targetable=false;model.start_wave()
 for building in model.buildings.values():building.hp=1e12;building.max_hp=1e12
 for portal in model.portals:
  for kind in [0,1,3,4]:
   var point=model.waves.routes.exit_point(portal,kind);point.y=model.surface_height(point.x,point.z)
   var enemy=model.waves.spawn_enemy(kind,point)
   var forward=model.waves.routes.direction(portal);enemy.facing=atan2(-forward.x,-forward.z)
   var gate=model.waves.routes.gate_target(enemy)
   check(gate>=0 and model.buildings.get(gate,{}).get("kind")=="gate","Portal %s role %d acquires a castle gate"%[Vector2i(portal.x,portal.z),kind])
   if gate<0:model.enemies.clear();continue
   var reached=false;var supported=true
   for step in 1200:
    var previous:Vector3=enemy.pos
    model.waves.flow.begin_tick();model.waves.tick_enemy(enemy,.25,Vector3(0,0,18))
    if absf(enemy.pos.y-model.surface_height(enemy.pos.x,enemy.pos.z))>.002 or not model.terrain.step_clear(previous,enemy.pos):supported=false
    var target=model.buildings.get(enemy.get("target_id",-1),{})
    if enemy.get("target_kind","")=="building" and target.get("kind")=="gate" and (enemy.get("attack",false) or enemy.get("action","") in ["windup","strike","recover"]):reached=true;break
   check(reached and supported,"Portal %s role %d reaches and attacks a gate on supported terrain (%s)"%[Vector2i(portal.x,portal.z),kind,str(enemy.pos)])
   model.enemies.clear()
 finish()
func finish():
 print("BLOOD_GULCH_ROUTES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
