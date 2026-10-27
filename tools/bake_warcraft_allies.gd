extends SceneTree
## Original Blademaster skin/actions in the existing native army pose-atlas format.
const Baker=preload("res://scripts/forest/crowd/army_pose_baker.gd")
const Model=preload("res://scripts/warcraft_model.gd")
func _initialize():run.call_deferred()
func run():
 var model=Model.new();root.add_child(model);model.rotation.y=PI
 var helper=Baker.new();var palette=[];var textures=[];var modes=[];var properties=[];var mesh=ArrayMesh.new();var vertex_refs=[]
 var billboard_names=preload("res://scripts/warcraft_effects.gd").data().billboards["31"]
 var upright_names=preload("res://scripts/warcraft_effects.gd").data().upright["31"]
 for node:MeshInstance3D in model.meshes:
  var sk:Skeleton3D=node.get_node(node.skeleton)
  var surface=node.mesh.surface_get_arrays(0);var count:int=surface[Mesh.ARRAY_VERTEX].size();var binds={};var groups={}
  for v in count:
   for k in 4:
    if surface[Mesh.ARRAY_WEIGHTS][v*4+k]<=0:continue
    var bind=int(surface[Mesh.ARRAY_BONES][v*4+k]);var bone=node.skin.get_bind_bone(bind)
    if bone<0:bone=sk.find_bone(node.skin.get_bind_name(bind))
    if not binds.has(bind):binds[bind]=palette.size();palette.append({"node":node,"skeleton":sk,"bind":bind,"bone":bone})
   var b=int(surface[Mesh.ARRAY_BONES][v*4]);var bone=node.skin.get_bind_bone(b)
   if bone<0:bone=sk.find_bone(node.skin.get_bind_name(b))
   if surface[Mesh.ARRAY_WEIGHTS][v*4]>.999 and sk.get_bone_name(bone) in billboard_names:
    if not groups.has(b):groups[b]=[]
    groups[b].append(v)
  var centers={}
  for b in groups:
   var center=Vector3.ZERO
   for v in groups[b]:center+=surface[Mesh.ARRAY_VERTEX][v]
   centers[b]=center/groups[b].size()
  var bones=PackedFloat32Array();var weights=PackedFloat32Array();var centers_data=PackedFloat32Array();var offsets=PackedFloat32Array();var uv2=PackedVector2Array()
  for v in count:
   uv2.append(Vector2(textures.size(),0))
   for k in 4:
    var bind=int(surface[Mesh.ARRAY_BONES][v*4+k]);bones.append(binds.get(bind,0));weights.append(surface[Mesh.ARRAY_WEIGHTS][v*4+k])
   var b=int(surface[Mesh.ARRAY_BONES][v*4]);var billboard=centers.has(b) and surface[Mesh.ARRAY_WEIGHTS][v*4]>.999
   var center:Vector3=centers.get(b,Vector3.ZERO);var offset:Vector3=(surface[Mesh.ARRAY_VERTEX][v]-center)*model.rig_visual.scale.x
   var bone=node.skin.get_bind_bone(b)
   if bone<0:bone=sk.find_bone(node.skin.get_bind_name(b))
   centers_data.append_array(PackedFloat32Array([center.x,center.y,center.z,(2 if sk.get_bone_name(bone) in upright_names else 1) if billboard else 0]));offsets.append_array(PackedFloat32Array([-offset.z,offset.y,0,0]))
  surface[Mesh.ARRAY_BONES]=null;surface[Mesh.ARRAY_WEIGHTS]=null;surface[Mesh.ARRAY_CUSTOM0]=bones;surface[Mesh.ARRAY_CUSTOM1]=weights;surface[Mesh.ARRAY_CUSTOM2]=centers_data;surface[Mesh.ARRAY_CUSTOM3]=offsets;surface[Mesh.ARRAY_TEX_UV2]=uv2
  var flags=0
  for shift in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]:flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<shift
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface,[],{},flags)
  var mat:StandardMaterial3D=node.material_override;textures.append(mat.albedo_texture);modes.append(mat.blend_mode==BaseMaterial3D.BLEND_MODE_ADD);properties.append(mat.albedo_color)
  vertex_refs.append({"mesh":node.name,"vertices":count})
 var definitions={"idle":"Stand","walk":"Walk","spin":"Attack Walk Stand Spin","primary0":"Attack","primary1":"Attack 2","primary2":"Attack Slam"};var clips={};var rows=0
 for key in definitions:
  var duration=model.animation_player.get_animation(definitions[key]).length
  var count=ceili(duration*60)+1
  clips[key]={"start":rows,"count":count,"duration":duration,"loop":key in ["idle","walk","spin"]};rows+=count
 var image=Image.create(palette.size()*6,rows,false,Image.FORMAT_RGBAF)
 for key in definitions:
  var clip:Dictionary=clips[key]
  for frame in int(clip.count):
   model.pose(definitions[key],frame/60.0);model.skeleton.force_update_all_bone_transforms()
   for i in palette.size():
    var p:Dictionary=palette[i]
    var transform_:Transform3D=p.skeleton.global_transform*p.skeleton.get_bone_global_pose(p.bone)*p.node.skin.get_bind_pose(p.bind)
    helper.put_pose(image,i,int(clip.start)+frame,transform_)
    var value=image.get_pixel(i*6+3,int(clip.start)+frame);value.a=p.node.material_override.albedo_color.a if p.node.visible else 0.0;image.set_pixel(i*6+3,int(clip.start)+frame,value)
 clips.walk_back=clips.walk;clips.hurt=clips.idle;clips.shadow_cut=clips.spin
 for i in 6:
  for suffix in ["","_walk","_back"]:clips["primary%d"%i+suffix]=clips["primary%d"%(i%3)]
 var props=Image.create(3,properties.size(),false,Image.FORMAT_RGBAF)
 for i in properties.size():props.set_pixel(2,i,Color(properties[i].r,properties[i].g,properties[i].b,1))
 var resource=Resource.new();resource.set_meta("kind",31);resource.set_meta("mesh",mesh);resource.set_meta("textures",textures);resource.set_meta("glows",modes);resource.set_meta("properties",ImageTexture.create_from_image(props));resource.set_meta("pose_texture",ImageTexture.create_from_image(image));resource.set_meta("clips",clips);resource.set_meta("fps",60);resource.set_meta("vertex_refs",vertex_refs)
 resource.set_meta("palette",palette.map(func(p):return {"mesh":p.node.name,"bone":p.bone,"bind":p.bind}))
 var hashes={}
 for path in ["res://tools/bake_warcraft_allies.gd","res://scripts/forest/crowd/army_pose_baker.gd","res://scripts/warcraft_model.gd","res://assets/characters/warcraft/blademaster/motion.json","res://assets/characters/warcraft/effects/sources.json",GameAssets.model_path("res://assets/models/characters/warcraft/blademaster/blademaster.glb")]:helper.fingerprint(path,hashes)
 resource.set_meta("source_hashes",hashes)
 assert(ResourceSaver.save(resource,"res://assets/characters/ally_crowd/31.res")==OK)
 print("WARCRAFT_ARMY_BAKE palette=",palette.size()," rows=",rows," surfaces=",mesh.get_surface_count());quit()
