extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var Runtime=load("res://scripts/forest/crowd/army_runtime.gd");var full=Runtime.new();var scene=Runtime.new();full.configure(null);scene.configure(null)
 if not scene.native.has_method("take_scene_events"):
  check(false,"Scene delivery needs compact event fields without dropping any simulation event");full.free();scene.free();finish();return
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42)
 var data=load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model)
 for runtime in [full,scene]:
  runtime.configure_kits(data);runtime.set_navigation(1,{"width":0})
  for i in 30:
   runtime.spawn(i+1,0,[0,1,3][i%3],Vector3((i%6)*9,0,(i/6)*10),192,3.9)
   runtime.spawn(-i-1,1,[11,5,7,8,10][i%5],Vector3((i%6)*9+2,0,(i/6)*10+5),500,.4)
 var kinds={};var full_fields=0;var scene_fields=0
 for tick in 300:
  for runtime in [full,scene]:runtime.step(1.0/60,{})
  var before:Array=full.native.take_events();var after:Array=scene.native.take_scene_events()
  check(before.size()==after.size(),"Every simulation event is retained in original order")
  if before.size()!=after.size():break
  for i in before.size():
   var a:Dictionary=before[i];var b:Dictionary=after[i];kinds[a.kind]=true
   check(a.kind==b.kind and a.serial==b.serial,"Kinds and serials remain exact")
   for key in b:check(a.has(key) and a[key]==b[key],"Every delivered scene field retains the exact source value")
   if a.kind in ["damage","death","external_damage"]:check(a==b,"All gameplay hit, kill, reward and synchronous callback fields remain complete")
   full_fields+=a.size();scene_fields+=b.size()
 check(kinds.has("damage") and kinds.has("death") and kinds.has("bullet") and kinds.has("melee"),"Fixture exercises real mixed-kit attacks and deaths")
 check(scene_fields<full_fields*.65,"Scene-only delivery avoids unused bookkeeping on cosmetic events")
 # Empty drains and reconfiguration retain ordered event identity.
 check(scene.native.take_scene_events().is_empty(),"Scene delivery drains each event exactly once")
 full.clear();scene.clear();full.free();scene.free()
 print("ARMY_SCENE_EVENTS_FIELDS source=",full_fields," scene=",scene_fields," kinds=",kinds.keys())
 finish.call_deferred()
func finish():print("ARMY_SCENE_EVENTS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
