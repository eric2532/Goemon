extends "res://tests/forest-shrine/elsa_central_steps_review.gd"
## Replace only the source BG wall photo within the joined private assembly.
const WALL_FOLDER=STEPS_FOLDER+"../Wall/"
var wall_spec:Dictionary={}
var wall_prepared=false

func _initialize():
 super._initialize()
 capture_output=OUTPUT+"central-wall-candidate/"

func setup_review_game():
 await super.setup_review_game()
 wall_spec=JSON.parse_string(FileAccess.get_file_as_string(WALL_FOLDER+"data.json"))
 var original:Dictionary=Floor.data(59530).duplicate(true)
 var replacement:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WALL_FOLDER+"floor-data.json"))
 var offset=int(original.pages)
 for key in replacement.placements:
  var row:Dictionary=replacement.placements[key].duplicate();row.page=int(row.page)+offset
  original.placements[key]=row
 for i in int(replacement.pages):
  Floor.regional_textures[[59530,Floor.PAGE_OFFSET+offset+i]]=ImageTexture.create_from_image(Image.load_from_file(WALL_FOLDER+"floor-atlas-%d.png"%i))
 original.pages=offset+int(replacement.pages);Floor.regional_records[59530]=original

func prepare_review_point(point:Dictionary):
 super.prepare_review_point(point)
 if wall_prepared:return
 wall_prepared=true
 var original=game.world.find_child("ElsaOriginalObject_414",true,false)
 if original==null:return
 var state=Original.state(59530);var bits:PackedByteArray=state.bits.duplicate();var paints={}
 for pair in [["native","native-paint.png"],["floor","rear-paint.png"],["body","body.png"]]:
  var image=Image.load_from_file(WALL_FOLDER+pair[1]);image.generate_mipmaps()
  paints[pair[0]]=ImageTexture.create_from_image(image)
 var node=MeshInstance3D.new();node.name="ElsaPrivateCentralMasonryWall"
 node.mesh=Scenery.central_steps_mesh(wall_spec,paints)
 node.position=Vector3(state.origin.x,0.,state.origin.y);original.get_parent().add_child(node)
 node.set_meta("inferred_hidden_wall_continuation",true)
 check(wall_spec.candidate_only and node.mesh.has_meta("source_all_surface_arrays"),"Source wall retains CPU geometry and remains private")
 check(node.get_child_count()==0 and state.bits==bits,"Wall depth adds no collision, navigation or travel owner")
 print("ELSA_CENTRAL_WALL_CANDIDATE source_pixels=",wall_spec.observed_pixels," faces=",wall_spec.surfaces.size())
