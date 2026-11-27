extends "res://tests/forest-shrine/elsa_map_review.gd"
## Staged visual review. A separate movement fixture verifies landing support.
const Floor=preload("res://scripts/forest/forest_elsa_landmark_floor.gd")
const Steps=preload("res://scripts/forest/forest_elsa_hall_steps.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const DRAFT=OUTPUT+"../Temple Interior/Hall Entry Candidate/"
var initialized=false
var prepared=false
var retained_images:Array[Image]=[]
var entry_props:Dictionary={}
var prop_paints:Dictionary={}

func _initialize():
 capture_output=OUTPUT+"hall-entry-candidate/"
 super._initialize()
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DRAFT+"data.json"))
 var floor_:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DRAFT+"floor-data.json"))
 assert(data.candidate_only and floor_.candidate_only and int(data.map)==59530)
 Steps.records[59530]=data;Floor.regional_records[59530]=floor_
 for name in ["paint.png","riser.png","nosing.png"]:
  var image_=Image.load_from_file(DRAFT+name);image_.generate_mipmaps();retained_images.append(image_)
  Steps.paints[[59530,name]]=ImageTexture.create_from_image(image_)
 for page in int(floor_.pages):
  var image_=Image.load_from_file(DRAFT+"floor-atlas-%d.png"%page);retained_images.append(image_)
  Floor.regional_textures[[59530,Floor.PAGE_OFFSET+page]]=ImageTexture.create_from_image(image_)
 if FileAccess.file_exists(DRAFT+"props-data.json"):
  entry_props=JSON.parse_string(FileAccess.get_file_as_string(DRAFT+"props-data.json"))
  assert(entry_props.candidate_only and int(entry_props.map)==59530)
  for name in ["bg-pedestal-body.png","bg-pedestal-globe.png","pedestal-apron-infill.png"]:
   var image_=Image.load_from_file(DRAFT+name);image_.generate_mipmaps();retained_images.append(image_)
   prop_paints[name]=ImageTexture.create_from_image(image_)
 initialized=true

func run():
 if not initialized:printerr("ELSA_HALL_ENTRY_INIT_FAILED");quit(1);return
 await super.run()

func prepare_review_point(point:Dictionary):
 check(int(point.map)==59530,"Staged entry belongs to its original temple map")
 if prepared:return
 prepared=true
 var nodes=game.world.find_children("ElsaOriginalObject_406","MultiMeshInstance3D",true,false).filter(func(node):return node.is_visible_in_tree() and node.get_world_3d()==game.camera_rig.camera.get_world_3d())
 check(nodes.size()==1,"The original pedestal identifies the active source scenery root")
 if nodes.size()!=1:return
 var parent=nodes[0].get_parent();var state=Original.state(59530)
 if not entry_props.is_empty():
  var scenery=preload("res://scripts/forest/forest_elsa_scenery.gd")
  var canonical:Dictionary=scenery.source_surface_spec(scenery.props.groups["406"].pedestal.path,59530)
  var body:Dictionary=entry_props.spec.body.duplicate(true);body.erase("cap_paint_pixel")
  check(body==canonical.body,"The background variant reuses the reviewed source-family body geometry")
  # This private fixture reuses approved geometry with staged source paint.
  var reviewed:Dictionary=entry_props.duplicate(true);reviewed.spec.candidate_only=false
  scenery.entry_pedestals(parent,state.origin,reviewed,[prop_paints["bg-pedestal-body.png"],prop_paints["bg-pedestal-globe.png"],prop_paints["pedestal-apron-infill.png"]])
  var node=parent.find_child("ElsaOriginalBGPedestal",false,false)
  check(node.mesh.get_surface_count()==2 and node.get_child_count()==0,"Mapped BG pedestal has separate body/globe surfaces and no gameplay owner")
  var floor_node=parent.find_child("ElsaOriginalPedestalApronRepair",false,false)
  check(floor_node.get_child_count()==0,"Source-clipped apron continuation changes no collision, walking cells or interaction")
 var effect_nodes=parent.find_children("*","MultiMeshInstance3D",true,false).filter(func(node):return int(node.get_meta("source_graphic",-1)) in [44519,44520,44521])
 check(effect_nodes.size()==3,"All three original temple effect placements remain present")
 for node in effect_nodes:
  var material:ShaderMaterial=node.multimesh.mesh.surface_get_material(0)
  check(material.shader.get_code().contains("blend_add"),"Native LIGHT_THROUGH effect preserves the scenery behind its dark fringe")
 check(parent.find_child("ElsaOriginalCurvedTreads",false,false)!=null,"The existing scenery owner assembles the staged treads")
 check(Steps.visuals.has(59530) and Steps.visuals[59530].get_surface_count()==3,"Source tread tops, nosings and risers use separate real surfaces")
 check(Steps.supports[59530].has_meta("source_support_faces"),"Signed support geometry retains its CPU triangle source")
 # Preserve the native near-black background at background depth, not on a flat lid.
 var image_=Image.create(1,1,false,Image.FORMAT_RGBA8);image_.fill(Color(2./255.,2./255.,2./255.));retained_images.append(image_)
 var texture_=ImageTexture.create_from_image(image_);var plane=PlaneMesh.new();plane.size=Vector2(state.size)*3.
 var node=MeshInstance3D.new();node.name="ElsaOriginalVoidBackdropCandidate";node.mesh=plane;node.material_override=Source.material(texture_)
 var centre:Vector2=state.origin+(Vector2(state.size)-Vector2.ONE)*1.5
 node.position=Vector3(centre.x,-20.,centre.y);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node)
 node.set_meta("original_background_matte",true)
 check(is_zero_approx(game.model.surface_height(Original.source_point(59530,Vector2i(69,92)).x,Original.source_point(59530,Vector2i(69,92)).y)),"Review remains on the unchanged upper floor; lower movement support is explicitly pending")
 print("ELSA_HALL_ENTRY_VISUAL_DRAFT levels=5 private_pages=",Floor.data(59530).pages," candidate_only=true")
