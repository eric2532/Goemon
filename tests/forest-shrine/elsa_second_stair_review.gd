extends "res://tests/forest-shrine/elsa_central_wall_review.gd"
## Private joined source BG stair; original walkability/support stay untouched.
const SECOND_FOLDER=STEPS_FOLDER+"../Second Stair/"
var second_spec:Dictionary={}
var second_prepared=false

func _initialize():
 super._initialize()
 capture_output=OUTPUT+"second-stair-candidate/"

func setup_review_game():
 await super.setup_review_game()
 second_spec=JSON.parse_string(FileAccess.get_file_as_string(SECOND_FOLDER+"data.json"))
 var original:Dictionary=Floor.data(59530).duplicate(true)
 var replacement:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SECOND_FOLDER+"floor-data.json"))
 var offset=int(original.pages)
 for key in replacement.placements:
  var row:Dictionary=replacement.placements[key].duplicate();row.page=int(row.page)+offset
  original.placements[key]=row
 for i in int(replacement.pages):
  Floor.regional_textures[[59530,Floor.PAGE_OFFSET+offset+i]]=ImageTexture.create_from_image(Image.load_from_file(SECOND_FOLDER+"floor-atlas-%d.png"%i))
 original.pages=offset+int(replacement.pages);Floor.regional_records[59530]=original

func prepare_review_point(point:Dictionary):
 super.prepare_review_point(point)
 if second_prepared:return
 second_prepared=true
 var original=game.world.find_child("ElsaOriginalObject_414",true,false)
 if original==null:return
 var published=game.world.find_child("ElsaOriginalBGStair",true,false)
 if published!=null:published.hide()
 var state=Original.state(59530);var bits:PackedByteArray=state.bits.duplicate();var paints={}
 for name in ["native","cap","stone","stone_shadow","body","charcoal","gold"]:
  var image=Image.load_from_file(SECOND_FOLDER+("native-paint.png" if name=="native" else name+".png"));image.generate_mipmaps()
  paints[name]=ImageTexture.create_from_image(image)
 var node=MeshInstance3D.new();node.name="ElsaPrivateSecondStair"
 node.mesh=Scenery.central_steps_mesh(second_spec,paints)
 node.position=Vector3(state.origin.x,0.,state.origin.y);original.get_parent().add_child(node)
 check(node.mesh.has_meta("source_all_surface_arrays") and node.get_child_count()==0,"Second stair reuses retained static geometry without a new collision owner")
 var arrays:Array=node.mesh.get_meta("source_all_surface_arrays");var smallest=INF;var triangles=0
 for surface in arrays:
  var vertices:PackedVector3Array=surface[Mesh.ARRAY_VERTEX]
  for i in range(0,vertices.size(),3):
   smallest=minf(smallest,(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length()*.5);triangles+=1
 check(smallest>.000001,"Second stair has finite nondegenerate retained triangles")
 check(state.bits==bits and game.army_runtime.handles.is_empty(),"Original walking cells and safe temple remain intact")
 print("ELSA_SECOND_STAIR_CANDIDATE triangles=",triangles," minimum_area=",smallest," source_balusters=",second_spec.source_balusters.map(func(row):return row.size()))
