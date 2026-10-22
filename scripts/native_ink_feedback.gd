extends Node
## One native cosmetic clock. Damage and projectile flight stay in their owners.
var game: Node
var fx: Node3D
var hero_id=-1
var quality=-1
func configure(owner: Node) -> void:
 game=owner;hero_id=game.player.character_id
 fx=preload("res://assets/rogue/scripts/effects.gd").new();add_child(fx)
 _settings()
func _settings() -> void:
 if quality!=int(game.settings.quality):quality=int(game.settings.quality);fx.apply_quality(quality)
 fx.reduced_flashes=game.settings.get("reduced_flashes",false)
func slash(point: Vector3,direction: Vector3,heavy: bool,combo: int,tint: Color,size: float,plane: float) -> void:
 _settings()
 var strokes=fx.items.filter(func(item):return item.kind=="slash")
 if strokes.size()>=[2,3,4][quality]:
  var old=strokes[0];fx._release_feedback(old);old.node.queue_free();fx.items.erase(old)
 var options={"style":"cleave" if heavy else "sword","height":0.0,"plane":(0.25 if combo%2 else -.25) if plane==9.0 else plane}
 fx.slash(point,atan2(direction.x,direction.z),combo,tint,(3.1 if heavy else 2.3)*size,options)
func impact(point: Vector3,direction: Vector3,strength: int,tint: Color,style: String="native") -> void:
 _settings()
 fx.weapon_impact(point-Vector3.UP,atan2(direction.x,direction.z),style,tint,strength>0)
func tick(delta: float) -> void:
 if not is_instance_valid(game) or not is_instance_valid(fx):return
 if hero_id!=game.player.character_id:clear();hero_id=game.player.character_id
 if game.player.hp<=0:clear();return
 if not game.playing or game.paused or game.transitioning:return
 _settings();fx.tick(delta)
func clear() -> void:
 if is_instance_valid(fx):fx.clear()
