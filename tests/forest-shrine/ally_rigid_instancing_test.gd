extends SceneTree
const Actor=preload("res://assets/rogue/scripts/actor.gd")
const Renderer=preload("res://scripts/forest/ally_rigid_renderer.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func _initialize():run.call_deferred()
func rigid(actor)->Array:
 return actor.model.find_children("*","MeshInstance3D",true,false).filter(func(node):return node.skin==null and node.mesh is ArrayMesh and node.mesh.get_blend_shape_count()==0)
func owned(renderer,source)->bool:
 for group in renderer.groups.values():
  for entry in group.entries:
   if entry.source.get_ref()==source:return source.get_surface_override_material(0)==group.shared[0]
 return false
func run():
 var renderer=Renderer.new();root.add_child(renderer);renderer.set_process(false)
 var actors=[];var native_layers={};var native_skins={};var native_transforms={};var native_overrides={}
 for kind in ["dragoon","ranger","ninja","knight","explorer"]:
  for index in 2:
   var actor=Actor.new();root.add_child(actor);actor.setup(kind)
   actor.position=Vector3(index*7,0,actors.size()*4);actor.rotation.y=index*.37
   actor.animate_pose({"grounded":true,"isPlayer":true},.016,index*.4,0);actors.append(actor)
   for mesh in actor.model.find_children("*","MeshInstance3D",true,false):
    native_layers[mesh]=mesh.layers;native_transforms[mesh]=mesh.global_transform
    native_overrides[mesh]=[]
    for slot in mesh.mesh.get_surface_count():native_overrides[mesh].append(mesh.get_surface_override_material(slot))
    if mesh.skin!=null:native_skins[mesh]=mesh.skin
   renderer.register_actor(actor)
 renderer.sync()
 check(renderer.groups.size()==8,"All five kits share exactly their eight rigid equipment meshes")
 check(renderer.groups.values().all(func(group):return group.has("shared")),"Native equipment uses shared material resources for automatic GPU instancing")
 if failures:renderer.free();for_free(actors);quit(1);return
 check(renderer.get_child_count()==0,"Native instancing needs no replacement draw nodes or LOD approximation")
 var materials_match=true;var surfaces=0;var identities_match=true
 for group in renderer.groups.values():
  surfaces+=group.shared.size()
  for entry in group.entries:
   var source=entry.source.get_ref()
   for slot in group.shared.size():
    materials_match=materials_match and renderer.materials_equal(entry.materials[slot],group.shared[slot])
    identities_match=identities_match and source.get_active_material(slot)==group.shared[slot]
 check(surfaces==29 and materials_match,"All twenty-nine material surfaces retain every baseline property")
 check(identities_match,"Copies of each equipment surface share one GPU material identity")
 check(native_layers.keys().all(func(mesh):return mesh.layers==native_layers[mesh] and mesh.global_transform==native_transforms[mesh]),"Every source render layer and animated world transform stays unchanged")
 check(native_skins.keys().all(func(mesh):return mesh.skin==native_skins[mesh] and mesh.get_surface_override_material(0)==native_overrides[mesh][0]),"Skinned body and cape surfaces retain their private native resources")
 var ninja=actors[4];var sibling=actors[5];var weapon=rigid(ninja)[0]
 weapon.get_parent().hide();renderer.sync()
 check(not weapon.is_visible_in_tree() and weapon.visible,"Authored weapon hiding remains native and retains its own visible flag")
 weapon.get_parent().show();ninja.hide();renderer.sync()
 check(rigid(ninja).all(func(mesh):return not mesh.is_visible_in_tree()),"Parked or dead hidden actors retain native visibility")
 ninja.show();ninja.position+=Vector3(4,2,-3);ninja.animate_pose({"grounded":true,"isPlayer":true,"attack":{"style":"cutlass","duration":.4,"contact":.12,"time":.12,"index":0}},.016,1,0);renderer.sync()
 check(rigid(ninja).all(func(mesh):return owned(renderer,mesh)),"A moved and reused ally keeps shared equipment materials")
 ninja.flash_hit(Color.RED,1.1);ninja.animate_pose({"grounded":true},.016,1.1,0);renderer.sync()
 check(rigid(ninja).all(func(mesh):return mesh.get_surface_override_material(0)==native_overrides[mesh][0]),"Private hit flashes immediately restore original equipment materials")
 check(rigid(sibling).all(func(mesh):return owned(renderer,mesh) and mesh.get_active_material(0).emission==native_overrides[mesh][0].emission),"One ally's hit flash never changes a sibling's shared baseline")
 ninja.animate_pose({"grounded":true},.2,1.3,0);renderer.sync()
 check(rigid(ninja).all(func(mesh):return owned(renderer,mesh)),"Reset emission rejoins native automatic instancing")
 ninja.animate_pose({"grounded":true,"buffTime":1.0},.2,1.5,0);renderer.sync()
 check(rigid(ninja).all(func(mesh):return mesh.material_overlay==ninja.ultimate_aura.body_material),"An active ultimate overlay remains attached to original equipment")
 ninja.animate_pose({"grounded":true},.2,1.7,0);renderer.sync()
 check(rigid(ninja).all(func(mesh):return owned(renderer,mesh) and mesh.material_overlay==null),"Clearing a temporary aura leaves the correct shared baseline")
 var replacement=native_overrides[weapon][0].duplicate();weapon.set_surface_override_material(0,replacement);renderer.sync()
 check(weapon.get_surface_override_material(0)==replacement,"An external surface replacement is never overwritten")
 var changed=Actor.new();root.add_child(changed);changed.setup("ranger")
 var changed_mesh=rigid(changed)[0];var purple=changed_mesh.get_surface_override_material(0);purple.albedo_color=Color.PURPLE
 renderer.register_actor(changed);renderer.sync()
 check(changed_mesh.get_surface_override_material(0)==purple and not owned(renderer,changed_mesh),"A nonbaseline material is never merged into another actor's batch")
 changed.free()
 var knight_mesh=rigid(actors[6])[0]
 knight_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;knight_mesh.layers=4;knight_mesh.lod_bias=2.5;renderer.sync()
 check(knight_mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED and knight_mesh.layers==4 and knight_mesh.lod_bias==2.5,"Authored shadow, layer, and distance-detail changes stay native")
 var old_mesh=rigid(actors[2])[0];old_mesh.mesh=BoxMesh.new();renderer.sync()
 check(old_mesh.mesh is BoxMesh,"An external geometry replacement remains authoritative")
 renderer.set_enabled(false)
 check(native_overrides.keys().filter(func(mesh):return mesh!=old_mesh and mesh!=weapon).all(func(mesh):return mesh.get_surface_override_material(0)==native_overrides[mesh][0]),"Disabling restores all original private material resources")
 check(weapon.get_surface_override_material(0)==replacement,"Disabling preserves an externally replaced override")
 renderer.set_enabled(true);renderer.sync()
 check(rigid(sibling).all(func(mesh):return owned(renderer,mesh)),"Enabling restores shared baseline materials")
 var group_count=renderer.groups.size();actors[0].free();actors.remove_at(0)
 check(renderer.groups.size()==group_count,"Freeing one actor keeps the other actor's shared materials")
 renderer.free()
 check(actors.all(func(actor):return rigid(actor).filter(func(mesh):return mesh!=old_mesh and mesh!=weapon).all(func(mesh):return mesh.get_surface_override_material(0)==native_overrides[mesh][0])),"Renderer disposal restores every surviving owned material")
 check(weapon.get_surface_override_material(0)==replacement,"Renderer disposal preserves external material ownership")
 for_free(actors)
 print("ALLY_RIGID_INSTANCING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func for_free(actors:Array):
 for actor in actors:actor.free()
