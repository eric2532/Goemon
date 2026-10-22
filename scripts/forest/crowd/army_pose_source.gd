extends "res://scripts/player.gd"
## Temporary source for authored pose/tuning samples; never an army combat unit.
var director:Node
var kit_id=5
var slot=0
var gate_id=-999999
func _setup_initial_model():
 ensure_character(kit_id);model=character_models[kit_id]
func ensure_character(id:int):
 if id!=kit_id or character_models.has(id):return
 var visual=preload("res://scripts/rogue_hero_model.gd").new()
 visual.class_id=RogueRoster.class_id(id);add_child(visual);character_models[id]=visual
 var ability=preload("res://scripts/forest/summoned_ally_combat.gd").new()
 ability.hero=self;ability.game=game;add_child(ability);character_abilities[id]=ability;visual.combat=ability
 ability.configure(self,visual.class_id);ability.sync_actor(visual.actor);visual.hide();visual.set_process(false)
func refresh_max_health(_heal_growth:bool=false):
 max_hp=float(director.HEALTH[slot]);hp=minf(hp,max_hp)
func _ready():
 ai_controlled=true;super._ready();select_character(kit_id)
 active_ability.fx.apply_quality(0);active_ability.fx.effect_budget=16;active_ability.fx.army_trails=true
 set_process(false);set_physics_process(false)
