extends SceneTree
var failures=0
var checks=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func run():
 var trail=load('res://scripts/recovered_musashi_trail.gd').new();root.add_child(trail)
 trail.begin_action('fusion_1')
 check(trail.delay_ticks==2,'original Fusion delay')
 check(trail.record_ticks==6,'original Fusion duration')
 var pair=PackedVector3Array([Vector3(1,2,3),Vector3(0,2,3)])
 for i in 2:trail.source_tick(pair,.054)
 check(trail.samples.size()==1,'seed after wait without premature ribbon')
 trail.source_tick(pair,.054)
 check(trail.samples.size()==3,'two pairs per source update even without movement')
 check(trail.mesh!=null,'source ribbon rendered')
 var colors=trail.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
 check(colors[0].is_equal_approx(Color(122/255.0,122/255.0,244/255.0)),'literal original blue RGB')
 var snapshot=trail.samples[0].duplicate()
 pair[0]+=Vector3(100,0,0);trail.source_tick(pair,.054)
 check(trail.samples[0]==snapshot,'old samples stay in world space')
 for i in 50:trail.source_tick(pair,.054)
 check(trail.mesh==null and trail.samples.is_empty(),'original fade ends')
 trail.begin_action('lumina');check(trail.weapon=='lumina' and trail.delay_ticks==2 and trail.record_ticks==11,'red Lumina descriptor')
 for i in 3:trail.source_tick(pair,.054)
 colors=trail.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
 check(colors[0].is_equal_approx(Color(244/255.0,122/255.0,122/255.0)),'literal original red RGB')
 trail.source_tick(pair,.054,false)
 colors=trail.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
 check(colors[0].is_equal_approx(Color(228/255.0,114/255.0,114/255.0)),'native half-brightness color during fade')
 trail.begin_action('fusion_1')
 check(trail.fading_trails.size()==1,'separate Lumina trail survives Fusion initialization')
 trail.clear();check(trail.mesh==null and trail.action.is_empty() and trail.fading_trails.is_empty(),'cancel clears all emission')
 trail.begin_action('fusion_4')
 for i in 20:trail.source_tick(pair,.054)
 check(trail.samples.size()==16,'native sixteen-pair ring capacity')
 check(trail.trail_material.shader.code.contains('blend_add'),'native additive material')
 print('MUSASHI_SWORD_VFX_TEST checks=',checks,' failures=',failures)
 trail.queue_free();await process_frame;quit(1 if failures else 0)
