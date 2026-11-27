extends SceneTree
const East=preload("res://scripts/forest/forest_east_region_art.gd")
func _initialize():
 var skin=East.structure()
 skin.quad(Vector3.ZERO,Vector3.UP,Vector3(1,1,0),Vector3.RIGHT)
 var one:Mesh=skin.finish();var both:Mesh=East.combine([one,one])
 assert(one.has_meta("east_cpu_arrays"))
 assert(both.has_meta("east_cpu_arrays"))
 assert(both.get_surface_count()==2)
 for arrays in both.get_meta("east_cpu_arrays"):
  assert(arrays[Mesh.ARRAY_VERTEX].size()==6)
  assert(arrays[Mesh.ARRAY_NORMAL].size()==6)
  assert(arrays[Mesh.ARRAY_TEX_UV].size()==6)
 var scaled=East.owner_frame(both)
 assert(is_equal_approx(scaled.get_aabb().size.y,East.OWNER_Y_SCALE))
 East.Art.load_east()
 var old=East.structure();var cached=East.structure()
 for pose in [[Vector3.ZERO,Vector3(2,3,-4),.12],[Vector3(-3,4,5),Vector3(3,1,2),.31]]:
  East.Harbor.rod(old,pose[0],pose[1],pose[2],"timber");East.rod(cached,pose[0],pose[1],pose[2],"timber")
 var original_arrays:Array=old.finish().get_meta("east_cpu_arrays")[0];var cached_arrays:Array=cached.finish().get_meta("east_cpu_arrays")[0]
 for component in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:assert(original_arrays[component]==cached_arrays[component],"Cached native rod must preserve exact geometry and UVs")
 var plank:Mesh=East.native_floor_piece(East.Art.data().graphics["1260162"])
 for normal:Vector3 in plank.get_meta("east_cpu_arrays")[0][Mesh.ARRAY_NORMAL]:assert(normal.y>.99,"Native plank paint must face above the floor")
 var dragon:Dictionary=East.Art.data().graphics["1235177"];var dragon_spec:Dictionary=East.data().graphics["1235177"]
 var relief:Mesh=East.sculpted_relief(dragon,dragon_spec,load(East.ROOT+"1235177-back.png"),load(East.ROOT+"1235177-front.png"))
 var native_view=Vector3(-1./16.,1./East.Fit.VERTICAL,1./16.).normalized()
 for normal:Vector3 in relief.get_meta("east_cpu_arrays")[0][Mesh.ARRAY_NORMAL]:assert(normal.dot(native_view)>0.,"Visible sculpture paint must face the native view")
 var spec:Dictionary=East.data().graphics["1233190"];var graphic:Dictionary=East.Art.data().graphics["1233190"].duplicate(true);graphic.cut=[int(spec.source_serial)]
 var raw:Mesh=East.Elsa.fitted_model(spec.asset,graphic,Rect2(spec.visible[0],spec.visible[1],spec.visible[2]-spec.visible[0],spec.visible[3]-spec.visible[1]))
 print("EAST_TREE_OWNER_AUDIT ",JSON.stringify({"graphic":1233190,"fitted_model_height":raw.get_aabb().size.y,"after_owner_factor_height":raw.get_aabb().size.y*East.OWNER_Y_SCALE,"native_pixel_height_owner":float(spec.visible[3]-spec.visible[1])*East.OWNER_HEIGHT_PER_PIXEL,"generic_owner_source_height":preload("res://scripts/forest/forest_original_map_solids.gd").source_height(graphic)}))
 print("EAST_LANDMARK_CPU_COMPOSITION checks=16 failures=0")
 quit(0)
