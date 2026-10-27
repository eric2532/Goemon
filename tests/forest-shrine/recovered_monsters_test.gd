extends SceneTree
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Visual=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func expected_pose(part:Dictionary)->Transform3D:
 var angle=Vector3(part.angles[0],part.angles[1],part.angles[2])*PI/4096
 var x=angle.x;var y=angle.y;var z=angle.z
 var q=Quaternion(sin(x)*cos(y)*cos(z)-cos(x)*sin(y)*sin(z),-(cos(x)*sin(y)*cos(z)+sin(x)*cos(y)*sin(z)),-(cos(x)*cos(y)*sin(z)-sin(x)*sin(y)*cos(z)),cos(x)*cos(y)*cos(z)+sin(x)*sin(y)*sin(z))
 return Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*.018),Vector3.ZERO)*Transform3D(Basis(q),Vector3(part.position[0],-part.position[1],-part.position[2]))
func run():
 check(Roles.RECOVERED[Roles.HAYA_WOLF]=="karate_wolf","Wolf role selects the verified 13-part wolf, preserving the misnamed gorilla separately")
 check(Visual.data(Roles.HAYA_WOLF).get_meta("part_count")==13,"Runtime imports the wolf's own body")
 check(Visual.data(Roles.HAYA_WOLF).get_meta("semantics").attack==["Source__801a84d0"],"Runtime selects the wolf's actual flying kick")
 check(Roles.SLOW_GUY!=Roles.HAYA_WOLF and Roles.RECOVERED[Roles.SLOW_GUY]=="haya_wolf","Gorilla and wolf have separate native types and shared resources")
 check(Visual.data(Roles.SLOW_GUY).get_meta("part_count")==12 and Visual.data(Roles.SLOW_GUY).get_meta("semantics").attack==["Source__801a1874"],"Gorilla retains its original 12-part body and arm-swing attack")
 check(preload("res://scripts/forest/forest_enemy_contact.gd").shapes(2).is_empty(),"Retired model paths do not attempt to load an empty resource")
 var max_error=0.0;var samples=0;var worst=""
 for kind in Roles.RECOVERED:
  var resource:Resource=Visual.data(kind);var source_path:String=resource.get_meta("source_path")
  check(resource.get_meta("source_sha256")==FileAccess.get_sha256(source_path),"Pose bake hashes the actual authored/recovered source")
  check(resource.get_meta("visual_sha256")==FileAccess.get_sha256(resource.get_meta("visual_path")),"Pose bake hashes the actual imported GLB")
  var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/recovered_monsters/"+Roles.RECOVERED[kind]+"_motion.json"))
  var clips:Dictionary=resource.get_meta("clips");var poses:Array=resource.get_meta("poses");var count:int=resource.get_meta("part_count")
  for clip in original.clips:
   check(clips.has(clip.name),"Every original action survives editable import/export/bake")
   for frame in clip.frames:
    var row:int=clips[clip.name].rows[mini(int(frame.tick),clips[clip.name].rows.size()-1)]
    for index in count:
     var expected=expected_pose(original.poses[frame.pose][index]);var actual:Transform3D=poses[row*count+index]
     var error:float=expected.origin.distance_to(actual.origin)
     if error>max_error:worst="%s %s tick=%d part=%d expected=%s actual=%s"%[Roles.RECOVERED[kind],clip.name,frame.tick,index,expected.origin,actual.origin]
     max_error=maxf(max_error,error)
     for axis in 3:max_error=maxf(max_error,(expected.basis[axis]-actual.basis[axis]).length())
     samples+=1
 check(max_error<.0001,"All imported/baked source part matrices match, including mixed full/packed kick frames: "+worst)
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 var data:Dictionary=load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model)
 runtime.configure_kits(data)
 for kind in [Roles.VAMBEE,Roles.HAYA_WOLF,Roles.VAMBEE_TORSO,Roles.SLOW_GUY]:
  for delta in [1.0/20,1.0/30,1.0/60]:
   runtime.clear();runtime.set_navigation(12,{"width":0,"origin":Vector3(-240,0,-240)})
   var enemy:int=runtime.spawn(1,0,kind,Vector3.ZERO,model.waves.role_stats(kind).hp,Roles.footprint_radius(kind))
   runtime.spawn(-1,1,12,Vector3(0,0,-1.6),100000,.4)
   var markers=[];var done=false;var kicks=false;var hits=0
   for step in 400:
    runtime.step(delta,{})
    for event in runtime.take_events():
     if event.kind=="melee":markers.append(event.source_tick)
     if event.kind=="damage" and event.target_id==-1:hits+=1
     if event.kind=="done":done=true
    if runtime.unit_state(enemy).position.z<-.1:kicks=true
    if done:break
   check(done and markers==[float(Roles.ATTACKS[kind].contact)],"Shared native attack engine preserves one contact at every simulation rate: %d"%kind)
   check(hits==1,"Each original attack damages its actual victim exactly once: %d"%kind)
   check(kind!=Roles.HAYA_WOLF or kicks,"The kick moves forward through the existing terrain sweep")
   check(kind!=Roles.SLOW_GUY or not kicks,"Gorilla's planted swing does not inherit wolf kick travel")
 for delta in [1.0/20,1.0/30,1.0/60]:
  for entry_tick in [16,20,22]:
   runtime.clear();runtime.set_navigation(120+entry_tick,{"width":0})
   var gorilla:int=runtime.spawn(1,0,Roles.SLOW_GUY,Vector3.ZERO,640,1.5)
   var victim:int=runtime.spawn(-1,1,12,Vector3(0,0,-1.6),100000,.4)
   for step in 20:
    runtime.step(delta,{})
    if runtime.unit_state(gorilla).action==1:break
   runtime.set_pose(victim,Vector3(0,0,-20),0);runtime.take_events()
   var hits=0;var finished=false
   for step in 200:
    if runtime.unit_state(gorilla).action_time*30+0.00001>=entry_tick:runtime.set_pose(victim,Vector3(0,0,-1.6),0)
    runtime.step(delta,{})
    for event in runtime.take_events():
     if event.kind=="damage" and event.target_id==-1:hits+=1
     if event.kind=="done":finished=true
    if finished:break
   check(finished and hits==(1 if entry_tick<=20 else 0),"Gorilla active frames 15–20 catch a late arrival once and reject a late miss: %d at %s"%[entry_tick,delta])
 runtime.clear();runtime.set_navigation(13,{"width":0})
 var handle:int=runtime.spawn(2,0,Roles.VAMBEE,Vector3.ZERO,100,1.3)
 var hit:Dictionary=runtime.apply_hit(handle,{"amount":1000.0})
 check(hit.accepted and not hit.dead and runtime.valid(handle) and runtime.unit_state(handle).kind==Roles.VAMBEE_TORSO,"Vambee transforms into its original crawling torso without a second actor/simulation")
 check(runtime.take_events().any(func(e):return e.kind=="status" and e.action_index==17),"Shared event stream publishes the split exactly once")
 hit=runtime.apply_hit(handle,{"amount":100000.0})
 check(hit.dead and not runtime.valid(handle),"Torso dies through the same damage/death lifecycle")
 check(not runtime.apply_hit(handle,{"amount":1.0}).accepted,"Old handles cannot damage a replacement")
 var invalid:Dictionary=data.duplicate(true);invalid.enemy_kits[25]=0
 check(not runtime.native.configure_kits(invalid),"The shared profile rejects a self-reviving form")
 invalid=data.duplicate(true);invalid.enemy_kits[5]=10000
 check(not runtime.native.configure_kits(invalid),"The shared profile rejects contacts outside their phase")
 invalid=data.duplicate(true);invalid.enemy_contact_ends[0]=INF
 check(not runtime.native.configure_kits(invalid),"Source contact windows reject nonfinite input")
 invalid=data.duplicate(true);invalid.enemy_contact_ends[0]=10000
 check(not runtime.native.configure_kits(invalid),"Source contact windows cannot extend beyond an attack")
 runtime.configure_kits(data)
 var seen={}
 for i in 30:
  for slot in [0,1,3]:seen[Roles.wave_variant(slot,i)]=true
 check(seen.size()==6 and seen.has(Roles.VAMBEE) and seen.has(Roles.HAYA_WOLF) and seen.has(Roles.SLOW_GUY),"Saved four-slot wave budgets include gorilla and wolf without increasing counts")
 check(Roles.WAVE_TYPES.has(Roles.SLOW_GUY) and Roles.WAVE_TYPES.has(Roles.HAYA_WOLF),"Continuous camp waves include both enemies")
 runtime.free();model=null
 print("RECOVERED_MONSTERS_RESULT checks=",checks," failures=",failures," source_part_samples=",samples," max_matrix_error=",max_error)
 quit(1 if failures else 0)
