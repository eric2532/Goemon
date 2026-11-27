extends SceneTree
## Isolated setup-array preservation. No shared master or runtime publication.
const Original=preload("res://build/Other Files/Asset Toolkit/East Gate Region/Bank Caps/Fort CPU Candidate/fort_parts_before.gd")
const Candidate=preload("res://build/Other Files/Asset Toolkit/East Gate Region/Bank Caps/Fort CPU Candidate/fort_parts_candidate.gd")
const Live=preload("res://scripts/forest/forest_falan_fort_parts.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Bank Caps/Fort CPU Candidate/"
var checks=0
var failures=0
var observations=[]

func _initialize():
 create_timer(300,true,false,true).timeout.connect(func():printerr("FORT_CPU_ARRAYS_TIMEOUT");quit(2))
 run.call_deferred()

func check(okay:bool,label:String):
 checks+=1
 if not okay:failures+=1;printerr("FORT_CPU_ARRAYS_FAIL ",label)

func difference(a:Variant,b:Variant)->float:
 if a==null or b==null:return 0. if a==b else INF
 if a.size()!=b.size():return INF
 var maximum=0.
 for i in a.size():
  if a[i] is Vector3 or a[i] is Vector2:maximum=maxf(maximum,a[i].distance_to(b[i]))
  elif a[i] is Color:
   for channel in 4:maximum=maxf(maximum,absf(a[i][channel]-b[i][channel]))
  elif a[i] is float:maximum=maxf(maximum,absf(a[i]-b[i]))
  elif a[i]!=b[i]:return INF
 return maximum

func arrays_equal(a:Array,b:Array,label:String)->Dictionary:
 var changes={};check(a.size()==b.size(),label+" array channel count")
 for slot in mini(a.size(),b.size()):
  var error=difference(a[slot],b[slot]);changes[str(slot)]=error
  check(error==0.,label+" exact channel"+str(slot)+" error="+str(error))
 return changes

func compare_mesh(a:Mesh,b:Mesh,label:String,retained:bool=true):
 check(a.get_surface_count()==b.get_surface_count(),label+" surface count")
 check(a.get_aabb()==b.get_aabb(),label+" exact source bounds")
 var captured=[]
 for slot in mini(a.get_surface_count(),b.get_surface_count()):
  var original=a.surface_get_arrays(slot);var actual=b.surface_get_arrays(slot)
  captured.append(arrays_equal(original,actual,label+" surface"+str(slot)))
  if retained:
   var cpu:Array=b.get_meta("source_surface_arrays_all")[slot] if b.has_meta("source_surface_arrays_all") else b.get_meta("source_surface_arrays")
   arrays_equal(actual,cpu,label+" retained CPU"+str(slot))
  var am=a.surface_get_material(slot);var bm=b.surface_get_material(slot)
  check((am==null)==(bm==null),label+" material presence")
  if am is ShaderMaterial and bm is ShaderMaterial:
   check(am.shader==bm.shader,label+" shader owner")
   for uniform in am.shader.get_shader_uniform_list():
    var name_:String=uniform.name
    check(am.get_shader_parameter(name_)==bm.get_shader_parameter(name_),label+" exact material parameter "+name_)
 for key in ["falan_crown_points","falan_crown_feet","falan_crown_vertices","falan_wall_slab_volume","falan_iron_spikes","falan_iron_tips","falan_gate_beam","falan_gate_detail_planes"]:
  check(a.has_meta(key)==b.has_meta(key),label+" metadata presence "+key)
  if a.has_meta(key) and b.has_meta(key):check(a.get_meta(key)==b.get_meta(key),label+" original gameplay/fit metadata "+key)
 observations.append({"part":label,"surfaces":a.get_surface_count(),"bounds":str(a.get_aabb()),"maximum_channel_differences":captured})

func run():
 var before=Fresh.snapshot([get_script().resource_path,"scripts/forest/forest_falan_fort_parts.gd",OUT+"fort_parts_candidate.gd",OUT+"fort_parts_before.gd","scripts/forest/forest_coastal_mesh.gd","scripts/forest/forest_falan_building_shapes.gd","scripts/forest/forest_falan_proportions.gd","scripts/forest/forest_wind_meadow_assets.gd","tools/prepare_east_fort_cpu_candidate.py"])
 var contract:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"source-contract.json"))
 check(FileAccess.get_sha256(OUT+"fort_parts_before.gd")==contract.shared_sha256,"Frozen prepublication original matches the historical proof master")
 check(FileAccess.get_sha256("res://scripts/forest/forest_falan_fort_parts.gd")==contract.candidate_sha256,"Live publication is the exact reviewed candidate")
 compare_mesh(Original.merlon(),Candidate.merlon(),"full_merlon")
 compare_mesh(Original.merlon(true),Candidate.merlon(true),"narrow_merlon")
 compare_mesh(Original.merlon(),Live.merlon(),"live_full_merlon")
 compare_mesh(Original.merlon(true),Live.merlon(true),"live_narrow_merlon")
 var merlon_bytes=var_to_bytes(Candidate.merlon().get_meta("source_surface_arrays"))
 for serial in Original.Data.PARTS:
  var old=Original.raw(int(serial));var candidate=Candidate.raw(int(serial))
  compare_mesh(old,candidate,"raw_"+str(serial))
  compare_mesh(Original.prepare(int(serial)),Candidate.prepare(int(serial)),"prepared_"+str(serial),false)
  compare_mesh(old,Live.raw(int(serial)),"live_raw_"+str(serial))
  compare_mesh(Original.prepare(int(serial)),Live.prepare(int(serial)),"live_prepared_"+str(serial),false)
 check(var_to_bytes(Candidate.merlon().get_meta("source_surface_arrays"))==merlon_bytes,"Repeated raw preparation leaves shared CPU merlon arrays unchanged")
 var changed=Fresh.changed(before);check(changed.is_empty(),"Loaded original and private candidate sources remain current")
 var file=FileAccess.open(OUT+"live-array-proof.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"source_hashes":before,"source_changed_during_run":changed,"cpu_array_accesses":Candidate.cpu_stats,"live_cpu_array_accesses":Live.cpu_stats,"scope":"Published live/candidate replay against SHA-pinned frozen prepublication master. All source geometry, packed channel values, fit metadata, material values and textures remain exact. Independent detail builders and primitive/imported meshes keep counted fallback reads. No rendered-performance acceptance."},"  "));file.close()
 print("EAST_FORT_CPU_ARRAYS_RESULT checks=",checks," failures=",failures," stats=",Candidate.cpu_stats);quit(1 if failures else 0)
