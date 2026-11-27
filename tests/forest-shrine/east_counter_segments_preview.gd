extends "res://tests/forest-shrine/east_hourglass_preview.gd"
## Review modules assembled at their actual33514source cells before any hook.
const Counters=preload("res://scripts/forest/forest_east_counter_segments.gd")
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
func minimum_study_height()->float:return 1.9
func run():
 var paths=[get_script().resource_path,"tests/forest-shrine/east_hourglass_preview.gd","scripts/forest/forest_east_counter_segments.gd","scripts/forest/forest_east_counter_front.gdshader",Counters.ROOT+"data.json","assets/maps/original_crossgate/east/catalog.json"]
 for serial in Counters.IDS:paths.append(Counters.ROOT+str(serial)+".png")
 var hashes=Sources.snapshot(paths)
 root.size=Vector2i(1440,900);root.title="Cross Gate · Connected Counter Study"
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("243039");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("dae4e3");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.;stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=55
 Art.load_east();var row=Maps.state(Maps.runtime_id(33514));var cells:int=row.size.x*row.size.y;var group=Node3D.new();stage.add_child(group);var count_=0
 for i in cells:
  var serial=int(row.raw.decode_u16(20+(cells+i)*2))
  if serial not in Counters.IDS:continue
  var node=MeshInstance3D.new();node.mesh=Counters.mesh(serial,Art.data().graphics[str(serial)]);node.position=Vector3((i%row.size.x-20)*3.,0,(i/row.size.x-9)*3.);group.add_child(node);count_+=1
 check(count_>20,"Connected original counter placements retained")
 var mesh=preload("res://scripts/forest/forest_east_region_art.gd").reusable_node_mesh(group);group.free()
 var output="res://build/Other Files/Asset Toolkit/East Gate Region/Counter Segments/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 #Inherited study writes under Hourglass Studies; move only these owned captures.
 await study(stage,camera,mesh,"connected-native-counter-33514",mesh.get_aabb())
 for corner:Vector2i in[Vector2i(20,9),Vector2i(20,18)]:
  var local=Node3D.new();stage.add_child(local)
  for i in cells:
   var cell=Vector2i(i%row.size.x,i/row.size.x)
   if absi(cell.x-corner.x)>1 or absi(cell.y-corner.y)>1:continue
   var serial=int(row.raw.decode_u16(20+(cells+i)*2))
   if serial not in Counters.IDS:continue
   var node=MeshInstance3D.new();node.mesh=Counters.mesh(serial,Art.data().graphics[str(serial)]);node.position=Vector3((cell.x-corner.x)*3.,0,(cell.y-corner.y)*3.);local.add_child(node)
  var detail=preload("res://scripts/forest/forest_east_region_art.gd").reusable_node_mesh(local);local.free()
  await study(stage,camera,detail,"counter-joint-%d-%d"%[corner.x,corner.y],detail.get_aabb())
 for name in captures:DirAccess.rename_absolute(OUT+name,output+name)
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Counter references remain current")
 var file=FileAccess.open(output+"preview.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_placements":count_,"observations":observations,"captures":captures,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Private assembled source counter at3m tile spacing; no map hook.17197concave/17202outercorner silhouette and isolated ends still require visual judgment."},"  "));file.close();print("EAST_COUNTER_SEGMENTS_PREVIEW_RESULT checks=",checks," failures=",failures);quit(failures)
