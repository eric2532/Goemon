extends SceneTree
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Kits=preload("res://scripts/forest/crowd/army_kit_data.gd")
var checks=0
var failures=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():run.call_deferred()
func run():
 check(Model.uses_slime_waves(),"Run this fixture with --crossgate-pet-test")
 for path in [Document.WIND_MEADOW_PATH,Document.WIND_MEADOW_LARGE_PATH]:
  var doc=Document.new(false);check(doc.read_file(path).is_empty(),"Arena size loads")
  var model=Model.new();model.reset(42,{},doc.data,false)
  var kit=Kits.from_model(model)
  check(kit.slime_approach_boost,"Only the arena enables accelerated slime approach")
  var runtime=Runtime.new();runtime.configure(null);runtime.set_navigation(1,Runtime.navigation_data(model));runtime.configure_kits(kit)
  var target=model.point(Vector2i(0,3))
  # Preserve the arena's non-player boost; shared player crowding is tested separately.
  var targets={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([3]),"positions":PackedVector3Array([target]),"hp":PackedFloat32Array([100000])}
  for hz in [20,30,60]:
   var previous=10.0
   for distance in [160,120,100,80,60,40,20]:
    runtime.clear();runtime.native.set_targets(targets)
    var point=target+Vector3.FORWARD*distance;point.y=model.surface_height(point.x,point.z)
    var h=runtime.spawn(1,0,20,point,5000,3.9)
    runtime.step(1.0/hz,{})
    var state=runtime.unit_state(h);var speed=Vector2(state.velocity.x,state.velocity.z).length()
    check(speed<=previous+.04 and speed>=2.95,"Actual map approach decelerates smoothly at %d m / %d Hz"%[distance,hz])
    if distance==160:check(absf(speed-9)<.04,"Distant slime moves at three times the base pace")
    if distance==20:check(absf(speed-3)<.04,"Nearby slime keeps the original melee pace")
    previous=speed
   runtime.clear()
   kit.slime_approach_boost=false;runtime.configure_kits(kit);runtime.native.set_targets(targets)
   var point=target+Vector3.FORWARD*160;point.y=model.surface_height(point.x,point.z)
   var h=runtime.spawn(1,0,20,point,5000,3.9);runtime.step(1.0/hz,{})
   var state=runtime.unit_state(h)
   check(absf(Vector2(state.velocity.x,state.velocity.z).length()-3)<.04,"Disabled kit retains the original speed")
   kit.slime_approach_boost=true;runtime.configure_kits(kit)
   targets.kinds=PackedInt32Array([0])
   for distance in [160,80,20]:
    runtime.clear();runtime.native.set_targets(targets)
    var player_approach=target+Vector3.FORWARD*distance
    player_approach.y=model.surface_height(player_approach.x,player_approach.z)
    var pursuer=runtime.spawn(1,0,20,player_approach,5000,3.9)
    runtime.step(1.0/hz,{})
    var velocity:Vector3=runtime.unit_state(pursuer).velocity
    var speed=Vector2(velocity.x,velocity.z).length()
    var expected={160:12.0,80:8.25,20:4.5}[distance]
    check(absf(speed-expected)<.1,"Player pursuit moves at %.2f m/s at %d m / %d Hz (measured %.3f)"%[expected,distance,hz,speed])
   targets.kinds=PackedInt32Array([3])
  runtime.clear();runtime.free()
  model.terrain_detail=""
  check(not Kits.from_model(model).slime_approach_boost,"Other maps retain their existing movement")
 print("SLIME_APPROACH_GODOT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
