extends SceneTree
## Bake Musashi's recovered gait onto Ed's rigid parts, preserving Ed's lengths.
const OUTPUT="res://assets/animations/ed_musashi_gait.res"
const MAP={0:4,1:5,2:7,3:6,4:8,5:20,6:18,7:11,8:19,9:12}
const CHAINS=[[1,2],[3,4],[6,7],[8,9]]
var ed
var donor
var target_rest={}
var source_rest={}
var ed_feet=[]
var donor_feet=[]
func _initialize():run.call_deferred()
func poses(model,ed_parts: bool)->Dictionary:
 var result={}
 for i in model.skeleton.get_bone_count():
  var label=model.skeleton.get_bone_name(i)
  if label.begins_with("Part_"):result[int(label.substr(5,2))]=model.skeleton.get_bone_global_pose(i)
 return result
func foot_vertices(model,prefixes: Array)->Array:
 var result=[]
 for mesh in model.rig_visual.find_children("*","MeshInstance3D",true,false):
  if not prefixes.any(func(prefix):return str(mesh.name).begins_with(prefix)):continue
  for surface in mesh.mesh.get_surface_count():
   var arrays=mesh.mesh.surface_get_arrays(surface)
   for v in arrays[Mesh.ARRAY_VERTEX].size():
    var bind=int(arrays[Mesh.ARRAY_BONES][v*4])
    var label=str(mesh.skin.get_bind_name(bind))
    result.append([int(label.substr(5,2)),mesh.skin.get_bind_pose(bind)*arrays[Mesh.ARRAY_VERTEX][v]])
 return result
func lowest(parts: Dictionary,vertices: Array)->float:
 var low=INF
 for entry in vertices:low=minf(low,(parts[entry[0]]*entry[1]).y)
 return low
func fit(source: Dictionary,ratio: float)->Dictionary:
 var result={}
 for i in MAP:
  var src:Transform3D=source[MAP[i]];var ref:Transform3D=source_rest[MAP[i]];var rest:Transform3D=target_rest[i]
  result[i]=Transform3D(src.basis.orthonormalized()*ref.basis.orthonormalized().inverse()*rest.basis,rest.origin+(src.origin-ref.origin)*ratio)
 for chain in CHAINS:
  var a:int=chain[0];var b:int=chain[1]
  var original:Vector3=target_rest[b].origin-target_rest[a].origin
  var donor_vector:Vector3=source_rest[MAP[b]].origin-source_rest[MAP[a]].origin
  var align=Basis(Quaternion(donor_vector.normalized(),original.normalized()))
  var turn=align*source[MAP[a]].basis.orthonormalized()*source_rest[MAP[a]].basis.orthonormalized().inverse()*align.inverse()
  # Musashi's single arm part pivots at the elbow; Ed has a separate upper
  # arm. Anchor Ed's shoulders/hips to his torso instead of copying that pivot.
  var torso_turn=source[20].basis.orthonormalized()*source_rest[20].basis.orthonormalized().inverse()
  result[a].origin=result[5].origin+torso_turn*(target_rest[a].origin-target_rest[5].origin)
  result[a].basis=turn*target_rest[a].basis
  result[b].origin=result[a].origin+turn*original
  result[b].basis=align*source[MAP[b]].basis.orthonormalized()*source_rest[MAP[b]].basis.orthonormalized().inverse()*align.inverse()*target_rest[b].basis
 return result
func run():
 # Raw assets avoid invoking the runtime adapter while rebuilding this library.
 ed=load("res://scripts/recovered_leader_model.gd").new();ed.character_id=14;root.add_child(ed)
 donor=load("res://scripts/recovered_musashi_model.gd").new();root.add_child(donor)
 ed._sample(ed.motion("source_00"),0,0);target_rest=poses(ed,true)
 donor._sample(donor.IDLE,0);source_rest=poses(donor,false)
 ed_feet=foot_vertices(ed,["07_","09_"]);donor_feet=foot_vertices(donor,["11_","12_"])
 assert(not ed_feet.is_empty() and not donor_feet.is_empty())
 var ratio=(target_rest[7].origin-target_rest[6].origin).length()/(source_rest[11].origin-source_rest[18].origin).length()
 var ground=-ed.rig_visual.position.y/ed.rig_visual.scale.y
 var library=AnimationLibrary.new()
 for pair in [["Walk",donor.WALK],["Run",donor.RUN],["Sprint",donor.SPRINT]]:
  var duration=donor.animation_player.get_animation(pair[1]).length
  var count=ceili(duration*60);var frames=[];var floors=[];var floor_min=INF
  for key in count:
   donor._sample(pair[1],duration*key/count)
   var source=poses(donor,false)
   frames.append(fit(source,ratio));var low=lowest(source,donor_feet);floors.append(low);floor_min=minf(floor_min,low)
  var animation=Animation.new();animation.length=duration;animation.loop_mode=Animation.LOOP_LINEAR
  for part in range(10):
   for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
    var track=animation.add_track(type);animation.track_set_path(track,NodePath("Ed/Skeleton3D:Part_%02d"%part))
    for key in range(count+1):
     var index=key%count;var pose:Transform3D=frames[index][part]
     pose.origin.y+=ground+(floors[index]-floor_min)*ratio-lowest(frames[index],ed_feet)
     var value=pose.origin if type==Animation.TYPE_POSITION_3D else (pose.basis.get_rotation_quaternion() if type==Animation.TYPE_ROTATION_3D else Vector3.ONE)
     animation.track_insert_key(track,duration*key/count,value)
  animation.set_meta("donor_clip",pair[1]);animation.set_meta("donor_asset","res://assets/characters/recovered_musashi/musashi.glb")
  animation.set_meta("target","Ed original ten-part rig; fixed limb lengths; in-place root")
  library.add_animation(pair[0],animation)
  print("ED_MUSASHI_BAKE ",pair[0]," frames=",count," duration=",duration)
 assert(ResourceSaver.save(library,OUTPUT)==OK)
 ed.queue_free();donor.queue_free();await process_frame;quit()
