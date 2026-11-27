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
 if not baseline:
  var targets={10003:[["native_house_sign",Vector2(29,235),16]],10005:[["native_baker_sign",Vector2(74,229.5),58],["native_house_sign",Vector2(31,235),16]],10049:[["native_bar_sign",Vector2(81.5,193.5),57],["native_house_sign",Vector2(173,325),17]],10050:[["native_bar_sign",Vector2(297,192),58]],10078:[["native_weapon_sign",Vector2(259,206),48]],10080:[["native_inn_sign",Vector2(273,172),52]],10306:[["native_house_sign",Vector2(29,224),16]]}
  for serial in targets:
   var mesh:Mesh=Architecture.prepare(serial);var a=mesh.surface_get_arrays(0)
   for target in targets[serial]:
    var tile:Vector2=Architecture.HouseParts.Data.TILES[target[0]];var pixels=[]
    for i in a[Mesh.ARRAY_VERTEX].size():
     if a[Mesh.ARRAY_TEX_UV2][i]==tile:pixels.append(Fit.project(Basis(Vector3.UP,PI*.5)*a[Mesh.ARRAY_VERTEX][i])-Fit.References.RECTS["house_%d"%serial].position)
    check(pixels.size()==6,"Native plaque has one independent panel: %d %s"%[serial,target[0]])
    if pixels.size()!=6:continue
    var center=Vector2.ZERO;var low=INF;var high=-INF
    for pixel:Vector2 in pixels:center+=pixel;low=minf(low,pixel.x);high=maxf(high,pixel.x)
    check((center/6).distance_to(target[1])<2.0,"Plaque follows original pixel station: %d %s"%[serial,target[0]])
    var visible_fraction=48.0/112.0 if target[0]=="native_house_sign" else 1.0
    check(absf((high-low)*visible_fraction-target[2])<1.0,"Plaque width follows original art: %d %s"%[serial,target[0]])
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
    var vertices:PackedVector3Array=model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var center=Vector3.ZERO;var count=0
    for i in tiles.size():
     if tiles[i]==Architecture.HouseParts.Data.TILES.shop_shield:center+=vertices[i];count+=1
    check(count>0,"Native shield has its own facade feature")
    if count>0:
     center/=count
     var row:Array=Architecture.Data.GRAPHICS[serial]
     var pixel=Fit.project(Basis(Vector3.UP,PI*.5)*center)-Fit.References.RECTS["house_10079"].position
     check(pixel.distance_to(Vector2(258,186))<2.0,"Shield anchor follows its original source pixel station")
  await capture(model,"house_%d"%serial,Fit.mesh_points(model.mesh))
 if not baseline:
  Civic.build(stage,Vector3.ZERO,Civic.SHELLS[Vector2i(1,-35)])
  var inn:Node3D=stage.get_children()[-1];inn.position=Vector3.ZERO
  for row in [["inn_sign",Vector2(142.5,169.5),Vector2(75,49),Vector2(0,58)],["inn_side_sign",Vector2(316.5,242),Vector2(67,-42),Vector2(0,48)]]:
   var panel:Node3D=inn.find_child("Recovered_"+row[0],true,false)
   check(panel!=null,"Inn retains its original independent plaque: "+row[0])
   if panel==null:continue
   var pose=inn.global_transform.affine_inverse()*panel.global_transform
   var center=Fit.project(pose.origin)-Fit.References.RECTS.civic_1101.position
   var across=Fit.project(pose*Vector3(.5,0,0))-Fit.project(pose*Vector3(-.5,0,0))
   var down=Fit.project(pose*Vector3(0,-.5,0))-Fit.project(pose*Vector3(0,.5,0))
   check(center.distance_to(row[1])<1.0,"Inn plaque centre matches original art: "+row[0])
   check(across.distance_to(row[2])<1.0 and down.distance_to(row[3])<1.0,"Inn plaque corners match original art: "+row[0])
  inn.queue_free();await process_frame
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
