extends "res://tests/forest-shrine/elsa_central_portal_review.gd"
## The whole mixed414/422 assembly replaces its photos in this private review.
const STEPS_FOLDER=FOLDER+"../Steps/"
var step_spec:Dictionary={}
var steps_prepared=false

func _initialize():
 super._initialize()
 capture_output=OUTPUT+"central-stairs-candidate/"

func setup_review_game():
 await super.setup_review_game()
 step_spec=JSON.parse_string(FileAccess.get_file_as_string(STEPS_FOLDER+"data.json"))
 for placement in Scenery.props.maps["59530"]:
  if placement.group in ["414","422"]:placement.erase("ground_cells")

func prepare_review_point(point:Dictionary):
 super.prepare_review_point(point)
 if steps_prepared:return
 steps_prepared=true
 var original=game.world.find_child("ElsaOriginalObject_414",true,false)
 if original==null:return
 var parent=original.get_parent();var state=Original.state(59530)
 var bits:PackedByteArray=state.bits.duplicate()
 var ground:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(STEPS_FOLDER+"ground-infill.json"))
 var ground_image=Image.load_from_file(STEPS_FOLDER+"ground-infill.png")
 var texture_=ImageTexture.create_from_image(ground_image)
 var start=Vector2(ground.origin[0],ground.origin[1]);var size_=Vector2(ground.size[0],ground.size[1])
 var skin=Source.new([Rect2(Vector2.ZERO,size_),-start,Vector2.ONE,0],texture_,1./Scenery.Fit.VERTICAL)
 skin.reflection_threshold=2.
 var corners=[]
 for p in [start,start+Vector2(size_.x,0),start+size_,start+Vector2(0,size_.y)]:corners.append(Floor.ground(p))
 skin.quad(corners[0],corners[1],corners[2],corners[3])
 var apron=MeshInstance3D.new();apron.name="ElsaPrivateCentralGroundRepair";apron.mesh=skin.finish(true)
 apron.position=Vector3(state.origin.x,.035,state.origin.y);apron.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 apron.set_meta("inferred_occluded_paving",true);parent.add_child(apron)
 check(ground.candidate_only and ground.pixels>0 and not ground.patches.is_empty(),"Concealed parent paving is source-derived and remains private")
 for token in ["414","422"]:
  for node in game.world.find_children("ElsaOriginalObject_"+token,"MultiMeshInstance3D",true,false):node.hide()
 var paints={}
 for pair in [["native","native-paint.png"],["floor","floor-paint.png"],["body","body.png"],["stone","stone.png"],["cap","cap.png"],["gold","gold.png"]]:
  var image=Image.load_from_file(STEPS_FOLDER+pair[1]);image.generate_mipmaps()
  paints[pair[0]]=ImageTexture.create_from_image(image)
 var node=MeshInstance3D.new();node.name="ElsaPrivateConnectedCentralStairs"
 node.mesh=Scenery.central_steps_mesh(step_spec,paints)
 node.position=Vector3(state.origin.x,0.,state.origin.y);parent.add_child(node)
 node.set_meta("inferred_decorative_height",true)
 check(node.mesh.has_meta("source_all_surface_arrays") and node.get_child_count()==0,"Connected source stairs retain CPU geometry and add no collision owner")
 var source_columns:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(STEPS_FOLDER+"../roles.json"))
 var column:Dictionary=source_columns.column_candidates.filter(func(row):return row.name=="left-post")[0]
 var texture=ImageTexture.create_from_image(Image.load_from_file(STEPS_FOLDER+"../"+column.paint))
 var g={"origin":column.origin,"rect":[0,0,column.size[0],column.size[1]]}
 var pillar=MeshInstance3D.new();pillar.name="ElsaPrivateCentralStairPost"
 pillar.mesh=Scenery.Fit.transformed(Scenery.column(g,texture,column.shape),Scenery.Fit.native_coastal_frame())
 pillar.position=node.position;parent.add_child(pillar)
 check(state.bits==bits,"Reconstructing the raised architecture preserves every original walking bit")
 for proof in step_spec.walkability_proofs:
  var cell=Vector2i(proof.cell[0],proof.cell[1]);var at=Original.source_point(59530,cell)
  check(Original.open(bits,state.size,cell)==(int(proof.reference_flag)==0),"Native walking matches the recorded client/reference flag "+str(cell))
  check(is_zero_approx(game.model.surface_height(at.x,at.y)),"Decorative height does not create an unsupported climb route "+str(cell))
 check(game.army_runtime.handles.is_empty(),"The source temple remains a safe area")
 print("ELSA_CENTRAL_STEPS_CANDIDATE surfaces=",node.mesh.get_surface_count()," source_polygons=",step_spec.surfaces.size()," levels=",step_spec.top_height,",",step_spec.turn_height," visual_only=true")
