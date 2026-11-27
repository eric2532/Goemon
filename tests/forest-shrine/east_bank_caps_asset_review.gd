extends SceneTree
## Isolated source-cap appearance; actual terrain/player/pet evidence is separate.
const Caps=preload("res://scripts/forest/forest_east_bank_caps.gd")
const Il=preload("res://scripts/forest/forest_east_il_source_completion.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Bank Caps/Asset Review/"
var checks=0
var failures=0
var captures=[]

func _initialize():
 create_timer(240,true,false,true).timeout.connect(func():printerr("BANK_CAP_ASSET_TIMEOUT");quit(2))
 run.call_deferred()

func check(okay:bool,message:String):
 checks+=1
 if not okay:failures+=1;printerr("FAIL ",message)

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var paths=[get_script().resource_path,"scripts/forest/forest_east_bank_caps.gd","scripts/forest/forest_east_il_source_completion.gd","scripts/forest/forest_coastal_mesh.gd","assets/maps/falan/east_region/bank_caps/data.json","assets/maps/falan/east_region/bank_caps/surfaces.png","assets/maps/falan/east_region/il_source_completion/data.json"]
 for serial in [12528,12503,12527,12515,12502]:
  paths.append(Caps.ROOT+str(serial)+"-native.png");paths.append(Caps.ROOT+str(serial)+"-front.png")
 var before=Fresh.snapshot(paths)
 var viewport=SubViewport.new();viewport.size=Vector2i(720,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage=Node3D.new();viewport.add_child(stage);var world=WorldEnvironment.new();var environment=Environment.new()
 environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("27313a");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=.85;world.environment=environment;stage.add_child(world)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);stage.add_child(light)
 var node=MeshInstance3D.new();stage.add_child(node);var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
 var rows=Il.bank_placements();check(rows.size()==6,"Only six new Il source cap placements are enrolled")
 var joins=0
 for row:Dictionary in rows:
  joins+=row.join_rects.size()
  check(row.join_rects.is_empty() or row.source_dry_neighbor.dry_land,"Every full-cell seam lies on an original recorded dry neighbor")
 check(joins==4,"The two western wet-bank neighbors receive no whole-cell seam")
 for serial in [12528,12503,12527,12515,12502]:
  var mesh=Caps.mesh(serial,4.);node.mesh=mesh
  check(mesh.get_surface_count()==2,"Native paint and independent closed backing remain separate "+str(serial))
  check(mesh.has_meta("source_surface_arrays_all"),"CPU source arrays avoid renderer readback "+str(serial))
  var bounds=mesh.get_aabb();check(bounds.position.x>=-1.51 and bounds.end.x<=1.51 and bounds.position.z>=-1.51 and bounds.end.z<=1.51,"The original1x1source footprint stays exact "+str(serial))
  check(bounds.position.y< -3.99 and bounds.end.y<.01,"Only inferred hidden continuation descends to water "+str(serial))
  for angle in 2:
   node.scale.y=1./(.045*9.9777530314) if angle==0 else 1.
   var target=node.transform*mesh.get_aabb().get_center();camera.size=13. if angle==0 else 6.3
   camera.position=target+(Vector3(-1,1.603567,1) if angle==0 else Vector3(1,1.1,-1)).normalized()*60.;camera.look_at(target);camera.current=true
   for i in 6:await process_frame
   await RenderingServer.frame_post_draw
   var path=OUT+str(serial)+("-native-axis.png" if angle==0 else "-reverse.png")
   check(viewport.get_texture().get_image().save_png(path)==OK,"Captured source-cap asset "+str(serial)+" angle"+str(angle));captures.append(path)
 var changed=Fresh.changed(before);check(changed.is_empty(),"Loaded bank-cap source/materials stayed current")
 var file=FileAccess.open(OUT+"asset-review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_hashes":before,"source_changed_during_run":changed,"captures":captures,"six_new_il_placements":6,"dry_neighbor_joins":joins,"inferred":"Convex original grass lip with closed soil; hidden source-facing bank continuation descends6m land to2m water. Hidden backs use independent existing stone tiles. Water mask/walk cells remain unchanged.","scope":"Private source/reverse asset review only; actual player/native/pet approaches and ordinary reachable cameras remain required."},"  "));file.close()
 print("EAST_BANK_CAP_ASSET_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
