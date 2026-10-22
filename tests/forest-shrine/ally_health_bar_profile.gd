extends SceneTree
## Same native bars and fill transforms; only GPU resource identities change.
const Unit=preload("res://scripts/forest/explorer_helper_unit.gd")
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Smooth Gameplay/ally-health-native"
var bars=[]
var source
var camera
var report=[]
func _initialize():run.call_deferred()
func stage(label_:String):
 for frame in 12:await process_frame
 RenderingServer.force_draw()
 var row={"stage":label_,"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)};report.append(row);print("ALLY_HEALTH_NATIVE ",JSON.stringify(row))
 root.get_texture().get_image().save_png(OUT+"/"+label_+".png")
func run():
 if DisplayServer.get_name()=="headless":printerr("Native renderer required");quit(1);return
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1280,800);DisplayServer.window_set_size(Vector2i(1280,800))
 var world=Node3D.new();root.add_child(world)
 source=Unit.new()
 for i in 120:
  var display=Node3D.new();world.add_child(display);display.position=Vector3((i%12-5.5)*2.3,(i/12-4.5)*.65,0)
  var back=Geo.box(display,Vector3(0,0,-.02),Vector3(1.85,.22,.04),source.health_material(Color("142b2b")).duplicate())
  var fill=Geo.box(display,Vector3.ZERO,Vector3(1.7,.12,.04),source.health_material(Color("8ae1ac")).duplicate())
  var fraction=float(i%10+1)/10;fill.scale.x=fraction;fill.position.x=-.85*(1-fraction)
  for mesh in [back,fill]:
   mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   bars.append({"source":mesh,"mesh":mesh.mesh,"material":mesh.material_override})
 camera=Camera3D.new();root.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=18;camera.position=Vector3(0,0,20);camera.current=true
 await stage("native")
 for i in bars.size():
  bars[i].source.mesh=bars[i%2].mesh;bars[i].source.material_override=bars[i%2].material
 await stage("shared")
 for row in bars:row.source.mesh=row.mesh;row.source.material_override=row.material
 await stage("restored")
 var file=FileAccess.open(OUT+"/profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
 var passed=report[1].draws<report[0].draws-200 and report[2].draws==report[0].draws
 print("ALLY_HEALTH_NATIVE_RESULT passed=",passed)
 world.free();source.free();camera.free();quit(0 if passed else 1)
