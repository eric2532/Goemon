extends SceneTree
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Kit=preload("res://scripts/forest/crowd/army_kit_data.gd")
const Dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func skins()->Array:return range(41,61)
func run():
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42)
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 var data=Kit.from_model(model)
 check(data.pet_geometry.size()==(Pets.COUNT+29+5)*7,"Native geometry offsets include all companion skins")
 for skin in skins():
  runtime.clear();runtime.set_navigation(1,{"width":0});runtime.configure_kits(data)
  var handle=runtime.spawn(1,0,19,Vector3.ZERO,100000,.5)
  runtime.native.set_pet_skin(handle,skin);runtime.native.set_pose(handle,Vector3.ZERO,0)
  runtime.native.set_targets({"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3(0,0,-1.5)]),"hp":PackedFloat32Array([100000])})
  var hits=0;var sounds={}
  for tick in 360:
   runtime.step(1.0/60,{})
   for event in runtime.take_events():
    if event.kind=="external_damage":hits+=1;check(event.amount>0,"Source contact deals positive damage")
    if event.kind=="status" and event.action_index>=500:sounds[int(event.action_index)-500]=true
  check(hits>=2,"Repeated native contacts for "+Pets.title(skin))
  var expected={}
  for direction in Pets.motions().variants[skin].attack_directions:
   for cue in direction:
    if int(cue.id)>0:expected[int(cue.id)]=true
  check((expected.is_empty() or not sounds.is_empty()) and sounds.keys().all(func(c):return expected.has(c)),"Original attack audio for "+Pets.title(skin))
  check(Dimensions.companion_body(skin).has_volume(),"Prepared normal/XL body has positive dimensions")
 runtime.clear();runtime.free();data.clear();model=null
 await process_frame;await process_frame
 print(Pets.category(skins()[0])+" COMBAT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
