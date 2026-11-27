extends "res://tests/forest-shrine/elsa_map_review.gd"
## Private source-role preview. No canonical texture, gameplay or mesh is edited.
const Scenery=preload("res://scripts/forest/forest_elsa_scenery.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/Elsa Island/Temple Interior/Central Assembly Candidate/"
var spec:Dictionary={}
var prepared=false

func _initialize():
 capture_output=OUTPUT+"central-posts-candidate/"
 super._initialize()

func setup_review_game():
 await super.setup_review_game()
 spec=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"roles.json"))
 check(spec.candidate_only,"Central post preview stays private")
 Scenery.props=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/elsa/props/data.json"))
 var images=[]
 for name in ["atlas","solid"]:
  var image=Image.load_from_file("res://assets/maps/falan/elsa/props/%s-10.png"%name)
  image.convert(Image.FORMAT_RGBA8);images.append(image)
 var masks=[]
 for name in ["right-post","left-post"]:masks.append(Image.load_from_file(FOLDER+name+"-mask.png"))
 var removed=0
 for proof in spec.sources:
  var row:Dictionary=Scenery.props.groups[proof.group]
  check(int(row.page)==10,"Both mixed native masters retain their original atlas page")
  var start=Vector2i(proof.native_origin[0]-spec.native_origin[0],proof.native_origin[1]-spec.native_origin[1])
  for y in int(row.rect[3]):
   for x in int(row.rect[2]):
    var at=Vector2i(x,y)+start
    if masks.all(func(mask):return mask.get_pixelv(at).r==0.):continue
    var pixel=Vector2i(int(row.rect[0])+x,int(row.rect[1])+y)
    if images[0].get_pixelv(pixel).a>0.:removed+=1
    for image in images:
     var color:Color=image.get_pixelv(pixel);color.a=0.;image.set_pixelv(pixel,color)
 check(removed==int(spec.roles[0].selected_pixels)+int(spec.roles[1].selected_pixels),"Only the two source post photographs leave the private atlas")
 Scenery.prop_textures[10]=[ImageTexture.create_from_image(images[0]),ImageTexture.create_from_image(images[1])]

func prepare_review_point(point:Dictionary):
 check(int(point.map)==59530,"Mixed-master preview stays in its source temple")
 if prepared:return
 prepared=true
 var original=game.world.find_child("ElsaOriginalObject_414",true,false)
 check(original!=null,"Normal scenery owns the mapped mixed masters")
 if original==null:return
 var state=Original.state(59530)
 for row in spec.column_candidates:
  var texture=ImageTexture.create_from_image(Image.load_from_file(FOLDER+row.paint))
  var g={"origin":row.origin,"rect":[0,0,row.size[0],row.size[1]]}
  var mesh=Scenery.Fit.transformed(Scenery.column(g,texture,row.shape),Scenery.Fit.native_coastal_frame())
  var node=MeshInstance3D.new();node.name="ElsaPrivateCentral_"+row.name
  node.mesh=mesh;node.position=Vector3(state.origin.x,0.,state.origin.y)
  node.set_meta("inferred_hidden_surfaces",true);original.get_parent().add_child(node)
  check(mesh.has_meta("source_surface_arrays") and node.get_child_count()==0,"Private octagonal post reuses retained CPU geometry and adds no collision "+row.name)
  var box=mesh.get_aabb()
  var expected=(float(row.shape.foot[1])-float(row.shape.profile[-1][1]))/Scenery.Fit.VERTICAL
  check(absf(box.position.y)<.001 and absf(box.end.y-expected)<.001,"Visible source rows guide the inferred full post height "+row.name)
 check(game.army_runtime.handles.is_empty(),"Temple post review preserves the safe area")
 var at=Original.source_point(59530,Vector2i(point.cell[0],point.cell[1]))
 check(is_zero_approx(game.model.surface_height(at.x,at.y)),"Private post preview leaves walking support unchanged")
 print("ELSA_CENTRAL_POST_CANDIDATE posts=",spec.column_candidates.size()," original=",spec.original_rgba_sha256)
