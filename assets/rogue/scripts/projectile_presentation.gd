extends RefCounted
## Army flight keeps a logical pose at the native physics rate. Only draw
## submission waits for the displayed frame; human shots continue using nodes.
static func begin(pr:Dictionary)->void:
 if not pr.has("visual_lease"):pr.visual_lease=pr.mesh.get_meta("army_projectile_generation",-1)
 if not pr.get("deferPresentation",false) or pr.has("presentation"):return
 pr.presentation={"transform":pr.mesh.transform,"materials":pr.mesh.get_meta("ink_materials",[]),"frame":-1,"dirty":false,"lease":pr.mesh.get_meta("army_projectile_generation",-1)}
static func position_of(pr:Dictionary)->Vector3:
 return pr.presentation.transform.origin if pr.has("presentation") else pr.mesh.position
static func set_position(pr:Dictionary,value:Vector3)->void:
 if pr.has("presentation"):
  var pose:Transform3D=pr.presentation.transform;pose.origin=value;pr.presentation.transform=pose;pr.presentation.dirty=true
 else:pr.mesh.position=value
static func set_quaternion(pr:Dictionary,value:Quaternion)->void:
 if pr.has("presentation"):
  var pose:Transform3D=pr.presentation.transform;pose.basis=Basis(value).scaled(pose.basis.get_scale());pr.presentation.transform=pose;pr.presentation.dirty=true
 else:pr.mesh.quaternion=value
static func rotate_local(pr:Dictionary,axis:Vector3,angle:float)->void:
 if pr.has("presentation"):
  var pose:Transform3D=pr.presentation.transform;pose.basis=pose.basis*Basis(axis,angle);pr.presentation.transform=pose;pr.presentation.dirty=true
 else:pr.mesh.rotate_object_local(axis,angle)
static func basis_of(pr:Dictionary)->Basis:
 return pr.presentation.transform.basis if pr.has("presentation") else pr.mesh.basis
static func present(pr:Dictionary)->void:
 if not pr.has("presentation") or not is_instance_valid(pr.mesh) or pr.mesh.is_queued_for_deletion():return
 var draw:Dictionary=pr.presentation
 if draw.get("lease",-1)!=pr.mesh.get_meta("army_projectile_generation",-1) or pr.mesh.get_meta("army_projectile_parked",false):return
 if not draw.dirty or draw.frame==Engine.get_process_frames():return
 draw.frame=Engine.get_process_frames();draw.dirty=false
 pr.mesh.transform=draw.transform
 for material in draw.materials:material.set_shader_parameter("brush_clock",pr.get("inkClock",0.0))
static func release(pr:Dictionary)->void:
 if not is_instance_valid(pr.mesh):return
 preload("res://scripts/character_projectile_pool.gd").retire_visual(pr.mesh,pr.get("visual_lease",pr.presentation.get("lease",-1) if pr.has("presentation") else -1))
