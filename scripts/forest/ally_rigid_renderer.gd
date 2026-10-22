extends Node3D
## Forward+ automatically GPU-instances identical rigid mesh/material surfaces.
## Share only the authored baseline materials; keep original mesh nodes, skins,
## transforms, visibility, shadows and per-instance LOD/culling entirely native.
## actor.gd retains its private material pointers for hit/power emission effects.
var enabled=true
var groups:Dictionary={}
var actors:Dictionary={}
var material_properties:Array[StringName]=[]

func _ready():
 name="AllyRigidRenderer";process_mode=Node.PROCESS_MODE_ALWAYS;process_priority=100
 var probe=StandardMaterial3D.new()
 for property in probe.get_property_list():
  var key:String=property.name
  if property.usage&PROPERTY_USAGE_STORAGE and not key.begins_with("resource_") and not key.begins_with("metadata/") and key!="script":material_properties.append(StringName(key))

func materials_equal(a:Material,b:Material)->bool:
 if not a is StandardMaterial3D or not b is StandardMaterial3D:return false
 for key in material_properties:
  if a.get(key)!=b.get(key):return false
 return true

func register_actor(actor:Node3D):
 var actor_id=actor.get_instance_id()
 if actors.has(actor_id):return
 var callback=unregister_actor.bind(actor_id)
 actors[actor_id]={"source":weakref(actor),"callback":callback}
 actor.tree_exiting.connect(callback)
 for source in actor.model.find_children("*","MeshInstance3D",true,false):
  if not source.mesh is ArrayMesh or source.skin!=null or source.mesh.get_blend_shape_count()>0:continue
  var active=[];var overrides=[];var emissions=[];var compatible=true
  for slot in source.mesh.get_surface_count():
   var mat=source.get_active_material(slot)
   var original=source.mesh.surface_get_material(slot)
   if not mat is StandardMaterial3D or mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or not materials_equal(mat,original):
    compatible=false;break
   active.append(mat);overrides.append(source.get_surface_override_material(slot));emissions.append([mat.emission_enabled,mat.emission,mat.emission_energy_multiplier])
  if not compatible or active.is_empty():continue
  var key=source.mesh.get_instance_id()
  if not groups.has(key):
   var shared=[]
   for mat in active:shared.append(mat.duplicate())
   groups[key]={"mesh":source.mesh,"shared":shared,"entries":[]}
  groups[key].entries.append({"source":weakref(source),"actor_id":actor_id,"materials":active,"overrides":overrides,"emissions":emissions,"blocked":false})

func _restore(entry:Dictionary,group:Dictionary):
 var source=entry.source.get_ref()
 if not is_instance_valid(source):return
 for slot in mini(entry.overrides.size(),source.get_surface_override_material_count()):
  # A later author owns any replacement, including an explicit null override.
  if source.get_surface_override_material(slot)==group.shared[slot]:source.set_surface_override_material(slot,entry.overrides[slot])

func sync():
 for group in groups.values():
  for entry in group.entries:
   var source=entry.source.get_ref()
   if not is_instance_valid(source):continue
   if not enabled or entry.blocked:
    _restore(entry,group);continue
   if source.mesh!=group.mesh or source.skin!=null:
    entry.blocked=true;_restore(entry,group);continue
   for slot in entry.overrides.size():
    var current=source.get_surface_override_material(slot)
    if current!=entry.overrides[slot] and current!=group.shared[slot]:
     entry.blocked=true;break
   if entry.blocked:_restore(entry,group);continue
   for slot in entry.materials.size():
    var mat:StandardMaterial3D=entry.materials[slot]
    # Full material equality is checked once above. The supported actor path
    # only animates these emission fields; setters do not emit Resource.changed
    # in Godot 4.6. Keep private effects per actor and rejoin after they reset.
    var baseline:Array=entry.emissions[slot]
    var unchanged=mat.emission_enabled==baseline[0] and mat.emission==baseline[1] and mat.emission_energy_multiplier==baseline[2]
    var desired=group.shared[slot] if unchanged else entry.overrides[slot]
    if source.get_surface_override_material(slot)!=desired:source.set_surface_override_material(slot,desired)

func set_enabled(value:bool):
 enabled=value;sync()

func unregister_actor(actor_id:int):
 if not actors.has(actor_id):return
 var actor=actors[actor_id].source.get_ref()
 if is_instance_valid(actor) and actor.tree_exiting.is_connected(actors[actor_id].callback):actor.tree_exiting.disconnect(actors[actor_id].callback)
 actors.erase(actor_id)
 for key in groups.keys():
  var group:Dictionary=groups[key]
  for index in range(group.entries.size()-1,-1,-1):
   if group.entries[index].actor_id!=actor_id:continue
   _restore(group.entries[index],group);group.entries.remove_at(index)
  if group.entries.is_empty():groups.erase(key)

func _process(_delta):
 if enabled:sync()

func _exit_tree():
 for actor_id in actors.keys():unregister_actor(actor_id)
