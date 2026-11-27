extends SceneTree
const Underlay=preload("res://scripts/forest/forest_east_bank_underlay.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/"
var checks=0
var failures=0
var observations=[]

func _initialize():run.call_deferred()
func check(okay:bool,label:String):
 checks+=1
 if not okay:failures+=1;printerr("BANK_UNDERLAY_FAIL ",label)

func run():
 var paths=[get_script().resource_path,"scripts/forest/forest_east_bank_underlay.gd","scripts/forest/wind_meadow_ground.gdshader",ROOT+"Il Source Completion/Whole Shore Candidate/banks.json",ROOT+"Village Props/Cliff Audit/Alyut Complete Candidate/banks.json"]
 var before=Fresh.snapshot(paths)
 var bounds=Rect2(-721.5,-721.5,1443,1443)
 for pair in [[2000,"Il Source Completion/Whole Shore Candidate/banks.json"],[2400,"Village Props/Cliff Audit/Alyut Complete Candidate/banks.json"]]:
  var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+pair[1]));var original=var_to_bytes(data)
  var input_rows=[]
  for source:Dictionary in data.rows:
   var row=source.duplicate(true);row.anchor=Vector2(source.anchor[0],source.anchor[1]);input_rows.append(row)
   check(int(source.get("native_floor",source.get("source_bg",0))) in range(5000,5009),"Source BG under each replaced bank cell is water "+str(pair[0])+str(source.source_cell))
  for frame:Transform2D in [Transform2D.IDENTITY,Transform2D(0.,Vector2(-165,-123)),Transform2D(PI*.5,Vector2(240,-120))]:
   var rows=[];var expected={}
   for source:Dictionary in input_rows:
    var row=source.duplicate();row.anchor=frame*source.anchor;row.frame=Transform2D(frame.x,frame.y,Vector2.ZERO);rows.append(row)
    expected[Vector2i(((row.anchor-bounds.position)/3.).floor())]=true
   var result=Underlay.settings(bounds,rows);var texture:Texture2D=result.native_land_visibility;var image:Image=texture.get_meta("source_cpu_image")
   check(result.size()==3 and result.use_native_land_visibility,"Only existing three shader settings are returned")
   check(Underlay.settings(bounds,rows).native_land_visibility==texture,"Immutable same-cell mask is reused")
   check(texture.get_meta("source_bank_cut_cells").size()==rows.size(),"Exact placement count, no neighboring source tile cut")
   var actual={};var controls_clear=true
   for y in image.get_height():
    for x in image.get_width():
     var cell=Vector2i(x,y);var pixel=image.get_pixelv(cell)
     if pixel.g<.5:actual[cell]=true
     else:controls_clear=controls_clear and pixel==Color.WHITE
   check(actual==expected,"Nearest mask removes exactly enrolled source cells "+str(pair[0])+str(frame))
   check(controls_clear,"Every non-enrolled dry/water/void pixel remains visible to its old owner")
   var material=ShaderMaterial.new();material.shader=load("res://scripts/forest/wind_meadow_ground.gdshader")
   check(material.get_shader_parameter("use_native_land_visibility")!=true,"Private material begins with no enabled visibility owner")
   for key in result:material.set_shader_parameter(key,result[key])
   check(material.get_shader_parameter("native_land_visibility")==texture,"Existing nearest visibility sampler uses prepared mask")
   check(material.get_shader_parameter("native_visibility_bounds")==result.native_visibility_bounds,"Existing shader bounds match local bank grid")
   var water_cuts=[{"anchor":Vector2(-600,-600),"source_cell":Vector2i.ZERO,"source_bg":5000},{"anchor":Vector2(-597,-600),"source_cell":Vector2i(1,0),"source_bg":5008}]
   var expanded=Underlay.settings(bounds,rows,water_cuts);var expanded_texture:Texture2D=expanded.native_land_visibility
   check(expanded_texture!=texture and Underlay.settings(bounds,rows,water_cuts).native_land_visibility==expanded_texture,"Distinct bank/water sets use immutable distinct cached masks")
   check(expanded_texture.get_meta("source_bank_cut_cells").size()==rows.size() and expanded_texture.get_meta("source_water_cut_cells").size()==2,"Source-water neighbors are recorded separately, without fake bank IDs")
   var expanded_image:Image=expanded_texture.get_meta("source_cpu_image");var extra=0
   for y in image.get_height():
    for x in image.get_width():
     if expanded_image.get_pixel(x,y)!=image.get_pixel(x,y):extra+=1
   check(extra==2,"Optional source-water records change exactly two additional pixels")
   observations.append({"source":pair[0],"placements":rows.size(),"frame":str(frame),"mask_size":str(image.get_size()),"cut_cells":actual.size(),"bg_under_all_cuts":"5000..5008water","physics_changes":false})
  check(var_to_bytes(data)==original,"Source rows and all support/walk metadata remain byte-identical")
 var cube=BoxMesh.new();cube.size=Vector3(960,12,960)
 var full=Underlay.visual_bounds(cube)
 check(full==Rect2(-481.5,-481.5,963,963),"Full visual AABB gains half-cell guard without changing mesh")
 var changed=Fresh.changed(before);check(changed.is_empty(),"All mask proof sources remain current")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT+"Bank Caps/Underlay Candidate"))
 var file=FileAccess.open(ROOT+"Bank Caps/Underlay Candidate/mask-proof.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_hashes":before,"source_changed_during_run":changed,"observations":observations,"scope":"Private pure mask/material proof only. All393Il and117Alyut BGs under selected banks are original water. Neighboring BGdryland remains visible. Visible cap/body/join coverage and actual source-current normal/second views remain separate acceptance gates. No runtime enrollment, shader edit or physical changes."},"  "));file.close()
 print("EAST_BANK_UNDERLAY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
