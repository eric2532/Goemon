extends RefCounted
## Shelter changes navigation/visibility; the ally keeps its identity and food.
var reference:WeakRef
var building_id=-1
var exit_point=Vector3.ZERO
var navigation_revision=-1
var retry_left=0.0
var combat=preload("res://scripts/forest/forest_bunker_combat.gd").new()
var unit:
	get:return reference.get_ref()
func _init(owner_:Node):
	reference=weakref(owner_);combat.reference=reference
func reset():
	building_id=-1;navigation_revision=-1;retry_left=0.0;combat.reset()
func tick(delta:float)->bool:
	var u=unit;var game=u.game;var m=game.model
	if game.ordinary_pause or game.settings_open or game.rogue_roster_open or game.transitioning or m.phase not in ["preparing","wave"] or (m.phase=="wave" and game.paused):return true
	if u.state=="sheltered":
		var b:Dictionary=m.buildings.get(building_id,{})
		if b.is_empty() or b.hp<=0:leave();return true
		u.hp=minf(u.max_hp,u.hp+10.0*delta)
		if u.hp>=u.max_hp:leave()
		elif m.phase=="wave":combat.tick(b,delta)
		else:combat.rest()
		return true
	if m.phase!="wave":return false
	if u.state=="bunker_leaping":
		combat.tick_leap(delta);return true
	retry_left=maxf(0,retry_left-delta)
	if u.state in ["prepared","appearing","acting","returning"] and u.hp>0 and u.hp<u.max_hp*.3 and retry_left<=0:
		retry_left=1.0
		var b=m.nearest_barracks(u.global_position)
		if not b.is_empty():
			building_id=b.id;exit_point=m.point(m.entry(b));navigation_revision=m.navigation_revision
			u.state="retreating";u.active_ability.cancel();u.active_ability.active=true
			u.auto_attack_enabled=false;u.ai_target=null;u.pending_thrust=false;u.opening=false
			u.director.remove_taunt(u);u.route.clear();u.route_goal=Vector2i(-999,-999)
	if u.state=="retreating":
		var b:Dictionary=m.buildings.get(building_id,{})
		if b.is_empty() or b.hp<=0:
			reset();u.state="acting";u.think_left=0;return false
		if navigation_revision!=m.navigation_revision:
			navigation_revision=m.navigation_revision
			if m.route(m.nearest_open(m.cell_of(u.global_position)),m.entry(b)).is_empty():
				reset();u.state="acting";u.think_left=0;return false
		if u.global_position.distance_to(exit_point)<1.5:
			u.state="sheltered";u.global_position=m.center(b);u.active_ability.player.pos=u.global_position
			u.velocity=Vector3.ZERO;u.ai_move=Vector3.ZERO;u.collision_layer=0;u.hide();combat.enter(b);u.director.sync_targets()
		else:u.game.gate_defenders.set_destination(u,exit_point)
		return true
	if u.state=="returning":
		# The exit is already clear ground. Resume hunting immediately instead
		# of crossing the battlefield back to the preparation placement.
		u.state="acting";u.think_left=0;return false
	return false
func leave():
	var u=unit;var m=u.game.model
	u.active_ability.interrupt_attack_for_movement()
	var cell=m.nearest_open(m.cell_of(exit_point))
	if cell.x==-999:cell=m.nearest_open(m.shrine_entry())
	if cell.x!=-999:u.global_position=m.point(cell)+Vector3.UP*.12
	u.active_ability.player.pos=u.global_position;u.velocity=Vector3.ZERO;u.ai_move=Vector3.ZERO
	u.collision_layer=2;u.show();u.route.clear();u.route_goal=Vector2i(-999,-999)
	u.state="returning";u.think_left=0;reset()
	if m.phase=="preparing":u.rest_between_waves()
	u.director.sync_targets()
