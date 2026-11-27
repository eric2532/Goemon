extends SceneTree
const Walls=preload("res://scripts/forest/forest_kili_art.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Sokia full-source outdoors/"
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("SOKIA_WALL_CPU_FAIL ",label_)
func _initialize():
 create_timer(90).timeout.connect(func():printerr("SOKIA_WALL_CPU_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 var before="--before-wall"in OS.get_cmdline_user_args();var rows=[]
 var folder=REVIEW+"Before native walls/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 for serial in range(11230,11251):
  var mesh:Mesh=Walls.recovered_wall(serial);var path=folder+str(serial)+".res"
  if before:
   check(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK,"Reference saved "+str(serial));continue
  var old:Mesh=load(path);var a:Array=mesh.surface_get_arrays(0);var b:Array=old.surface_get_arrays(0)
  check(a[Mesh.ARRAY_VERTEX].size()==b[Mesh.ARRAY_VERTEX].size(),"Vertex count "+str(serial))
  var delta={"vertices":0.,"normals":0.,"uv":0.}
  for i in a[Mesh.ARRAY_VERTEX].size():
   delta.vertices=maxf(delta.vertices,a[Mesh.ARRAY_VERTEX][i].distance_to(b[Mesh.ARRAY_VERTEX][i]))
   delta.normals=maxf(delta.normals,a[Mesh.ARRAY_NORMAL][i].distance_to(b[Mesh.ARRAY_NORMAL][i]))
   delta.uv=maxf(delta.uv,a[Mesh.ARRAY_TEX_UV][i].distance_to(b[Mesh.ARRAY_TEX_UV][i]))
  check(delta.vertices==0. and delta.normals<.0001 and delta.uv<.0001,"Original geometry and paint density "+str(serial))
  var material:ShaderMaterial=mesh.surface_get_material(0);var reference:ShaderMaterial=old.surface_get_material(0)
  check(material.shader==reference.shader and material.get_shader_parameter("base_texture")==reference.get_shader_parameter("base_texture")and material.get_shader_parameter("atlas_tile_pixels")==reference.get_shader_parameter("atlas_tile_pixels"),"Original material and atlas "+str(serial))
  check(not mesh.has_meta("source_surface_arrays"),"Temporary CPU arrays are released "+str(serial))
  rows.append({"serial":serial,"maximum_difference":delta})
 var file=FileAccess.open(REVIEW+("before-"if before else"")+"wall-cpu-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"walls":rows},"  ")+"\n");file.close()
 print("SOKIA_WALL_CPU ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
