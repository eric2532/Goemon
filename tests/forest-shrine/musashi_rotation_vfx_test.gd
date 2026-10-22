extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func run():
 if not ResourceLoader.exists('res://scripts/recovered_musashi_rotation_effect.gd'):
  push_error('Original Rotation runtime renderer missing');quit(1);return
 var vfx=load('res://scripts/recovered_musashi_rotation_effect.gd').new();root.add_child(vfx)
 vfx.spawn(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*5.4),Vector3(4,5,6)))
 check(vfx.vortices.size()==2,'two original vortex actors')
 check(vfx.vortices[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==288,'96 ROM triangles')
 check(vfx.vortices[0].scale.y==0,'init executes without growth')
 check(vfx.shock_ring.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==72,'twelve Gouraud ring quads')
 var origin=vfx.vortices[0].global_position
 vfx.source_tick()
 check(vfx.states[0].size==Vector3(4352,512,4352),'variant0 original first growth')
 check(vfx.states[1].size==Vector3(4608,512,4608),'variant1 original first growth')
 check(vfx.states[0].yaw==113 and vfx.states[1].yaw==-113,'counter rotating source angles')
 check(vfx.ring_rgb==Vector3(224,224,176),'ring original fade')
 check(vfx.vortices[0].global_position==origin,'effect anchored at spawn')
 for i in 60:vfx.source_tick()
 check(vfx.vortices.is_empty() and vfx.shock_ring==null,'both variants and ring expire')
 vfx.spawn(Transform3D.IDENTITY);vfx.clear()
 check(vfx.vortices.is_empty() and vfx.shock_ring==null,'cancel clears effects')
 print('MUSASHI_ROTATION_VFX_TEST checks=',checks,' failures=',failures)
 vfx.queue_free();await process_frame;quit(1 if failures else 0)
