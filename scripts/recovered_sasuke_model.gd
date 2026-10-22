extends HeroModel
## Sasuke's retail rigid meshes, rendered with their original native matrices.
const NativePose=preload('res://scripts/recovered_sasuke_pose.gd')
const NativeBody=preload('res://scripts/recovered_sasuke_body.gd')
const NativeLocomotion=preload('res://scripts/recovered_sasuke_locomotion.gd')
# Same source-unit conversion as original Goemon; retains native relative stature.
const NATIVE_SCALE=0.015158092072935184
const KUNAI=['0x9002aa8','0x9002bc8']
var native_parts:Dictionary={}
var sampler:RefCounted
var combat:Node
var source_scale=NATIVE_SCALE
var source_offset=Vector3.ZERO
var native_bones:Dictionary={}
var robe_skeleton:Skeleton3D
var source_action=0
var source_time=0.0
func _ready():
 set_meta('original_sasuke',true);set_meta('original_kunai_tier',3)
 body=Node3D.new();body.name='OriginalN64Sasuke';add_child(body)
 rig_visual=Node3D.new();rig_visual.name='NativeSourceSpace';rig_visual.rotation.y=PI;body.add_child(rig_visual)
 head=driver('Head',Vector3.ZERO)
 arms.assign([driver('Arm_L',Vector3.ZERO),driver('Arm_R',Vector3.ZERO)])
 legs.assign([driver('Leg_L',Vector3.ZERO),driver('Leg_R',Vector3.ZERO)])
 scarf=driver('Sash',Vector3.ZERO)
 hair_normal=Node3D.new();body.add_child(hair_normal)
 hair_gold=Node3D.new();body.add_child(hair_gold);hair_gold.hide()
 sampler=NativePose.new();sampler.source_scale=source_scale
 native_parts=NativeBody.create_parts()
 for pointer in native_parts:rig_visual.add_child(native_parts[pointer])
 var reference:Dictionary=sampler.sample_source(0,0)
 var minimum_y=INF
 for pointer in native_parts:
  if not reference.has(pointer):continue
  for vertex in NativeBody.data().parts[pointer].vertices:
   var p:Array=vertex.position
   minimum_y=minf(minimum_y,(reference[pointer]*Vector3(p[0],p[1],p[2])).y)
 source_offset=Vector3(0,-minimum_y*source_scale,0)
 skeleton=Skeleton3D.new();skeleton.name='NativeEquipmentSkeleton';rig_visual.add_child(skeleton)
 for bone in NativePose.PTR:
  skeleton.add_bone(bone);var index=skeleton.get_bone_count()-1;native_bones[bone]=index
  var native:Transform3D=reference[NativePose.PTR[bone]]
  skeleton.set_bone_rest(index,Transform3D(native.basis,native.origin*source_scale+source_offset))
 robe_skeleton=Skeleton3D.new();robe_skeleton.name='SasukeCapeSkeleton';body.add_child(robe_skeleton);robe_skeleton.add_bone('Chest')
 robe_skeleton.set_bone_rest(0,_cape_pose(skeleton.get_bone_rest(native_bones.Chest)))
 # Compatibility pivots carry no substitute equipment geometry.
 pipe=Node3D.new();pipe.name='NativeKunaiEquipment';rig_visual.add_child(pipe)
 coin=Node3D.new();rig_visual.add_child(coin);coin.hide()
 chain_pipe=ChainPipeVisual.new();rig_visual.add_child(chain_pipe);chain_pipe.hide()
 locomotion=NativeLocomotion.new(self);process_priority=30
 apply_native_pose(0,0)
func cape_skeleton()->Skeleton3D:return robe_skeleton
func _cape_pose(pose:Transform3D)->Transform3D:
 return rig_visual.transform*pose*rig_visual.transform.affine_inverse()
func reach_scale()->float:
 if not is_instance_valid(combat):return 1.0
 if combat.has_method('reach_scale'):return float(combat.reach_scale())
 var actor:Variant=combat.get('hero')
 if not is_instance_valid(actor):return 1.0
 return float(actor.pickup_multiplier('range'))*float(actor.melee_reach_setting())
func scaled_source_pose(action_id:int,seconds:float)->Dictionary:
 var source:Dictionary=sampler.sample_source(action_id,seconds)
 var factor=reach_scale()
 if is_equal_approx(factor,1.0):return source
 var hair_action=action_id in [0x5f,0x67,0x6f,0x9a]
 var pointers:Array=['0x9004918','0x90063d8'] if hair_action else KUNAI
 for pointer in pointers:
  if not source.has(pointer):continue
  var native:Transform3D=source[pointer]
  var anchor:Vector3=source['0x90063d8'].origin if hair_action else native.origin
  source[pointer]=Transform3D(native.basis.scaled(Vector3.ONE*factor),anchor+(native.origin-anchor)*factor)
 return source
func apply_native_pose(action_id:int,seconds:float):
 var source:Dictionary=scaled_source_pose(action_id,seconds)
 if source.is_empty():return
 source_action=action_id;source_time=seconds
 NativeBody.set_face(native_parts,action_id,seconds)
 for pointer in native_parts:
  var part:Node3D=native_parts[pointer]
  part.visible=source.has(pointer)
  if not part.visible:continue
  var native:Transform3D=source[pointer]
  part.transform=Transform3D(native.basis.scaled(Vector3.ONE*source_scale),native.origin*source_scale+source_offset)
  part.visible=absf(native.basis.determinant())>.00000001
 for bone in NativePose.PTR:
  var pointer:String=NativePose.PTR[bone]
  if source.has(pointer):
   var native:Transform3D=source[pointer]
   if absf(native.basis.determinant())>.00000001:skeleton.set_bone_global_pose(native_bones[bone],Transform3D(native.basis,native.origin*source_scale+source_offset))
 robe_skeleton.set_bone_global_pose(0,_cape_pose(skeleton.get_bone_global_pose(native_bones.Chest)))
func weapon_segments(action_id:int,seconds:float)->Array:
 var source:Dictionary=scaled_source_pose(action_id,seconds);var result:Array=[]
 var hair_action=action_id in [0x5f,0x67,0x6f,0x9a]
 var pointers:Array=['0x9004918','0x90063d8'] if hair_action else KUNAI
 for pointer in pointers:
  if not source.has(pointer):continue
  var native:Transform3D=source[pointer]
  if absf(native.basis.determinant())<.00000001:continue
  var base=Vector3.ZERO;var tip=Vector3(0,-44,0)
  if pointer=='0x9004918':base=Vector3(0,28,-21);tip=Vector3(0,78,-114)
  elif pointer=='0x90063d8':base=Vector3(0,0,1);tip=Vector3(2.5,5,1)
  base=rig_visual.transform*((native*base)*source_scale+source_offset)
  tip=rig_visual.transform*((native*tip)*source_scale+source_offset)
  result.append({'pointer':pointer,'base':base,'tip':tip})
 return result
func blade_endpoints(action_id:int,seconds:float)->Array:return weapon_segments(action_id,seconds)
func combat_pose(_attack:float,_heavy:bool,_combo:int,_dodge:bool):
 pipe_combo_pose={}
func set_surge(_active:bool):pass
func apply_skin(_id:String):skin_id=HeroSkins.DEFAULT_ID
func create_projectile_visual(kind:String)->Node3D:
 return NativeBody.create_projectile(kind,source_scale)
