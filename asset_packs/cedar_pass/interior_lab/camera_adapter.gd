# Interior-only extension; the repository ActionCamera implementation remains unchanged.
extends ActionCamera
var interior_active := false
var indoor_distance := 8.0
func _process(delta):
 super._process(delta)
 if not interior_active:return
 # Reuse actual yaw, smoothed follow target, FOV and input. An elevated interior
 # boom ignores only surfaces the cutaway has hidden, via camera layer 8.
 var p = clampf(pitch, .74, 1.1)
 var offset = Vector3(sin(yaw)*cos(p),sin(p),cos(yaw)*cos(p))
 var safe = 8.0
 for probe in [Vector3.ZERO,Vector3(.24,0,0),Vector3(-.24,0,0),Vector3(0,.22,0)]:
  var hit = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(follow+probe,follow+offset*8+probe,8))
  if not hit.is_empty():safe=minf(safe,maxf(.7,follow.distance_to(hit.position)-.35))
 indoor_distance=lerpf(indoor_distance,safe,1-exp(-delta*(30 if safe<indoor_distance else 7)))
 indoor_distance=minf(indoor_distance,safe+.05)
 camera.global_position=follow+offset*indoor_distance
 camera.look_at(follow,Vector3.UP)
