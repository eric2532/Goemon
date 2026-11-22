extends Node
## Five prepared caster adapters, driven only by the existing native army owner.
const Pets=preload("res://scripts/forest/pet_catalog.gd")
var runtime
var casters:Dictionary={}
func _ready():set_process(false);set_physics_process(false)
func reconcile():
 var selected=Pets.sanitized(runtime.game.settings.forest_pet_loadout)
 var skills=Pets.sanitized_skills(runtime.game.settings.forest_pet_skills)
 for key in casters.keys():
  if key not in selected or not skills.has(key):casters[key].retire();casters[key].queue_free();casters.erase(key)
 for key in selected:
  var slots=Pets.skill_slots(skills,key)
  if skills.has(key) and not casters.has(key):
   var caster=preload("res://scripts/forest/pet_skill_caster.gd").new();caster.game=runtime.game;caster.runtime=runtime;caster.pet_key=key;caster.gate_id=runtime.HOUND_ID-Pets.skin(key);caster.team_progression=runtime.game.model.team_progression
   add_child(caster);casters[key]=caster
  var handle:int=runtime.handles.get(runtime.HOUND_ID-Pets.skin(key),0)
  if casters.has(key):
   casters[key].team_progression=runtime.game.model.team_progression
   casters[key].configure(slots)
   if handle:casters[key].bind_unit(handle)
  if handle:
   var assigned:bool=runtime.native.set_pet_skills(handle,Pets.skill_codes(slots),int(preload("res://scripts/spells/skill_balance.gd").effective(casters[key],Pets.Spells.COMBO,"count")) if casters.has(key) else 3)
   assert(assigned,"Invalid pet skill loadout")
func receive(event:Dictionary):
 var skin=runtime.HOUND_ID-int(event.source_id)
 if skin<0 or skin>=Pets.COUNT:return
 var caster=casters.get(Pets.key(skin))
 if caster!=null:caster.receive(event)
func step(delta:float):
 for caster in casters.values():caster.step(delta)
func retire(handle:int):
 for caster in casters.values():
  if caster.native_handle==handle:caster.retire()
func clear():
 for caster in casters.values():caster.retire()

func prepare_skill_count(id:String):
 for caster in casters.values():caster.prepare_skill_count(id)
