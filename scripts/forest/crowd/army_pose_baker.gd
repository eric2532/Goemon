extends RefCounted
## Shared original-pose sampler: offline default bake and bounded tuning refresh.
const FPS=60.0
func bake(unit,profile:Dictionary={})->Resource:
 var c=unit.active_ability;var actor=unit.model.actor
 unit.global_position=Vector3.ZERO;unit.facing=Vector3.BACK;unit.model.rotation.y=PI;unit.show();c.active=true;c.reset_run();actor.seed=0
 var source:Node3D=actor.model
 var inverse=unit.global_transform.affine_inverse()
 var palette=[];var nodes=[];var vertex_refs=[];var groups={};var properties=[]
 for node in source.find_children("*","MeshInstance3D",true,false):
  if node.mesh==null:continue
  var base=palette.size();var sk:Skeleton3D=node.get_node_or_null(node.skeleton) if not node.skeleton.is_empty() else null
  if node.skin!=null:
   assert(sk!=null,"Missing source skeleton for "+str(node.get_path()))
   for bind in node.skin.get_bind_count():palette.append({"path":source.get_path_to(node),"bind":bind})
  else:palette.append({"path":source.get_path_to(node),"bind":-1})
  nodes.append({"node":node,"skeleton":sk,"base":base,"count":node.skin.get_bind_count() if node.skin!=null else 1})
  for surface in node.mesh.get_surface_count():
   var original=node.get_active_material(surface) as StandardMaterial3D
   assert(original!=null,"Unexported ally material")
   assert(original.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and original.normal_texture==null and original.roughness_texture==null and original.metallic_texture==null,"Unexported ally surface flags or maps")
   var key=original.albedo_texture
   if not groups.has(key):groups[key]={"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"uv":PackedVector2Array(),"uv2":PackedVector2Array(),"colors":PackedColorArray(),"bones":PackedFloat32Array(),"weights":PackedFloat32Array(),"indices":PackedInt32Array(),"texture":key}
   var dest:Dictionary=groups[key];var a=node.mesh.surface_get_arrays(surface);var count:int=a[Mesh.ARRAY_VERTEX].size();var offset:int=dest.vertices.size();var material_index=properties.size()
   properties.append({"roughness":original.roughness,"metallic":original.metallic,"emission":original.emission.srgb_to_linear() if original.emission_enabled else Color.BLACK,"energy":original.emission_energy_multiplier if original.emission_enabled else 0.0,"specular":original.metallic_specular,"cull":original.cull_mode,"albedo":original.albedo_color.srgb_to_linear()})
   vertex_refs.append({"path":source.get_path_to(node),"surface":surface,"group":groups.keys().find(key),"offset":offset,"count":count})
   for v in count:
    dest.vertices.append(a[Mesh.ARRAY_VERTEX][v]);dest.normals.append(a[Mesh.ARRAY_NORMAL][v])
    var uv:Vector2=a[Mesh.ARRAY_TEX_UV][v] if a[Mesh.ARRAY_TEX_UV]!=null else Vector2.ZERO
    dest.uv.append(uv*Vector2(original.uv1_scale.x,original.uv1_scale.y)+Vector2(original.uv1_offset.x,original.uv1_offset.y));dest.uv2.append(Vector2(material_index,0))
    var color=Color.WHITE
    if original.vertex_color_use_as_albedo and a[Mesh.ARRAY_COLOR]!=null:color=a[Mesh.ARRAY_COLOR][v].srgb_to_linear() if original.vertex_color_is_srgb else a[Mesh.ARRAY_COLOR][v]
    dest.colors.append(color)
    for k in 4:
     dest.bones.append(float(base+a[Mesh.ARRAY_BONES][v*4+k]) if node.skin!=null else float(base))
     dest.weights.append(a[Mesh.ARRAY_WEIGHTS][v*4+k] if node.skin!=null else (1.0 if k==0 else 0.0))
   if a[Mesh.ARRAY_INDEX]!=null:
    for index in a[Mesh.ARRAY_INDEX]:dest.indices.append(offset+index)
   else:
    for index in count:dest.indices.append(offset+index)
 var mesh=ArrayMesh.new();var textures=[]
 for dest in groups.values():
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=dest.vertices;arrays[Mesh.ARRAY_NORMAL]=dest.normals;arrays[Mesh.ARRAY_TEX_UV]=dest.uv;arrays[Mesh.ARRAY_TEX_UV2]=dest.uv2;arrays[Mesh.ARRAY_COLOR]=dest.colors;arrays[Mesh.ARRAY_INDEX]=dest.indices
  arrays[Mesh.ARRAY_CUSTOM0]=dest.bones;arrays[Mesh.ARRAY_CUSTOM1]=dest.weights
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
  textures.append(dest.texture)
 var props=Image.create(3,properties.size(),false,Image.FORMAT_RGBAF)
 for i in properties.size():
  var p:Dictionary=properties[i];props.set_pixel(0,i,Color(p.roughness,p.metallic,p.energy,p.specular));props.set_pixel(1,i,Color(p.emission.r,p.emission.g,p.emission.b,p.cull));props.set_pixel(2,i,p.albedo)
 if profile.is_empty():profile=load("res://assets/crowd/army_kit_profiles.tres").get_meta("profiles")[unit.kit_id]
 var cadence=preload("res://scripts/user_stride_run.gd").cadence(profile.speed) if preload("res://scripts/user_stride_run.gd").enabled(actor.id) else preload("res://scripts/goemon_reference_run_body.gd").cadence(profile.speed)
 var definitions={"idle":{"duration":3.6,"loop":true},"walk":{"duration":2.4,"loop":true,"motion":1},"walk_back":{"duration":2.4,"loop":true,"motion":-1},"hurt":{"duration":.12},"death":{"duration":.1}}
 for sample in 6:
  for motion in [0,1,-1]:
   var suffix="" if motion==0 else ("_walk" if motion==1 else "_back")
   definitions["primary%d"%sample+suffix]={"duration":profile.primary[sample].duration,"primary":sample,"motion":motion}
 if unit.kit_id==5:definitions.shadow_cut={"duration":.30,"dash":true};definitions.shot={"duration":.2,"fan":true};definitions.shot_walk={"duration":.2,"fan":true,"motion":1};definitions.shot_back={"duration":.2,"fan":true,"motion":-1}
 if unit.kit_id==7:
  definitions.guard={"duration":2.4,"loop":true,"guard":true};definitions.guard_walk={"duration":2.4,"loop":true,"guard":true,"motion":1};definitions.guard_back={"duration":2.4,"loop":true,"guard":true,"motion":-1}
 if unit.kit_id==8:
  definitions.lance_leap={"duration":.72,"leap":true};definitions.lance_landing={"duration":.8,"landing":true};definitions.lance_sweep={"duration":.84,"sweep":true}
  definitions.jump={"duration":.4,"jump":true};definitions.fall={"duration":.4,"fall":true}
 if unit.kit_id==10:
  for motion in [0,1,-1]:definitions["ranger_fan"+("" if motion==0 else ("_walk" if motion==1 else "_back"))]={"duration":.2,"fan":true,"motion":motion}
 var clips={};var row_count=0
 for key in definitions:
  var d:Dictionary=definitions[key]
  if d.get("loop",false) and d.get("motion",0)!=0:d.duration=1.0/cadence;d.warmup=2.0
  d.count=ceili(float(d.duration)*FPS)+1;d.start=row_count;row_count+=d.count;clips[key]=d
 var image=Image.create(palette.size()*6,row_count,false,Image.FORMAT_RGBAF)
 var contacts={};var muzzles={}
 for key in clips:
  var d:Dictionary=clips[key]
  c.reset_run();actor.seed=0;c.player.pos=Vector3.ZERO;c.player.angle=0;c.aim=Vector3.BACK*10;unit.facing=Vector3.BACK;unit.model.rotation.y=PI
  if d.has("primary"):
   var sample=int(d.primary);c.player.bladeSide=profile.primary[sample].get("swingSide",1);c.player.rangerShots=sample
   c.Actions.begin_attack(c,c.Actions.primary_config(c,sample%3),sample%3)
  elif d.get("sweep",false):c.Actions.begin_attack(c,{"duration":.84,"contact":.22,"damage":111,"reach":7.2,"arc":PI/2,"style":"dragoon-sweep","sweep_hits":0},0,"flintlock")
  if d.get("warmup",0)>0:
   var warm:Dictionary=c.player.duplicate(true);warm.graphicsQuality=0;warm.grounded=true;warm.vertical=0;warm.flip=-1;warm.landing=0;warm.motionSpeed=profile.speed;warm.localMotion=Vector3.BACK*profile.speed*d.motion
   if d.get("guard",false):warm.blocking=true;warm.guardTime=1
   for frame in roundi(d.warmup*60):actor.animate_pose(warm,1.0/60,(frame+1)/60.0,1)
   actor.locomotion.phase=0
  var points=PackedVector3Array();var hands=PackedVector3Array()
  for frame in int(d.count):
   var t=frame/FPS;var dt=1.0/FPS if frame>0 else 0.0
   var state:Dictionary=c.player.duplicate(true);state.graphicsQuality=0;state.grounded=true;state.vertical=0;state.flip=-1;state.landing=0
   var movement=float(d.get("motion",0));var speed=float(profile.speed)*absf(movement)
   state.localMotion=Vector3.BACK*speed*signf(movement);state.motionSpeed=speed
   if state.attack is Dictionary:state.attack.time=minf(t,float(state.attack.duration));state.meleeVisualScale=state.attack.get("meleeVisualScale",1.0)
   if d.get("guard",false):state.blocking=true;state.guardTime=1.0
   if d.get("fan",false):state.shot=maxf(.00001,.2-t)
   if d.get("dash",false):
    state.rollDuration=.14;state.roll=maxf(0,.14-t);state.rollStyle="dash-cut";state.dashAttack={"style":"dash-cut","weaponScale":1.0,"effectScale":1.0} if t<.14 else null
   if d.get("leap",false):state.grounded=false;state.vertical=-38;state.travel={"kind":"lance-leap","phase":"aimed-drop","duration":.72,"time":t,"height":0.0}
   if d.get("jump",false):state.grounded=false;state.vertical=20.0
   if d.get("fall",false):state.grounded=false;state.vertical=-38.0
   if d.get("landing",false):
    if frame==0:
     var prior=state.duplicate(true);prior.grounded=false;prior.vertical=-38;prior.travel={"kind":"lance-leap","phase":"aimed-drop","duration":.72,"time":.72,"height":0.0};actor.animate_pose(prior,0,0,0)
    state.landing=maxf(.00001,.8-t)
   actor.animate_pose(state,dt,t,absf(movement))
   var hidden=key=="death"
   var cursor=0
   for entry in nodes:
    var node:MeshInstance3D=entry.node;var sk:Skeleton3D=entry.skeleton
    if node.skin!=null:sk.force_update_all_bone_transforms()
    for bind in int(entry.count):
     var pose:Transform3D=inverse*node.global_transform
     if node.skin!=null:
      var bone=node.skin.get_bind_bone(bind)
      if bone<0:bone=sk.find_bone(node.skin.get_bind_name(bind))
      pose=inverse*sk.global_transform*sk.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind)
     if hidden or not node.is_visible_in_tree():pose=Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.ZERO)
     put_pose(image,cursor,int(d.start)+frame,pose);cursor+=1
   hands.append(inverse*unit.model.hand_position("R"))
   var weapon:Node3D=actor.joints.Weapon_Cutlass.node
   points.append(inverse*(weapon.global_transform*actor.WEAPON_AXES.get(actor.id,Vector3.UP)))
  contacts[key]=points;muzzles[key]=hands
 var resource=Resource.new();resource.set_meta("kind",unit.kit_id);resource.set_meta("fps",FPS);resource.set_meta("mesh",mesh);resource.set_meta("textures",textures);resource.set_meta("properties",ImageTexture.create_from_image(props));resource.set_meta("palette",palette);resource.set_meta("vertex_refs",vertex_refs);resource.set_meta("clips",clips);resource.set_meta("contacts",contacts);resource.set_meta("muzzles",muzzles);resource.set_meta("pose_texture",ImageTexture.create_from_image(image))
 var hashes={};fingerprint("res://assets/rogue/scripts/actor.gd",hashes);fingerprint("res://scripts/rogue_roster_combat.gd",hashes)
 fingerprint("res://assets/models/characters/goemon_cosplay/"+actor.id+".glb",hashes)
 for name_ in DirAccess.get_files_at("res://assets/animations"):
  if name_.ends_with(".json"):hashes["res://assets/animations/"+name_]=FileAccess.get_sha256("res://assets/animations/"+name_)
 resource.set_meta("source_hashes",hashes);return resource
func put_pose(image:Image,part:int,row:int,pose:Transform3D):
 var normal=pose.basis.inverse().transposed() if absf(pose.basis.determinant())>.000001 else Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
 for i in 3:
  var axis:Vector3=pose.basis[i];var n:Vector3=normal[i]
  image.set_pixel(part*6+i,row,Color(axis.x,axis.y,axis.z,pose.origin[i]));image.set_pixel(part*6+i+3,row,Color(n.x,n.y,n.z,0))
func fingerprint(path:String,hashes:Dictionary):
 if hashes.has(path) or not FileAccess.file_exists(path):return
 hashes[path]=FileAccess.get_sha256(path)
 for reference in ResourceLoader.get_dependencies(path):
  var dep=str(reference).get_slice("::",2) if str(reference).contains("::") else str(reference)
  if dep.begins_with("res://"):fingerprint(dep,hashes)
