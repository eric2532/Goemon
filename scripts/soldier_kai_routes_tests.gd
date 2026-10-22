extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func run():
 var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_kai_highway.json"))
 for role in [0,1,3]:
  for index in 8:
   var m=Model.new();m.reset(42,{},layout);m.workers.clear();m.defenders.clear();m.hero_targetable=false
   var reserved=[];var success=m.waves.routes.spawn(role,reserved,index)
   check(success,"Enlarged role%d portal%d has a supported spawn"%[role,index])
   if not success:continue
   var e:Dictionary=m.enemies.values()[0];var safe=true
   for step in 1800:
    var before:Vector3=e.pos;m.waves.tick_enemy(e,.1,Vector3(0,0,18))
    safe=safe and m.terrain.step_clear(before,e.pos) and absf(e.pos.y-m.surface_height(e.pos.x,e.pos.z))<.001 and m.waves.navigation.fitted_blocker(e,e.pos)<0
    if maxf(absf(e.pos.x),absf(e.pos.z))<68 or (role==1 and e.action=="source_attack"):break
   check(safe and (maxf(absf(e.pos.x),absf(e.pos.z))<68 or (role==1 and e.action=="source_attack")),"Enlarged role%d portal%d walks downhill to castle without crossing cliffs or solids"%[role,index])
 print("SOLDIER_KAI_ROUTES_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
