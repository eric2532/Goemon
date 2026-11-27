extends "res://tests/forest-shrine/elsa_map_review.gd"
## Review the scoped parent paving through original CUT floor geometry/UVs.
const Floor=preload("res://scripts/forest/forest_elsa_landmark_floor.gd")
const GROUND="res://build/Other Files/Asset Toolkit/Elsa Island/Temple Interior/Central Assembly Candidate/Second Stair/Parent Floor/"
var production=false

func _initialize():
 super._initialize();production="--production" in OS.get_cmdline_user_args()
 capture_output=OUTPUT+("second-stair-parent-floor-production/" if production else "second-stair-parent-floor-cut/")

func setup_review_game():
 await super.setup_review_game()
 if production:return
 var row:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(GROUND+"floor-data.json"))
 Floor.regional_records[59530]=row
 for i in int(row.pages):
  var image=Image.load_from_file(GROUND+"floor-atlas-%d.png"%i);image.generate_mipmaps()
  Floor.regional_textures[[59530,Floor.PAGE_OFFSET+i]]=ImageTexture.create_from_image(image)

func prepare_review_point(_point:Dictionary):
 var row:Dictionary=Floor.data(59530)
 check(bool(row.candidate_only)!=production and row.ground_infill.pixels>0,"CUT parent-paving source uses the expected publication state")
 check(game.world.find_children("ElsaOccludedFloor_BGStair*","MeshInstance3D",true,false).is_empty(),"Parent paving uses original CUT geometry without another overlay plane")
 check(game.army_runtime.handles.is_empty(),"The temple remains safe")
