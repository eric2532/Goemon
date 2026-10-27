extends "res://scripts/player.gd"
## A real roster character controlled through world-space intent, never input.
var gate_id=-1
var post=Vector3.ZERO
var recovery_left=0.0
var route: Array=[]
var route_goal=Vector2i(-999,-999)
var route_revision=-1
var route_left=0.0
var name_tag: Label3D
var director: Node
var _loading_defaults=false
func ensure_character(id: int):
 # The gate roster selects its kit during preparation, after this bootstrap.
 if _loading_defaults and id!=1:return
 if not RogueRoster.is_rogue(id):
  super.ensure_character(id);return
 if character_models.has(id):return
 var visual=preload("res://scripts/rogue_hero_model.gd").new()
 visual.class_id=RogueRoster.class_id(id);add_child(visual);character_models[id]=visual
 var ability=preload("res://scripts/forest/summoned_ally_combat.gd").new()
 ability.hero=self;ability.game=game;add_child(ability);character_abilities[id]=ability;visual.combat=ability
 ability.configure(self,visual.class_id);ability.sync_actor(visual.actor)
 ability.fx.army_trails=true
 visual.hide();visual.set_process(false)
func _ready():
 ai_controlled=true
 director=game.explorer_helpers
 _loading_defaults=true
 super._ready()
 _loading_defaults=false
 name_tag=Label3D.new();name_tag.name="DefenderName";name_tag.position.y=3.0;name_tag.font_size=28;name_tag.pixel_size=.008;name_tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED;name_tag.modulate=Color("b1e6df");add_child(name_tag)
func _physics_process(delta):
 if game.model.phase!="wave" or game.paused or hp<=0:return
 if is_instance_valid(ai_target) and not ai_target.dead:
  ai_aim=AttackChain.aim_point(ai_target,global_position+Vector3.UP)
  if attack_left<=0:facing=combat_attack_direction()
 else:
  ai_target=null;auto_attack_enabled=false
 invuln=maxf(0,invuln-delta)
 super._physics_process(delta)
func take_hit(amount: float,direction: Vector3,projectile: bool=false):
 if hp<=0 or invuln>0:return
 if active_ability!=null:
  if active_ability.protects_player():return
  if is_rogue_character():amount=active_ability.filter_damage(amount,direction,projectile)
 if amount<=0:return
 hp=maxf(0,hp-amount*game.tuning.enemy_damage);invuln=.35
 if hp<=0:
  recovery_left=15.0;auto_attack_enabled=false;ai_target=null;ai_move=Vector3.ZERO;velocity=Vector3.ZERO
  if active_ability!=null:active_ability.cancel()
  quick_attacks.cancel();attack_left=0;hide()
func restore_at_post():
 if active_ability!=null:active_ability.cancel()
 attack_chain.reset();hp=max_hp;invuln=0;recovery_left=0;velocity=Vector3.ZERO;ai_move=Vector3.ZERO;ai_target=null;auto_attack_enabled=false
 global_position=post+Vector3.UP*.15;route.clear();route_goal=Vector2i(-999,-999);show();model.show()
func set_defender_label(label_: String):
 name_tag.text=label_+" · "+(RogueRoster.name_for(character_id) if is_rogue_character() else ROSTER[character_id].name)
