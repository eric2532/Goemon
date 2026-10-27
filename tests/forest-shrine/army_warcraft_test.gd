extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Kits=preload("res://scripts/forest/crowd/army_kit_data.gd")
var checks=0
var failures=0
var runtime
var data:Dictionary
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func ticks(count:int)->Array:
 var events=[]
 for i in count:runtime.step(1.0/60,{});events.append_array(runtime.take_events())
 return events
func fixture(wall:bool=false)->Array:
 runtime.clear();runtime.configure_kits(data)
 var nav={"width":0}
 if wall:nav.merge({"ray_min":PackedVector3Array([Vector3(-8,0,1)]),"ray_max":PackedVector3Array([Vector3(8,10,1.2)]),"ray_owner":PackedInt64Array([99])})
 runtime.navigation_revision=-1;runtime.set_navigation(1,nav)
 var enemy:int=runtime.spawn(1,0,0,Vector3(0,0,3),50000,.4)
 var mirror:int=runtime.spawn(-1,1,31,Vector3.ZERO,150,.4)
 runtime.apply_hit(enemy,{"element":"ice","status_seconds":60.0});runtime.take_events()
 return [enemy,mirror]
func run():
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 data=Kits.from_model(model)
 var at:int=data.ally_kinds.find(31)
 check(at>=0 and data.blademaster.size()==4,"Blademaster is a data kit in the native owner")
 data.ally_profiles[at*5+1]=0;data.ally_profiles[at*5+4]=0
 runtime=Runtime.new();runtime.configure(null)
 var pair=fixture();var events=ticks(190)
 var hits=events.filter(func(e):return e.kind=="damage" and e.source_id==-1)
 check(hits.size()==12,"One Bladestorm delivers exactly twelve timed contacts")
 check(hits.all(func(e):return is_equal_approx(e.amount,24.0)),"Each native storm contact retains 24 base damage")
 check(events.filter(func(e):return e.kind=="status" and e.unit_kind==31 and e.action_index==9).size()==1,"One storm start event per lease")
 var later=ticks(500)
 check(later.any(func(e):return e.kind=="melee" and e.unit_kind==31),"Mirror returns to the shared primary combo")
 check(not later.any(func(e):return e.kind=="status" and e.unit_kind==31 and e.action_index==9),"Mirror never repeats its single storm")
 pair=fixture(true);events=ticks(600)
 check(not events.any(func(e):return e.kind=="damage" and e.source_id==-1),"Native storm and sword contacts respect solid cover")
 pair=fixture();ticks(40);runtime.despawn(pair[1]);runtime.take_events()
 check(not ticks(300).any(func(e):return e.kind=="damage" and e.source_id==-1),"Retired mirrors cannot deliver stale damage")
 pair=fixture();var old:int=pair[1];runtime.despawn(old);var fresh:int=runtime.spawn(-1,1,31,Vector3.ZERO,150,.4)
 check(fresh!=old and not runtime.valid(old),"Mirror slot reuse changes native generation")
 events=ticks(190)
 check(events.filter(func(e):return e.kind=="damage" and e.source_id==-1).size()==12,"A reused slot resets the one-storm state")
 var invalid=data.duplicate(true);invalid.blademaster=PackedFloat64Array([3,.25,24,-1])
 check(not runtime.native.configure_kits(invalid),"Native kit rejects invalid attack geometry")
 runtime.configure_kits(data)
 var atlas=load("res://assets/characters/ally_crowd/31.res")
 for path in atlas.get_meta("source_hashes"):check(FileAccess.file_exists(path) and FileAccess.get_sha256(path)==atlas.get_meta("source_hashes")[path],"Baked source stays current: "+path)
 check(atlas.get_meta("mesh").get_surface_count()==9,"Army bake preserves all nine independent geosets")
 for key in ["idle","walk","primary0","primary1","primary2","shadow_cut"]:check(atlas.get_meta("clips").has(key),"Original prepared clip "+key)
 await check_motion(atlas)
 runtime.free();print("ARMY_WARCRAFT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

func check_motion(atlas:Resource):
 var source=load("res://scripts/warcraft_model.gd").new();root.add_child(source);source.rotation.y=PI
 var image:Image=atlas.get_meta("pose_texture").get_image()
 var palette:Array=atlas.get_meta("palette")
 var clips:Dictionary=atlas.get_meta("clips")
 var definitions={"idle":"Stand","walk":"Walk","spin":"Attack Walk Stand Spin","primary0":"Attack","primary1":"Attack 2","primary2":"Attack Slam"}
 var error=0.0
 for key in definitions:
  var clip:Dictionary=clips[key]
  for frame in [0,int(clip.count)/2,int(clip.count)-1]:
   source.pose(definitions[key],frame/60.0);source.skeleton.force_update_all_bone_transforms()
   for i in palette.size():
    var entry:Dictionary=palette[i];var node=source.rig_visual.find_child(entry.mesh,true,false)
    var expected:Transform3D=source.skeleton.global_transform*source.skeleton.get_bone_global_pose(entry.bone)*node.skin.get_bind_pose(entry.bind)
    for axis in 3:
     var actual=image.get_pixel(i*6+axis,int(clip.start)+frame)
     error=maxf(error,Vector3(actual.r,actual.g,actual.b).distance_to(expected.basis[axis]))
     error=maxf(error,absf(actual.a-expected.origin[axis]))
    var opacity=image.get_pixel(i*6+3,int(clip.start)+frame).a
    check(is_equal_approx(opacity,node.material_override.albedo_color.a if node.visible else 0.0),"Original animated geoset opacity")
 check(error<.0001,"Native pose atlas preserves original skin transforms, including Critical Strike")
 print("WARCRAFT_MIRROR_MOTION_MAX_ERROR ",error)
 source.queue_free();await process_frame
