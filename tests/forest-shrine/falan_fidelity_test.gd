extends "res://tests/forest-shrine/falan_proportion_preview.gd"
const Benches=preload("res://scripts/forest/forest_falan_benches.gd")
const Lamps=preload("res://scripts/forest/forest_falan_lamps.gd")
const Street=preload("res://scripts/forest/forest_falan_street_details.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Falan Fidelity Implementation/"
var checks=0
var baseline=false
var folder:String
func review_folder()->String:return REVIEW

func _initialize():
 baseline="--baseline" in OS.get_cmdline_user_args()
 folder=review_folder()+("Before/" if baseline else "After/")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 create_timer(180).timeout.connect(func():printerr("FALAN_FIDELITY_TIMEOUT");quit(1))
 run.call_deferred()

func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FALAN_FIDELITY_FAIL "+message)

func run():
 root.size=Vector2i(900,900)
 stage=Node3D.new();root.add_child(stage)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("596b64")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8;stage.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-35,0);stage.add_child(light)
 camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT
 for serial in [10079,10078,10083]:
  var model=MeshInstance3D.new();model.mesh=Architecture.prepare(serial);model.rotation.y=PI*.5;stage.add_child(model)
  check(is_same(model.mesh,Architecture.prepare(serial)),"Repeated houses reuse their mesh")
  if not baseline:
   var paint:ShaderMaterial=model.mesh.surface_get_material(1)
   check(paint.get_shader_parameter("use_base_texture")==true and paint.get_shader_parameter("base_texture")==Architecture.Atlas,"Roof retains recovered slate paint")
   var tiles:PackedVector2Array=model.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
   if serial in [10079,10078]:check(tiles.has(Architecture.HouseParts.Data.TILES.shop_medallion),"Colored shop retains its original gable ornament")
   check(tiles.has(Architecture.HouseParts.Data.TILES.shop_shield)==(serial==10079),"Armor shield stays on the matching green shop family")
   if serial==10079:
    var raw=Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO)*Fit.Data.FITS["house_10079"]*Transform3D(Basis(Vector3.UP,-PI*.5),Vector3.ZERO)
    check(Fit.project(raw*Architecture.HouseParts.GREEN_SHIELD_CENTER).distance_to(Fit.References.RECTS["house_10079"].position+Vector2(258,186))<2.0,"Shield anchor matches its original source pixel station")
  await capture(model,"house_%d"%serial,Fit.mesh_points(model.mesh))
 var spec:Array=Civic.SHELLS[Vector2i(-12,-44)]
 Civic.build(stage,Vector3.ZERO,spec)
 var bank:Node3D=stage.get_children()[-1];bank.position=Vector3.ZERO
 if not baseline:
  for original in Civic.bank_paints:
   check(original.get_shader_parameter("weathered_masonry")!=true,"Bank weathering leaves shared source materials unchanged")
   check(Civic.bank_paints[original].get_shader_parameter("weathered_masonry")==true,"Bank owns its cached weathering material")
 await capture(bank,"civic_1121",Fit.node_points(bank))
 var street=Node3D.new();stage.add_child(street)
 Lamps.batch(street,10422,[Transform3D(Basis.IDENTITY,Vector3(-3,0,0))])
 if not baseline:check(Lamps.meshes[10422].get_aabb().end.y>6.80 and Lamps.meshes[10422].get_surface_count()==3,"Native double-arm lamp retains its tall finial and separate globe glass")
 Benches.batch(street,10405,[Transform3D(Basis(Vector3.UP,Benches.yaw(10405)),Vector3.ZERO)])
 Street.batch(street,10426,[Transform3D(Basis.IDENTITY,Vector3(3,0,0))])
 var bench:Mesh=Benches.meshes[true];var bounds=bench.get_aabb()
 check(bounds.size.x<=1.371 and bounds.size.z<=.841 and bounds.end.y<=1.70,"Bench keeps its source footprint")
 if not baseline:
  check((Basis(Vector3.UP,Benches.yaw(10405))*Vector3.FORWARD).dot(Vector3.RIGHT)>.99,"Source 10405 shows its open seat toward the original camera")
  check(Benches.wood==bench.surface_get_material(0),"Benches share one prepared wood material")
 check(is_same(Street.prepare(10426),Street.prepare(10426)) and is_same(Street.foliage(10426),Street.foliage(10426)),"Planter and foliage reuse prepared meshes")
 camera.size=10.4;camera.position=Vector3(10,11.34,12);camera.look_at(Vector3(0,2.7,0))
 await shot("street-native")
 street.queue_free();await process_frame
 var report=FileAccess.open(folder+"verification.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures,"baseline":baseline},"  "));report.close()
 print("FALAN_FIDELITY_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)

func capture(model:Node3D,key:String,points:Array[Vector3]):
 var rect:Rect2=Fit.References.RECTS[key]
 var measured=Fit.projected_bounds(points,Transform3D(model.basis,Vector3.ZERO))
 check(measured.position.distance_to(rect.position)<.05 and measured.size.distance_to(rect.size)<.05,"Original source dimensions and anchor: "+key)
 var center=rect.get_center();var at=Vector3((center.x/Fit.HORIZONTAL+center.y/Fit.FLOOR)*.5,0,(center.y/Fit.FLOOR-center.x/Fit.HORIZONTAL)*.5)
 camera.size=rect.size.y*1.2/(sqrt(2.0)*Fit.HORIZONTAL)
 camera.position=at+Vector3(100,100*sqrt(2.0)*tan(asin(.75)),100);camera.look_at(at)
 await shot(key+"-native")
 var bounds=AABB(model.basis*points[0],Vector3.ZERO)
 for p in points:bounds=bounds.expand(model.basis*p)
 var target=bounds.get_center()
 camera.size=maxf(bounds.size.x+bounds.size.z,bounds.size.y*1.7)*1.05
 for row in [["gameplay",Vector3(65,30,65)],["reverse",Vector3(-65,30,-65)]]:
  camera.position=target+row[1];camera.look_at(target);await shot(key+"-"+row[0])
 model.queue_free();await process_frame

func shot(name_:String):
 if DisplayServer.get_name()=="headless":return
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(folder+name_+".png")==OK,"Rendered "+name_)
