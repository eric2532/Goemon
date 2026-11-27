extends SceneTree
const Temple=preload("res://scripts/forest/forest_elsa_temple.gd")
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const Floor=preload("res://scripts/forest/forest_elsa_landmark_floor.gd")
const Scenery=preload("res://scripts/forest/forest_elsa_scenery.gd")
var checks=0
var failures=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("ELSA_TEMPLE_FAIL ",message)
func _initialize():
 create_timer(180).timeout.connect(func():printerr("ELSA_TEMPLE_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 var result:Mesh=Temple.mesh();var triangles=0
 check(result.get_surface_count()==5,"Original front and four native material roles are separate")
 check(result.surface_get_material(0).get_shader_parameter("original_palette")==true,"Original-facing paint retains its native color treatment")
 check(result.surface_get_material(1).get_shader_parameter("original_palette")==false,"Hidden surfaces use local lighting to read their geometry")
 check(Temple.Source.material(load(Temple.ROOT+"white.png")).get_shader_parameter("original_palette")==true,"Local hidden lighting does not change the shared source material")
 for i in result.get_surface_count():
  var arrays=result.surface_get_arrays(i);var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];triangles+=points.size()/3
  check(not points.is_empty(),"Every temple surface has geometry")
  for point in points:
   if not point.is_finite():check(false,"Finite temple vertices");break
 check(result.get_aabb().size.y>100.,"The clipped source facade has an enclosed inferred upper continuation")
 check(result.get_aabb().end.y<150.,"Inferred roofs use short facade-relative continuations instead of the old200m white tapers")
 var roof_arrays=result.surface_get_arrays(3);var roof_points:PackedVector3Array=roof_arrays[Mesh.ARRAY_VERTEX];var roof_levels={}
 for point in roof_points:
  if point.y>100.:roof_levels[snappedf(point.y,.1)]=true
 check(roof_levels.size()>8,"Blue roof caps have curved segmented profiles rather than one flat pyramid face")
 var central:Dictionary=Temple.data().parts.filter(func(part):return part.name=="central-entrance")[0]
 var contacts=Temple.facade_contacts(central);var contact_error=0.;var foot_shift=0.
 for point in contacts:
  var distance=INF
  for i in central.front.size()-1:
   var a=Vector2(central.front[i][0],central.front[i][1]);var b=Vector2(central.front[i+1][0],central.front[i+1][1]);var edge=b-a
   distance=minf(distance,point.distance_to(a+edge*clampf((point-a).dot(edge)/edge.length_squared(),0.,1.)))
  contact_error=maxf(contact_error,distance)
  var at=Temple.ground(point);foot_shift=maxf(foot_shift,at.distance_to(Temple.round_bays(at,central)))
 check(contacts.size()>central.front.size() and contact_error<.01,"Rounded facade adds segments along the original contact lines")
 check(foot_shift<.001,"Both rounded bays leave every original ground contact unchanged")
 var bay_error=0.
 for span in central.bays.spans:
  var depths=[]
  for t in [.125,.5,.875]:
   var u=lerpf(float(span[0]),float(span[1]),t);var at=Temple.ground(Vector2(u,-2500.))+Vector3.UP*(700./Temple.Fit.VERTICAL)
   var curved=Temple.round_bays(at,central);depths.append(curved.distance_to(at))
   var before=Temple.native(at)-Vector2(0,at.y*Temple.Fit.VERTICAL);var after=Temple.native(curved)-Vector2(0,curved.y*Temple.Fit.VERTICAL)
   bay_error=maxf(bay_error,before.distance_to(after))
  var depth=float(central.bays.depth)
  check(depths[1]>depth*.98 and depths[1]>depths[0]+depth*.25 and depths[1]>depths[2]+depth*.25,"Each source white lobe has a rounded volume rather than a straight slab")
 check(bay_error<.01,"Inferred bay depth preserves the original facade projection")
 var front_arrays=result.surface_get_arrays(0);var front_points:PackedVector3Array=front_arrays[Mesh.ARRAY_VERTEX];var front_uv:PackedVector2Array=front_arrays[Mesh.ARRAY_TEX_UV]
 var texture:Texture2D=result.surface_get_material(0).get_shader_parameter("base_texture");var projection_error=0.
 var rises:Array=Temple.Steps.data(59520).rises.values()+[0.]
 for i in front_points.size():
  var expected=front_uv[i]*texture.get_size()+Temple.bounds().position
  var actual=Temple.native(front_points[i])-Vector2(0,front_points[i].y*Temple.Fit.VERTICAL);var error=INF
  for rise in rises:error=minf(error,actual.distance_to(expected-Vector2(0,float(rise)*Temple.Fit.VERTICAL)))
  projection_error=maxf(projection_error,error)
 check(front_points.size()>1000 and projection_error<.8,"Actual tessellated facade vertices retain native paint placement within the half-pixel atlas clamp")
 print("ELSA_TEMPLE_BAYS contacts=",contacts.size()," contact_error=",contact_error," foot_shift=",foot_shift," projection_error=",projection_error)
 var root=Node3D.new();Temple.build(root,Vector2.ZERO)
 check(root.get_child_count()==9,"Temple, shared tread support and six rail instances are assembled")
 check(root.find_child("ElsaTempleOriginalGarden",false,false)==null,"BG repairs reuse the original tiles instead of a flat garden slab")
 var stairs=root.find_child("ElsaTempleCurvedTreads",false,false)
 check(stairs!=null and stairs.mesh.get_surface_count()==3,"Native paving, blue risers and thin gold nosings have separate surfaces")
 for node in root.get_children():
  if node is MeshInstance3D:print("ELSA_TEMPLE_PART ",node.name," surfaces=",node.mesh.get_surface_count()," triangles=",node.mesh.get_faces().size()/3)
 var state:Dictionary=Original.state(59520)
 for link in Temple.data().doors:
  var cell=Vector2i(link.cell[0],link.cell[1])
  check(Original.open(state.bits,state.size,cell),"Original temple crossing remains on open ground")
 if "--floor-probe" in OS.get_cmdline_user_args():
  var floor_root=Node3D.new();Floor.build(floor_root,state.origin)
  check(floor_root.get_child_count()==1,"One alpha-only occluded floor patch is assembled")
  var patch:MeshInstance3D=floor_root.get_child(0)
  check(patch.mesh.get_faces().size()==6 and is_zero_approx(patch.mesh.get_aabb().size.y),"Occluded infill adds only a ground quad")
  check(patch.get_child_count()==0,"Occluded paint adds no collision or travel owner")
  floor_root.free()
  var profiles=0
  for token in Floor.data().placements:
   if not Floor.data().placements[token].shoreline:continue
   var index=int(token);var serial=state.raw.decode_u16(20+index*2)
   var original:Dictionary=Original.Art.data().graphics[str(serial)]
   var repaired:Dictionary=Floor.graphic(index,original)
   var at=Vector3(state.origin.x+(index%state.size.x)*3,0,state.origin.y+(index/state.size.x)*3)
   var before=SurfaceTool.new();before.begin(Mesh.PRIMITIVE_TRIANGLES)
   var after=SurfaceTool.new();after.begin(Mesh.PRIMITIVE_TRIANGLES)
   check(Scenery.shore_floor(before,at,original,Vector2(2048,2048),index),"Original shoreline profile exists")
   check(Scenery.shore_floor(after,at,repaired,Floor.texture(repaired.page).get_size(),index),"Repaired tile retains that shoreline profile")
   var a=before.commit_to_arrays();var b=after.commit_to_arrays()
   check(a[Mesh.ARRAY_VERTEX]==b[Mesh.ARRAY_VERTEX] and a[Mesh.ARRAY_NORMAL]==b[Mesh.ARRAY_NORMAL],"Shoreline positions, heights and normals remain exact")
   profiles+=1
  check(profiles>0,"The repair actually covers shoreline tiles")
  print("ELSA_TEMPLE_FLOOR_PROFILES ",profiles)
 print("ELSA_TEMPLE_GEOMETRY_RESULT triangles=",triangles," checks=",checks," failures=",failures)
 root.free();quit(1 if failures else 0)
