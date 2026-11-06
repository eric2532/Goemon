extends SceneTree
## Explicit authoring operation: recipes/scenes only, never touches existing masters/maps.
const Kit=preload("res://scripts/forest/forest_environment_kit.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const OUT="res://build/Other Files/Asset Toolkit/Modular Environment/"
const FIXTURE="res://tests/forest-shrine/reference/maps/forest_modular_kit.json"
const ASSEMBLIES={
 "boulder_pair":[["mossy_boulder",Vector3(-1.05,0,-.25),.8,0.0],["mossy_boulder",Vector3(1.15,0,.4),.55,1.7]],
 "river_cluster":[["res://assets/models/cedar_pass/river_rock.glb",Vector3(-1,0,0),1.0,0.0],["res://assets/models/cedar_pass/river_rock.glb",Vector3(1,0,.3),.65,2.1]],
 "fence_corner":[["res://assets/models/cedar_pass/fence.glb",Vector3(0,0,-2.83125),1.875,0.0],["res://assets/models/cedar_pass/fence.glb",Vector3(-2.83125,0,0),1.875,PI/2]]
}
func _initialize():run.call_deferred()
func owned(node:Node,owner_:Node):
 for child in node.get_children():
  child.owner=owner_
  if child.scene_file_path.is_empty():owned(child,owner_)
func save_scene(node:Node,path:String):
 owned(node,node)
 var packed=PackedScene.new();assert(packed.pack(node)==OK)
 assert(ResourceSaver.save(packed,path)==OK);node.free()
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Kit.DIR))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var report={"terrain":{},"assemblies":{}}
 for kind in Kit.TERRAIN.keys()+Kit.JUNCTIONS.keys():
  var segments=Kit.segments(kind,Vector2.ZERO)
  assert(preload("res://scripts/forest/forest_ramparts.gd").validation_error(segments).is_empty())
  var model=preload("res://scripts/forest/forest_model.gd").new();model.terrain.configure(segments)
  var world=preload("res://scripts/forest/forest_world.gd").new();world.model=model
  var image=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE);world.fog_texture=ImageTexture.create_from_image(image)
  var scene=Node3D.new();scene.name=kind.to_pascal_case();scene.set_meta("ramparts",segments)
  preload("res://scripts/forest/forest_rampart_art.gd").build(world,scene,false)
  report.terrain[kind]={"recipe":segments,"scene":Kit.DIR+kind+".tscn"}
  save_scene(scene,Kit.DIR+kind+".tscn");world.free()
 for kind in ASSEMBLIES:
  var scene=Node3D.new();scene.name=kind.to_pascal_case();var bounds=AABB();var first=true;var triangles=0;var surfaces=0
  for item in ASSEMBLIES[kind]:
   var pose=Transform3D(Basis(Vector3.UP,item[3]).scaled(Vector3.ONE*item[2]),item[1])
   var path:String=item[0] if item[0].begins_with("res://") else Assets.DIR+item[0]+".glb"
   var visual=load(GameAssets.model_path(path)).instantiate();visual.name="Part%d"%scene.get_child_count();visual.transform=pose*visual.transform;scene.add_child(visual)
   if path.begins_with("res://assets/models/cedar_pass/"):scene.set_meta("scenery_material",preload("res://assets/models/cedar_pass/shared_matte.tres"))
   for part in Assets.source(item[0]):
    var box=pose*part.transform*part.mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
    surfaces+=part.mesh.get_surface_count()
    for surface in part.mesh.get_surface_count():
     var arrays=part.mesh.surface_get_arrays(surface);triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
  # The map owner uses this same conservative solid-cover box, including the L fence interior.
  scene.set_meta("scenery_bounds",bounds)
  preload("res://scripts/forest/forest_art.gd").solid(scene,bounds.get_center(),bounds.size,1,"wood" if kind=="fence_corner" else "stone")
  report.assemblies[kind]={"bounds":str(bounds),"triangles":triangles,"surfaces":surfaces}
  print("KIT_ASSEMBLY ",kind," ",report.assemblies[kind])
  save_scene(scene,Kit.DIR+kind+".tscn")
 var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow.json"))
 layout.title="Modular Kit Test";layout.raised_castle=false
 layout.ramparts=[]
 for item in [["ramp_6",Vector2(10,0),0,0],["causeway_36",Vector2(13,0),0,0],["ramp_6",Vector2(22,0),2,0],["ramp_12",Vector2(10,7),0,0],["platform_18",Vector2(16,7),0,6],["ramp_12",Vector2(25,7),2,0],["ramp_6",Vector2(10,-7),0,0],["platform_30",Vector2(13,-7),0,0],["ramp_6",Vector2(21,-7),2,0],["corner_18",Vector2(-24,-7),0,0],["t_junction_18",Vector2(-24,7),0,0],["ramp_6",Vector2(-27,-7),0,0],["ramp_6",Vector2(-21,.5),3,0],["ramp_6",Vector2(-27,7),0,0],["ramp_6",Vector2(-15,7),2,0],["ramp_6",Vector2(-21,14.5),3,0]]:
  layout.ramparts.append_array(Kit.placement(item[0],item[1],item[2],item[3]))
 layout.trees=layout.trees.filter(func(item):return not Rect2i(6,-12,24,25).has_point(Vector2i(item.x,item.z)))
 layout.roads=layout.roads.filter(func(item):return not Rect2i(8,-11,20,23).has_point(Vector2i(item.x,item.z)))
 for group in ["trees","roads"]:layout[group]=layout[group].filter(func(item):return not Rect2i(-30,-12,15,30).has_point(Vector2i(item.x,item.z)))
 layout.props=[{"kind":"boulder_pair","x":14,"z":3,"scale":1,"rotation":0},{"kind":"river_cluster","x":16,"z":3,"scale":1,"rotation":90},{"kind":"fence_corner","x":19,"z":3,"scale":1,"rotation":0}]
 for x in [10,11,12]:
  layout.props.append({"kind":"stone_block","x":x,"z":3,"scale":1,"rotation":0})
  layout.props.append({"kind":"stone_block","x":x,"z":3,"scale":1,"rotation":0,"height":6})
  layout.props.append({"kind":"wall_cap","x":x,"z":3,"scale":1,"rotation":0,"height":12})
 layout.props.append({"kind":"pine","x":11,"z":3,"scale":.5,"rotation":0,"height":12.7})
 var file=FileAccess.open(FIXTURE,FileAccess.WRITE);file.store_string(JSON.stringify(layout," "));file.close()
 file=FileAccess.open(OUT+"inventory.json",FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close()
 print("ENVIRONMENT_KIT_BUILD_PASS");quit()
