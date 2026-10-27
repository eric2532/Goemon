extends RefCounted
## Original ally steering retained for comparison fixtures only.
var game
func primary_range(unit)->float:
 if unit.character_id==2:return 22.0
 if unit.character_id==14:return preload("res://scripts/recovered_ed_beam.gd").maximum_length(unit)*.9
 if unit.character_id in [1,13,15,16,17]:return unit.melee_strike_reach()*.8
 var combat=unit.active_ability
 if combat.class_id in ["ranger","mage"]:return 22.0
 if combat.player.attack!=null and combat.player.attack.get("weapon","")=="cutlass":return maxf(1.0,float(combat.player.attack.reach)*.8)
 return maxf(1.3,float(combat.Actions.PRIMARY.get(combat.class_id,{"reach":2.85}).reach)*unit.melee_reach_setting()*.72)
func use_special(unit,gap: float):
 if not unit.is_rogue_character():return
 var c=unit.active_ability;var p=c.player
 if p.travel!=null or p.attack!=null or p.roll>0:return
 c.secondary_held=false
 if p.blocking:
  p.blocking=false;p.guardTime=0.0
 if p.cooldowns.drink<=0 and p.buffTime<=0 and gap<22:c.action("drink")
 match c.class_id:
  "knight":
   # Hold the actual counter shield against a committed incoming strike.
   var threat=false
   for e in game.model.enemies.values():
    if e.action=="windup" and e.get("target_kind","")=="defender" and e.get("target_id",-1)==unit.gate_id:threat=true;break
   if threat and gap<8:c.secondary_held=true;c.action("flintlock")
  "master-thief":
   if unit.hp<unit.max_hp*.35 and gap<6 and p.cooldowns.flintlock<=0:c.secondary_held=true;c.action("flintlock")
  "ninja","explorer":
   if gap>4 and gap<12 and p.cooldowns.flintlock<=0:c.action("flintlock")
  "dragoon":
   if gap<7 and p.cooldowns.flintlock<=0:c.action("flintlock")
  "mage":
   if gap<7 and p.cooldowns.flintlock<=0:c.action("flintlock")
  "pirate","ranger","samurai","magic-swordsman":
   if gap<25 and p.cooldowns.flintlock<=0:c.action("flintlock")
 if c.class_id in ["ninja","samurai"] and gap>5 and gap<25 and p.cooldowns.roll<=0:c.action("roll")
func set_destination(unit,destination: Vector3):
 unit.ai_move=Vector3.ZERO
 if unit.position.distance_to(destination)<.65:return
 var m=game.model
 var start=m.nearest_open(m.cell_of(unit.position));var goal=m.nearest_open(m.cell_of(destination))
 if start.x==-999 or goal.x==-999:return
 if goal!=m.cell_of(destination):destination=m.point(goal)
 if unit.route_goal!=goal or unit.route_revision!=m.navigation_revision or unit.route.is_empty():
  unit.route=m.route(start,goal);unit.route_goal=goal;unit.route_revision=m.navigation_revision
 if unit.route.is_empty():return
 while unit.route.size()>1 and Vector2(unit.position.x-m.point(unit.route[0]).x,unit.position.z-m.point(unit.route[0]).z).length()<1.3:unit.route.pop_front()
 var point: Vector3=m.point(unit.route[0]) if unit.route.size()>1 else destination
 var direction=point-unit.position;direction.y=0
 if direction.length()>.5:unit.ai_move=direction.normalized()
