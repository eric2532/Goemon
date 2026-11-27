extends SceneTree
## Preserve friendly/terrain contracts while replacing the old enemy-only half-plane.
const Model=preload("res://scripts/forest/forest_model.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Army=preload("res://scripts/forest/crowd/army_runtime.gd")
const Safety=preload("res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source art inventory/Safety metadata/Prepared preview/data.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja enemy safety/"
var checks=0
var failures=0
func _initialize():
 create_timer(180).timeout.connect(func():printerr("FREYJA_SAFETY_TIMEOUT");quit(1))
 run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FREYJA_SAFETY_FAIL ",label)
func source_local(area:String,cell:Vector2)->Vector2:return Regions.frame(area).inverse()*(cell*3.)
func safe(area:String,point:Vector2)->bool:
 var pixel=Vector2i(((point-Safety.ORIGINS[area])/3.).round())
 return Safety.SAFE_RECTANGLES[area].any(func(rect):return rect.has_point(pixel))
func run():
 var before="--before"in OS.get_cmdline_user_args();var rows=[]
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+"Before/"))
 var runtime=Army.new();check(runtime.configure(null,64),"Existing native runtime is available")
 for area in Safety.ORIGINS:
  var model=Model.new();model.reset(41829558,{},Regions.layout(area),false)
  var data=Army.navigation_data(model);runtime.native.set_navigation(data)
  var path=REVIEW+"Before/"+area+".res";var protected:Resource
  if before:
   protected=Resource.new();protected.set_meta("navigation",data)
  else:
   protected=load(path);check(protected!=null,"Protected baseline exists "+area)
   if protected==null:continue
   var previous:Dictionary=protected.get_meta("navigation")
   for key in previous:
    if key in ["obstacle_min","obstacle_max"]:continue
    check(var_to_bytes(previous[key])==var_to_bytes(data[key]),"Terrain/friendly/bridge/ray data stays exact "+area+" "+key)
  var samples=[]
  if before:
   for rect:Rect2i in Safety.SAFE_RECTANGLES[area]:
    for y in range(rect.position.y,rect.end.y,3):
     for x in range(rect.position.x,rect.end.x,3):
      var at:Vector2=Safety.ORIGINS[area]+Vector2(x,y)*3.;var world=model.world_point(at)
      if runtime.native.ally_ground_clear(world,.1):samples.append({"kind":"safe_owner","point":at});break
     if samples.size()>=3:break
    if samples.size()>=3:break
   if not Safety.SAFE_RECTANGLES[area].is_empty():check(not samples.is_empty(),"Actual city/village owner has a friendly-supported sample "+area)
   if area in ["freyja","east_gate"]:
    var found=0
    for y in range(36,135,2):
     for x in range(408,440,2):
      var at=source_local(area,Vector2(x,y));var world=model.world_point(at)
      if not safe(area,at) and runtime.native.ally_ground_clear(world,.1) and not runtime.native.can_reach(world,world,.1):
       samples.append({"kind":"suppressed_source_outdoor","source_cell":Vector2(x,y),"point":at});found+=1
      if found>=3:break
     if found>=3:break
    check(found>0,"Old220half-plane suppresses physically supported source outdoor ground "+area)
   protected.set_meta("samples",samples);check(ResourceSaver.save(protected,path)==OK,"Before native contract stored "+area)
  else:
   samples=protected.get_meta("samples")
   for sample in samples:
    var world=model.world_point(sample.point)
    check(runtime.native.ally_ground_clear(world,.1),"Friendly source route remains open "+area+" "+str(sample.point))
    var exposed:bool=model.FalanFrontier.call("enemy_exposed",model,sample.point)
    if sample.kind=="safe_owner":
     check(not exposed and not runtime.native.can_reach(world,world,.1),"City/village is safe for player and native enemy movement "+area)
    else:
     check(exposed and runtime.native.can_reach(world,world,.1),"Source outdoor enemy movement and player targetability agree "+area+" "+str(sample.source_cell))
  rows.append({"area":area,"native_obstacles":data.obstacle_min.size(),"friendly_obstacles":data.friendly_obstacle_min.size(),"safe_rectangles":Safety.SAFE_RECTANGLES[area].size(),"samples":samples.size()})
 runtime.free();await process_frame
 var result={"before":before,"checks":checks,"failures":failures,"areas":rows,"qualification":"Production model/native navigation data only; friendly/terrain/bridges/rays exact. Direct fights and rendered gameplay are separate."}
 var file=FileAccess.open(REVIEW+("before.json"if before else"verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
 print("FREYJA_ENEMY_SAFETY ",checks," checks ",failures," failures before=",before);quit(1 if failures else 0)
