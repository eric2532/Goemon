extends SceneTree
var checks=0
var failures=0
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const DIR="res://assets/characters/thirstquencher/"
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func run():
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"manifest.json"))
 check(manifest.variants.size()==3,"The three original soldier variants are present")
 for role in [0,1,3]:
  check(Soldier.hurt_bounds().has_point(Vector3(1.5,5.5,0)),"Scaled soldier body contact includes the enlarged upper torso")
  check(is_equal_approx(Roles.height(role),6.048) and is_equal_approx(Roles.footprint_radius(role),3.9),"Navigation dimensions fit the enlarged soldier body")
  var stats=Roles.stats(role)
  check(is_equal_approx(stats.stride,4.32 if role==1 else 6.912),"World stride fits the three-times-larger source gait")
  check(is_equal_approx(stats.speed,2.16 if role==1 else 4.32) and is_equal_approx(stats.damage,25.0 if role==1 else 11.0),"Enlarging soldiers preserves movement speed and attack damage")
  check(is_equal_approx(stats.range,24.0 if role==1 else 7.5),"Melee reach fits the larger body while gun range stays unchanged")
 check(Soldier.source_point(Vector3(0,-80,-48)).is_equal_approx(Vector3(0,4.32,-2.592)),"Source muzzle coordinates follow the enlarged drawn body")
 for variant in manifest.variants:
  var path=DIR+"soldier_%d_runtime.res"%int(variant.id)
  check(ResourceLoader.exists(path),"A batched source-motion resource exists for soldier%d"%int(variant.id))
  if not ResourceLoader.exists(path):continue
  var data=load(path)
  check(data.get_meta("source_sha256")==FileAccess.get_sha256(DIR+"manifest.json"),"Baked GPU poses match the current recovered manifest")
  check(data.get_meta("schema")==1 and data.get_meta("part_count")==11,"Runtime keeps all11sourceparts")
  var mesh:Mesh=data.get_meta("mesh");var poses:Array=data.get_meta("poses");var atlas:Image=data.get_meta("pose_texture").get_image()
  var clips:Dictionary=data.get_meta("clips")
  check(clips.size()==variant.clips.size(),"Every recovered numeric clip survives the runtime bake")
  var scene=load(variant.glb).instantiate();root.add_child(scene)
  var skeleton:Skeleton3D=scene.find_child("Skeleton3D",true,false);var player:AnimationPlayer=scene.find_child("AnimationPlayer",true,false)
  player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  var convert=Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*5.4),Vector3.ZERO)
  var exact=true;var atlas_exact=true
  for source in variant.clips:
   check(player.has_animation(source.name) and clips.has(source.name),"Original clip is accessible: "+source.name)
   var clip:Dictionary=clips[source.name]
   for tick in clip.rows.size():
    player.play(source.name);player.seek(float(tick)/30.0,true);skeleton.force_update_all_bone_transforms()
    var row=int(clip.rows[tick])
    for part in 11:
     var expected=convert*skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Part_%02d"%part))
     var actual:Transform3D=poses[row*11+part]
     if actual.origin.distance_to(expected.origin)>.0001 or not actual.basis.is_equal_approx(expected.basis):exact=false
     for axis in 3:
      var pixel=atlas.get_pixel(part*3+axis,row);var basis=Vector3(pixel.r,pixel.g,pixel.b)
      if basis.distance_to(actual.basis[axis])>.00001 or absf(pixel.a-actual.origin[axis])>.00001:atlas_exact=false
  check(exact,"All native animation ticks preserve the recovered GLB part matrices")
  check(atlas_exact,"GPU palette pixels preserve the exact CPU animation matrices")
  var vertices=0;var rigid=true
  for slot in mesh.get_surface_count():
   var arrays=mesh.surface_get_arrays(slot);vertices+=arrays[Mesh.ARRAY_VERTEX].size()
   for part in arrays[Mesh.ARRAY_TEX_UV2]:
    if part.x<0 or part.x>=11 or part.x!=roundf(part.x):rigid=false
   if arrays[Mesh.ARRAY_BONES]!=null and not arrays[Mesh.ARRAY_BONES].is_empty():rigid=false
  check(vertices>900 and rigid,"All original vertices are batched with their rigid sourcepartIDs")
  scene.queue_free();await process_frame
 print("THIRSTQUENCHER_ASSET_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
