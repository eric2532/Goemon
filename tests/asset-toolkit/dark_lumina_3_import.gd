extends SceneTree
const Finale=preload("res://scripts/forest/dark_lumina_3_kit.gd")
const OUT="res://build/Other Files/Asset Toolkit/Dark Lumina 3/"
func _initialize():run.call_deferred()
func run():
 Finale.prepare()
 for mesh in Finale.meshes.values():assert(mesh!=null and mesh.get_surface_count()>0)
 var wind_image:Image=Finale.meshes.wind.surface_get_material(0).get_shader_parameter("pose_texture").get_image()
 var first=wind_image.get_pixel(0,0);var next=wind_image.get_pixel(0,25)
 var known_vertex=false
 for x in wind_image.get_width():
  var v=wind_image.get_pixel(x,0)
  known_vertex=known_vertex or Vector3(v.r,v.g,v.b).distance_to(Vector3(-51,30,7)*.018*Finale.SCALE)<.0001
 assert(known_vertex,"The original morph endpoint survives Godot vertex reordering")
 assert(first!=next,"Wind vertex morph advances")
 var native=Finale.native();var text="inline void finale_fixture(army::KitData& k){\n"
 for key in native:
  if key=="finale_scale":text+="k.finale_scale="+str(native[key])+";\n";continue
  var values=[]
  for v in native[key]:values.append(str(v))
  text+="k."+key+"={"+",".join(values)+"};\n"
 FileAccess.open(OUT+"finale_kit.h",FileAccess.WRITE).store_string(text+"}\n")
 for name_ in ["dark_lumina_3","dark_lumina_3_sky_copy"]:
  var raw=load("res://assets/characters/recovered_monsters/"+name_+".glb").instantiate()
  var edited=load("res://assets/models/enemies/recovered_monsters/"+name_+".glb").instantiate()
  root.add_child(raw);root.add_child(edited)
  var a:AnimationPlayer=raw.find_child("AnimationPlayer",true,false);var b:AnimationPlayer=edited.find_child("AnimationPlayer",true,false)
  a.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;b.callback_mode_process=a.callback_mode_process
  var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/recovered_monsters/"+name_+"_motion.json"))
  for clip in manifest.clips:
   a.play(clip.name);b.play(clip.name)
   for frame in clip.frames:
    a.seek(frame.tick/30.0+.00001,true);b.seek(frame.tick/30.0+.00001,true)
    for part in manifest.parts:
     var left:Transform3D=raw.find_child(part.name,true,false).global_transform
     var right:Transform3D=edited.find_child(part.name,true,false).global_transform
     assert(left.origin.distance_to(right.origin)<.0001,"Authored pose translation changed")
     for axis in 3:assert(left.basis[axis].distance_to(right.basis[axis])<.0001,"Authored pose rotation changed")
  raw.free();edited.free()
 var balance=preload("res://scripts/forest/core_balance.gd")
 var old=[120,120,120,0,0,0,0,1]
 var migrated=balance.sanitized({"waves":[old]})
 assert(migrated.waves[0].slice(0,8)==old and migrated.waves[0][8]==0 and migrated.waves[0][9]==0)
 print("DARK_LUMINA_3_IMPORT_PASS original_poses=all meshes=",Finale.meshes.size()," wave_migration=ok")
 quit()
