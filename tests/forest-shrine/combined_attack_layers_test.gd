extends SceneTree
var checks=0
var failures=0
class Owner extends Node:
 var game={"settings":{"reduced_flashes":false}}
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func run():
 var owner=Owner.new();root.add_child(owner)
 var ben=preload("res://scripts/recovered_leader_trail.gd").new();ben.original=true;ben.opacity=.34;root.add_child(ben);ben.actor=owner
 var a=PackedVector3Array([Vector3.ZERO,Vector3(0,2,0)]);var b=PackedVector3Array([Vector3.RIGHT,Vector3(1,2,0)])
 ben.advance(0,a,true,true);ben.advance(.02,b,true,true);ben.flush_mesh()
 check(ben.material_override.blend_mode==BaseMaterial3D.BLEND_MODE_MIX,"Ben retains the original alpha-blended trail")
 var colors=ben.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
 check(Vector3(colors[-1].r,colors[-1].g,colors[-1].b).distance_to(Vector3(1,240.0/255,176.0/255))<.007 and absf(colors[-1].a-.34)<=1.0/255,"Ben retains the warm-yellow RGB and opacity")
 ben.clear();ben.sample_interval=1.0/30
 ben.advance(5,PackedVector3Array(),false,false)
 check(ben.samples.is_empty() and ben.mesh==null and ben.sample_clock>=5,"Idle waves skip geometry while retaining their sample clock")
 ben.advance(0,a,true,false)
 check(ben.samples.size()==1,"An idle wave can emit immediately on the next attack")
 ben.clear();ben.sample_interval=0;ben.lifetime=1;ben.advance(0,a,true,false)
 ben.lifetime=.01;ben.advance(0,b,true,false);ben.advance(.02,PackedVector3Array(),false,false)
 check(ben.samples.size()==1 and ben.samples[0].tip==a[1] and ben.mesh==null,"Expiry removes newer short-lived samples without discarding an older live sample")
 ben.clear();ben.lifetime=.22
 var musashi=preload("res://scripts/recovered_musashi_trail.gd").new();root.add_child(musashi);musashi.actor=owner
 for weapon in ["fusion_1","lumina"]:
  musashi.begin_action(weapon)
  for tick in 4:musashi.source_tick(a,.054)
  check(musashi.mesh!=null and musashi.original_trail.mesh!=null,"Musashi %s keeps both layers"%weapon)
  var arrays=musashi.original_trail.mesh.surface_get_arrays(0)
  var newest=musashi.samples[-1];var older=musashi.samples[-2]
  check(arrays[Mesh.ARRAY_VERTEX].slice(0,6)==PackedVector3Array([newest.outer,newest.inner,older.outer,newest.inner,older.inner,older.outer]),"Musashi restores exact original Gouraud quads")
  check(arrays[Mesh.ARRAY_COLOR][0].is_equal_approx(musashi.vertex_colors(0)[0]),"Musashi retains original weapon-specific RGB")
  owner.game.settings.reduced_flashes=true;musashi._draw()
  check(is_equal_approx(musashi.original_trail.material_override.get_shader_parameter("energy"),.42),"Musashi original layer honors reduced flashes")
  owner.game.settings.reduced_flashes=false
 musashi.clear()
 check(musashi.mesh==null and musashi.original_trail.mesh==null and musashi.fading_trails.is_empty(),"Musashi cancellation clears both layers and old weapon tails")
 var ribbon=preload("res://assets/rogue/scripts/magic_sword_brush.gd").new();root.add_child(ribbon)
 ribbon.original_brush=preload("res://assets/rogue/scripts/magic_sword_brush.gd").new();ribbon.add_child(ribbon.original_brush);ribbon.wave_scale=4
 ribbon.original_brush.material_override=preload("res://assets/rogue/scripts/ink_brush_style.gd").material(Color("65eac8"))
 for at in 3:ribbon.sample_blades([[Vector3(at,0,0),Vector3(at,8,0)]])
 check(ribbon.histories[0][-1][1]==Vector3(2,8,0) and ribbon.original_brush.histories[0][-1][1]==Vector3(2,2,0),"Original rogue brush follows compact weapon while new crescent keeps full reach")
 check(ribbon.original_brush.material_override.get_shader_parameter("ink_tint")==Color("65eac8") and not ribbon.original_brush.material_override.get_shader_parameter("strong_energy"),"Rogue original pigment keeps its own color and original shading")
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var ids=[ben.prepared_mesh.get_instance_id(),musashi.original_mesh.get_instance_id(),musashi.original_trail.material_override.get_instance_id(),ribbon.original_brush.mesh.get_instance_id()]
 for cycle in 300:
  ben.clear();ben.advance(0,a,true,true);ben.advance(.02,b,true,true);ben.flush_mesh();ben.advance(1,PackedVector3Array(),false,false)
  musashi.begin_action("fusion_1")
  for tick in 5:musashi.source_tick(a,.054)
  musashi.clear();ribbon.sample_blades([[Vector3(cycle,0,0),Vector3(cycle,8,0)]])
 check(ids==[ben.prepared_mesh.get_instance_id(),musashi.original_mesh.get_instance_id(),musashi.original_trail.material_override.get_instance_id(),ribbon.original_brush.mesh.get_instance_id()],"Nine hundred combined owner updates reuse prepared meshes and materials")
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated combined owners retain no resources")
 for path in ["res://assets/crowd/army_kit_profiles.tres","res://assets/characters/ally_crowd/11.res","res://assets/characters/ally_crowd/5.res","res://assets/characters/ally_crowd/7.res","res://assets/characters/ally_crowd/8.res","res://assets/characters/ally_crowd/10.res","res://assets/characters/ally_crowd/31.res"]:
  var baked=load(path)
  for source in baked.get_meta("source_hashes",{}):check(FileAccess.get_sha256(source)==baked.get_meta("source_hashes")[source],"Fresh baked input: "+source)
 ribbon.free();musashi.free();ben.free();owner.free()
 print("COMBINED_ATTACK_LAYERS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
