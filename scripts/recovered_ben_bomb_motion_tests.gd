extends SceneTree
const LeaderModel=preload("res://scripts/recovered_leader_model.gd")
class PhaseContext extends Node:
 var bomb_phase=""
 var bomb_clock=0.0
var failures=[]
func check(value: bool,message: String):
 if not value:failures.append(message);push_error(message)
func _initialize():call_deferred("run")
func run():
 # Literal first-second trace from 8017849C->8012A988 before8017E120.
 var body_keys=[0,1,12,13,14,15,16,17,12,13,14,15,16,17,18,12,13,14,15,16,17,18,12,13,14,15,16,17,12,13,14]
 var accessory_keys=[0,11,12,13,14,15,16,11,12,13,14,15,16,17,11,12,13,14,15,16,17,11,12,13,14,15,16,11,12,13,14]
 var releases=[]
 for tick in range(134):
  var frame=LeaderModel.ben_bomb_rom_frame(tick)
  if tick<body_keys.size():
   check(frame.body_key==body_keys[tick],"Original body key at world tick%d"%tick)
   check(frame.accessory_key==accessory_keys[tick],"Original accessory key at world tick%d"%tick)
  if frame.release:releases.append(tick)
 check(releases==[6,12,19,26,32,39,46,53,59,66,73,79,86,93,100,106,113,120,126,133],"All20original release ticks")
 check(not LeaderModel.ben_bomb_rom_frame(134).release,"Completed barrage must not repeat its final release")
 check(LeaderModel.ben_bomb_rom_frame(8).bob_offset_metres==-.32,"Original positive sourceY bob converts to negative GodotY")
 var model=LeaderModel.new();model.character_id=15;root.add_child(model)
 await process_frame
 var skeleton=model.skeleton
 var ap=model.animation_player
 var clip=model.motion("source_19")
 var checks=0;var max_error=0.0
 for tick in [0,1,6,7,12,14,21,30,133]:
  var frame=LeaderModel.ben_bomb_rom_frame(tick)
  model.current_clip=clip;model.blend_left=0;ap.play(clip)
  ap.seek(float(frame.body_key)/30.0,true)
  var expected=[]
  for i in skeleton.get_bone_count():expected.append(skeleton.get_bone_pose(i))
  ap.seek(float(frame.accessory_key)/30.0,true)
  for i in skeleton.get_bone_count():
   if skeleton.get_bone_name(i) in ["Part_12","Part_13","Part_14","Part_15"]:expected[i]=skeleton.get_bone_pose(i)
  model.sample_ben_bomb_rom(tick,0)
  for i in skeleton.get_bone_count():
   var actual=skeleton.get_bone_pose(i)
   var error=actual.origin.distance_to(expected[i].origin)
   for axis in range(3):error=maxf(error,actual.basis[axis].distance_to(expected[i].basis[axis]))
   max_error=maxf(max_error,error);checks+=1
   check(error<.00001,"Composite bone%s matches its independent original stream at tick%d"%[skeleton.get_bone_name(i),tick])
 var context=PhaseContext.new();root.add_child(context);model.combat=context
 var phase_checks=0
 var phase_cases=[
  ["source_18",0,"source_21",0,"source_18"],
  ["source_18",13,"source_21",13,"source_18"],
  ["source_18",24,"source_22",0,"source_18"],
  ["source_17",7,"source_22",7,"source_17"],
  ["source_17",16,"source_23",5,"source_17"],
  ["source_20",0,"source_24",0,"source_20"],
  ["source_20",34,"source_25",0,"source_20"],
  ["PropellerDeploy",5,"source_21",5,"source_18"],
  ["PropellerFly",16,"source_23",5,"source_17"],
  ["PropellerLand",34,"source_25",0,"source_20"],
  ["source_18",14,"source_21",13,"source_18","deploy",14],
  ["source_18",15,"source_23",4,"source_18","deploy",15],
  ["source_18",23,"source_23",12,"source_18","deploy",23],
  ["source_20",0,"source_22",0,"source_20","land",46],
  ["source_20",17,"source_23",6,"source_20","land",63],
  ["source_20",18,"source_24",18,"source_20","land",64]]
 for case_ in phase_cases:
  context.bomb_phase=str(case_[5]) if case_.size()>5 else ""
  context.bomb_clock=float(case_[6])/30.0 if case_.size()>6 else 0.0
  var body_clip=model.motion(case_[0]);var body_time=float(case_[1])/30.0
  model.current_clip=body_clip;model.blend_left=0;ap.play(body_clip);ap.seek(body_time,true);skeleton.force_update_all_bone_transforms()
  var expected_body=[]
  for i in skeleton.get_bone_count():expected_body.append(skeleton.get_bone_pose(i))
  var head=skeleton.find_bone("Part_00")
  var displayed_head=skeleton.get_bone_global_pose(head).origin
  var shift=Vector3.ZERO
  if body_clip.begins_with("Derived_"):
   ap.play(model.motion(case_[4]));ap.seek(body_time,true);skeleton.force_update_all_bone_transforms()
   shift=displayed_head-skeleton.get_bone_global_pose(head).origin
  ap.play(model.motion(case_[2]));ap.seek(float(case_[3])/30.0,true);skeleton.force_update_all_bone_transforms()
  var expected_accessories=[]
  for part in range(4):
   var transform=skeleton.get_bone_global_pose(skeleton.find_bone("Part_%02d"%part))
   transform.origin+=shift;expected_accessories.append(transform)
  ap.play(body_clip)
  model._sample(body_clip,body_time,0)
  check(ap.current_animation==body_clip,"Accessory sampler restores active body animation")
  for part in range(16):
   var index=skeleton.find_bone("Part_%02d"%part)
   var actual=skeleton.get_bone_global_pose(index) if part>=12 else skeleton.get_bone_pose(index)
   var expected=expected_accessories[part-12] if part>=12 else expected_body[index]
   var error=actual.origin.distance_to(expected.origin)
   for axis in range(3):error=maxf(error,actual.basis[axis].distance_to(expected.basis[axis]))
   max_error=maxf(max_error,error);phase_checks+=1
   check(error<.00001,"Body and original four-part accessory stream pair at%s key%d part%d"%[case_[0],case_[1],part])
 context.bomb_phase=""
 for test in [["source_17",10],["source_20",33]]:
  model.current_clip=model.motion(test[0]);ap.play(model.current_clip);model._sample(model.current_clip,float(test[1])/30.0,0)
  for mesh in model.ben_accessory_meshes:check(not mesh.visible,"Null pointer hides accessory mesh")
  model._sample(model.current_clip,0,0)
  for mesh in model.ben_accessory_meshes:check(mesh.visible,"Next valid pointer restores accessory mesh")
 var report={"failures":failures,"native_bone_checks":checks,"phase_bone_checks":phase_checks,"maximum_bone_error":max_error,"release_ticks":releases,"body_keys_first_second":body_keys,"accessory_keys_first_second":accessory_keys}
 var f=FileAccess.open("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Ben Bomb Motion Fix/model_counter_verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("Ben ROM bomb motion: ",JSON.stringify(report))
 model.queue_free();context.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
