extends RefCounted
## One typed, read-only view per physics snapshot. Packed buffers remain shared
## with the renderer and old views stay valid for lazy combat contact queries.
var handles:PackedInt64Array
var rows_by_slot:PackedInt32Array
var logical_ids:PackedInt64Array
var teams:PackedByteArray
var positions:PackedVector3Array
var velocities:PackedVector3Array
var pose_velocities:PackedVector3Array
var yaw:PackedFloat32Array
var hp:PackedFloat64Array
var max_hp:PackedFloat64Array
var ages:PackedFloat64Array
var shelter_modes:PackedInt32Array
var status:PackedInt32Array
var pose_time:PackedFloat32Array
var action_time:PackedFloat32Array
var pose_rows:PackedInt32Array
var actions:PackedInt32Array
var stun_left:PackedFloat32Array
var walk_phase:PackedFloat32Array
func _init(data:Dictionary):
 handles=data.get("handles",PackedInt64Array());rows_by_slot=data.get("rows_by_slot",PackedInt32Array())
 logical_ids=data.logical_ids
 teams=data.teams
 positions=data.positions
 velocities=data.velocities
 pose_velocities=data.pose_velocities
 yaw=data.yaw
 hp=data.hp
 max_hp=data.max_hp
 ages=data.ages
 shelter_modes=data.shelter_modes
 status=data.status
 pose_time=data.pose_time
 action_time=data.action_time
 pose_rows=data.pose_rows
 actions=data.actions
 stun_left=data.stun_left
 walk_phase=data.walk_phase
