extends "res://tests/forest-shrine/elsa_map_review.gd"
## Private full arch/post fit; reuse the existing source, column and floor owners.
const Scenery=preload("res://scripts/forest/forest_elsa_scenery.gd")
const Floor=preload("res://scripts/forest/forest_elsa_landmark_floor.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/Elsa Island/Temple Interior/Central Assembly Candidate/Portal/"
var spec:Dictionary={}
var prepared=false

func _initialize():
 capture_output=OUTPUT+"central-portal-candidate/"
 super._initialize()

func setup_review_game():
 await super.setup_review_game()
 spec=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"data.json"))
 check(spec.candidate_only,"Joined portal remains private")
 var original:Dictionary=Floor.data(59530).duplicate(true)
 var replacement:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"floor-data.json"))
 var offset=int(original.pages)
 for key in replacement.placements:
  check(not original.placements.has(key),"Portal photo removal does not overwrite entry-pedestal UV records")
  var row:Dictionary=replacement.placements[key].duplicate();row.page=int(row.page)+offset
  original.placements[key]=row
 for i in int(replacement.pages):
  var image=Image.load_from_file(FOLDER+"floor-atlas-%d.png"%i)
  Floor.regional_textures[[59530,Floor.PAGE_OFFSET+offset+i]]=ImageTexture.create_from_image(image)
 original.pages=offset+int(replacement.pages);original.candidate_only=true
 Floor.regional_records[59530]=original
 Scenery.props=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/elsa/props/data.json"))
 var images=[]
 for name in ["atlas","solid"]:
  var image=Image.load_from_file("res://assets/maps/falan/elsa/props/%s-10.png"%name)
  image.convert(Image.FORMAT_RGBA8);images.append(image)
 var mask=Image.load_from_file(FOLDER+"fg-photo-mask.png");var removed=0
 for placement in Scenery.props.maps["59530"]:
  if placement.group not in ["414","422"]:continue
  var row:Dictionary=Scenery.props.groups[placement.group]
  var start=Vector2i(placement.anchor[0]+row.origin[0]-spec.rect[0],placement.anchor[1]+row.origin[1]-spec.rect[1])
  for y in int(row.rect[3]):
   for x in int(row.rect[2]):
    if mask.get_pixelv(Vector2i(x,y)+start).r==0.:continue
    var pixel=Vector2i(int(row.rect[0])+x,int(row.rect[1])+y)
    if images[0].get_pixelv(pixel).a>0.:removed+=1
    for image in images:
     var color:Color=image.get_pixelv(pixel);color.a=0.;image.set_pixelv(pixel,color)
 check(removed==int(spec.fg_photo_pixels),"Only the original FG arch/right-post photographs leave the private atlas")
 Scenery.prop_textures[10]=[ImageTexture.create_from_image(images[0]),ImageTexture.create_from_image(images[1])]

func profile_point(pixel:Vector2)->Vector3:
 var foot=float(spec.arch.foot[0])*pixel.x+float(spec.arch.foot[1])
 return Vector3(pixel.x*3./64.-foot/16.,(foot-pixel.y)/Scenery.Fit.VERTICAL,pixel.x*3./64.+foot/16.)

