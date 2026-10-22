extends RefCounted
## Offline snapshots use the same idle drivers and equipment as playable models.
const HEROES=["goemon","edo","pirate","samurai","ninja","mage","knight","dragoon","magic-swordsman","ranger","explorer","master-thief"]
const SAMPLE_FRAMES=60
const STEP=1.0/60.0
static func create(id:int,parent:Node)->HeroModel:
 var model:HeroModel
 if id==1:model=load("res://scripts/hero_model.gd").new()
 elif id==2:model=load("res://assets/characters/musashi/model/musashi_model.gd").new()
 else:
  model=load("res://scripts/rogue_hero_model.gd").new();model.class_id=HEROES[id-1]
 parent.add_child(model)
 if id==1:model.ronin_scarf.hide()
 if id>=3:model.actor.seed=0
 manual(model)
 return model
static func manual(node:Node):
 node.set_process(false);node.set_physics_process(false)
 if node is AnimationPlayer:node.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 for child in node.get_children():manual(child)
static func sample(model:HeroModel):
 for frame in range(1,SAMPLE_FRAMES+1):
  model.animate(STEP,0,true,0,0,false,0,false)
  model.sync_skeleton()
static func skeleton(model:HeroModel)->Skeleton3D:
 return model.actor.cosplay_rig.skeleton if model.get("actor")!=null else model.skeleton
