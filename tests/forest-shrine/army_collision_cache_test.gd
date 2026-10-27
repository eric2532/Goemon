extends SceneTree
var checks=0
func check(ok:bool,label_:String):
 checks+=1
 assert(ok,label_)
func _initialize():run.call_deferred()
func run():
 var runtime=preload("res://scripts/forest/crowd/army_runtime.gd").new()
 var world=Node3D.new();root.add_child(world)
 var body=StaticBody3D.new();world.add_child(body)
 var node=CollisionShape3D.new();var shape=ConcavePolygonShape3D.new()
 var faces=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.BACK])
 shape.set_faces(faces);node.shape=shape;body.add_child(node)
 var first=runtime.static_collision_data(world)
 check(first.faces==faces and first.owners==PackedInt64Array([-1]),"Cold export preserves face order and ownership")
 var cached=runtime.static_collision_cache[node.get_instance_id()]
 check(runtime.static_collision_data(world)==first and runtime.static_collision_cache[node.get_instance_id()]==cached,"Warm export reuses the prepared record")
 body.position=Vector3(3,2,1)
 check(runtime.static_collision_data(world).faces==PackedVector3Array([Vector3(3,2,1),Vector3(4,2,1),Vector3(3,2,2)]),"Moved collider invalidates the world transform")
 faces[1]=Vector3(4,0,0);shape.set_faces(faces)
 check(runtime.static_collision_data(world).faces[1]==Vector3(7,2,1),"In-place shape edits invalidate cached vertices")
 var second=CollisionShape3D.new();second.shape=shape;second.position=Vector3.UP*4;body.add_child(second)
 check(runtime.static_collision_data(world).faces.size()==6,"Shared shape keeps distinct world transforms")
 node.disabled=true
 check(runtime.static_collision_data(world).faces.size()==3 and runtime.static_collision_cache.size()==1,"Disabled colliders are excluded and pruned")
 body.collision_layer=2
 check(runtime.static_collision_data(world).faces.is_empty() and runtime.static_collision_cache.is_empty(),"Physics layer changes retire old records")
 body.collision_layer=1;second.queue_free()
 check(runtime.static_collision_data(world).faces.is_empty(),"Queued collider deletion cannot retain stale collision")
 node.disabled=false;body.position=Vector3.ZERO
 var castle=Node3D.new();castle.set_meta("army_collision_owner",castle.get_instance_id());world.add_child(castle);world.move_child(castle,0)
 var wall=StaticBody3D.new();castle.add_child(wall)
 var panel=CollisionShape3D.new();panel.shape=BoxShape3D.new();panel.position=Vector3(0,4,0);wall.add_child(panel)
 var intact=runtime.static_collision_data(world)
 check(intact.faces.slice(0,3)==faces and intact.owners[0]==-1,"Scenery remains the stable prefix even when a castle precedes it in the scene")
 check(intact.owners.slice(1).count(castle.get_instance_id())==12,"Castle collision has its own mutable owner")
 wall.collision_layer=0
 var breached=runtime.static_collision_data(world)
 check(breached.faces==faces and breached.owners==PackedInt64Array([-1]),"Breach removes only castle faces and leaves the scenery prefix unchanged")
 wall.collision_layer=1
 check(runtime.static_collision_data(world)==intact,"Restored collision retains exact geometry and ownership")
 panel.shape.size=Vector3(2,3,4)
 var resized=runtime.static_collision_data(world)
 check(resized.faces!=intact.faces and runtime.static_collision_cache[panel.get_instance_id()].box_size==Vector3(2,3,4),"In-place box resizing invalidates prepared geometry")
 runtime.clear();check(runtime.static_collision_cache.is_empty(),"Army clear releases cached arrays")
 world.queue_free();runtime.free();await process_frame
 print("ARMY_COLLISION_CACHE_RESULT checks=",checks," failures=0");quit()