func arch_mesh()->Mesh:
 var row:Dictionary=spec.arch;var texture=ImageTexture.create_from_image(Image.load_from_file(FOLDER+row.paint))
 var solid=ImageTexture.create_from_image(Image.load_from_file(FOLDER+row.solid))
 var graphic=[Rect2(Vector2.ZERO,texture.get_size()),-Vector2(row.origin[0],row.origin[1]),Vector2.ONE,0]
 var skin=Source.new(graphic,texture,1./Scenery.Fit.VERTICAL)
 var edge_skin=Source.new(graphic,solid,1./Scenery.Fit.VERTICAL)
 var direction=Vector3(3./64.-float(row.foot[0])/16.,0.,3./64.+float(row.foot[0])/16.)
 var normal=Vector3.UP.cross(direction).normalized();var offset=-normal*float(row.depth)
 var loops=[];var loop=PackedVector2Array();var last=Vector2.INF
 for edge in row.edges:
  var a=Vector2(edge[0],edge[1]);var b=Vector2(edge[2],edge[3])
  if a!=last and not loop.is_empty():loops.append(loop);loop=PackedVector2Array()
  loop.append(a);last=b
 if not loop.is_empty():loops.append(loop)
 for polygon in loops:
  var triangles=Geometry2D.triangulate_polygon(polygon)
  check(not triangles.is_empty(),"Source arch contour triangulates without a rectangular slab")
  for i in range(0,triangles.size(),3):
   var points=[]
   for j in 3:points.append(profile_point(polygon[triangles[i+j]]+Vector2(row.origin[0],row.origin[1])))
   if (points[2]-points[0]).cross(points[1]-points[0]).dot(normal)<0.:points.reverse()
   for j in [0,1,2]:skin.projected_vertex(points[j],normal,points[j])
   for j in [2,1,0]:skin.projected_vertex(points[j]+offset,-normal,points[j])
 for edge in row.edges:
  var origin=Vector2(row.origin[0],row.origin[1])
  var a=profile_point(origin+Vector2(edge[0],edge[1]));var b=profile_point(origin+Vector2(edge[2],edge[3]))
  var sample=profile_point(origin+Vector2(edge[4],edge[5]));var points=[a,b,b+offset,a+offset]
  var face=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  for i in [0,1,2,0,2,3]:edge_skin.projected_vertex(points[i],face,sample)
 var mesh=ArrayMesh.new();var retained=[]
 for piece in [skin.finish(true),edge_skin.finish(true)]:
  var arrays:Array=piece.get_meta("source_surface_arrays");retained.append(arrays)
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(mesh.get_surface_count()-1,piece.surface_get_material(0))
 mesh.set_meta("source_all_surface_arrays",retained);return mesh

func prepare_review_point(point:Dictionary):
 check(int(point.map)==59530,"Joined portal stays in the source temple")
 if prepared:return
 prepared=true
 var original=game.world.find_child("ElsaOriginalObject_414",true,false)
 check(original!=null,"Existing scenery owns the original arch placements")
 if original==null:return
 var state=Original.state(59530);var parent=original.get_parent()
 for row in spec.columns:
  var texture=ImageTexture.create_from_image(Image.load_from_file(FOLDER+row.paint))
  var g={"origin":row.origin,"rect":[0,0,row.size[0],row.size[1]]}
  var node=MeshInstance3D.new();node.name="ElsaPrivatePortal_"+row.name
  node.mesh=Scenery.Fit.transformed(Scenery.column(g,texture,row.shape),Scenery.Fit.native_coastal_frame())
  node.position=Vector3(state.origin.x,0.,state.origin.y);parent.add_child(node)
  check(node.mesh.has_meta("source_surface_arrays") and node.get_child_count()==0,"Post uses the shared retained column fitter without collision "+row.name)
 var arch=MeshInstance3D.new();arch.name="ElsaPrivateJoinedCentralArch";arch.mesh=arch_mesh()
 arch.position=Vector3(state.origin.x,0.,state.origin.y);parent.add_child(arch)
 check(arch.mesh.get_surface_count()==2 and arch.mesh.has_meta("source_all_surface_arrays"),"Full arch has native front/rear and real contour-depth surfaces with retained CPU arrays")
 check(game.army_runtime.handles.is_empty(),"Portal remains a safe noncombat area")
 var at=Original.source_point(59530,Vector2i(point.cell[0],point.cell[1]))
 check(is_zero_approx(game.model.surface_height(at.x,at.y)),"Portal fit adds no walking cells or height support")
 print("ELSA_CENTRAL_PORTAL_CANDIDATE posts=",spec.columns.size()," contour_edges=",spec.arch.edges.size())
