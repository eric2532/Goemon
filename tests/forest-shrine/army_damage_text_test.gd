extends SceneTree
## Army popup admission must retain live cuts/trails and the combat RNG stream.
const Effects=preload("res://assets/rogue/scripts/effects.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,note: String):
	checks+=1;print("PASS: " if ok else "FAIL: ",note)
	if not ok:failures+=1
func effects(parent: Node,army: bool,budget: int=4):
	var fx=Effects.new();fx.army_trails=army;fx.effect_budget=budget;parent.add_child(fx);return fx
func arrow()->Dictionary:
	return {"color":Color("ffd487"),"rangeScale":1.0,"power":false,"vel":Vector3(0,0,60)}
func expected_next(seed_value: int,calls: int)->float:
	seed(seed_value)
	for i in calls:randf_range(-.25,.25);randf_range(-.24,.24)
	return randf()
func run():
	var game=Node3D.new();root.add_child(game)
	var fx=effects(game,true)
	var weapon=Node3D.new();game.add_child(weapon)
	var blades=[{"node":weapon,"axis":Vector3.RIGHT}]
	var attack={"contact":.1,"duration":.4,"time":.1,"index":0}
	fx.weapon_brush_sample(attack,blades,Color.WHITE)
	var first=arrow();var second=arrow()
	fx.ranger_trail(first,Vector3.ZERO,Vector3.BACK);fx.ranger_trail(second,Vector3.RIGHT,Vector3.RIGHT+Vector3.BACK)
	var initial=fx.damage(Vector3.ZERO,"ANBU STRIKE","crit")
	var retained=fx.items.map(func(item):return item.node)
	check(fx.items.size()==4 and initial is Label3D,"Fixture fills the four-item army pool with a live cut, two trails and a popup")
	var allocations={"labels":0}
	fx.child_entered_tree.connect(func(node):
		if node is Label3D:allocations.labels+=1)
	var want_next=expected_next(73415,250);seed(73415)
	var all_denied=true
	for i in 250:
		var result=fx.damage(Vector3.ZERO,"ANBU STRIKE","crit")
		all_denied=all_denied and result==null
	var actual_next=randf()
	check(all_denied and allocations.labels==0 and fx.get_child_count()==4,"Two hundred fifty damage calls at capacity allocate no new labels or deferred-free children")
	var stable=fx.items.size()==4
	for i in retained.size():stable=stable and is_instance_valid(retained[i]) and not retained[i].is_queued_for_deletion() and fx.items[i].node==retained[i]
	check(stable,"Denied text preserves the existing cut, trails and popup instead of evicting the small army pool")
	check(actual_next==want_next,"Every capacity-denied popup still consumes exactly the original two cosmetic random draws")
	weapon.position=Vector3.UP*.1;attack.time=.12;fx.weapon_brush_sample(attack,blades,Color.WHITE)
	fx.ranger_trail(first,Vector3.BACK,Vector3.BACK*2)
	check(not attack.magicBrush.node.is_queued_for_deletion() and is_equal_approx(attack.magicBrush.sampleTime,.12) and not first.rangerTrail.node.is_queued_for_deletion() and (first.rangerTrail.node.transform*Vector3.BACK).is_equal_approx(Vector3.BACK*2),"A full pool keeps updating its admitted blade brush and actual Ranger trail")
	var siblings_parent=Node3D.new();root.add_child(siblings_parent)
	var siblings=[]
	for i in 24:siblings.append(effects(siblings_parent,true))
	want_next=expected_next(84261,24);seed(84261)
	var admitted=0
	for sibling in siblings:
		if sibling.damage(Vector3.ZERO,"ANBU STRIKE","crit")!=null:admitted+=1
	actual_next=randf()
	var sibling_labels=0
	for sibling in siblings:sibling_labels+=sibling.get_child_count()
	check(admitted==4 and sibling_labels==4,"Twenty-four sibling ally effect pools share a four-popup displayed-frame admission limit")
	check(actual_next==want_next,"A mixed admitted and shared-limit-denied popup sequence preserves the next combat random roll")
	var separate_game=Node3D.new();root.add_child(separate_game)
	var separate=effects(separate_game,true)
	check(separate.damage(Vector3.ZERO,"ANBU STRIKE","crit")!=null,"A separate game owns an independent army popup admission counter")
	var human=effects(siblings_parent,false,2)
	var normal=human.damage(Vector3.ONE,37.4)
	var critical=human.damage(Vector3.ZERO,"ANBU STRIKE","crit")
	var player=human.damage(Vector3.ZERO,12,"player")
	check(normal!=null and critical!=null and player!=null and normal.is_queued_for_deletion() and human.items.size()==2,"Human popups bypass exhausted army admission and preserve ordinary oldest-effect eviction")
	check(normal.text=="37" and critical.text=="ANBU STRIKE" and critical.font_size==86 and player.font_size==68 and normal.font_size==58,"Human numeric formatting, critical text and native type sizes remain unchanged")
	check(critical.modulate==Color("ffe4a9") and player.modulate==Color("ff8e80") and critical.no_depth_test and critical.billboard==BaseMaterial3D.BILLBOARD_ENABLED and critical.outline_size==10 and is_equal_approx(critical.pixel_size,.0065),"Human popup colors, billboard, depth and outline styling remain unchanged")
	seed(1957);var offset=randf_range(-.25,.25);var drift=randf_range(-.24,.24);want_next=randf();seed(1957)
	var ordinary=human.damage(Vector3(4,5,6),8)
	actual_next=randf()
	check(ordinary.position.is_equal_approx(Vector3(4+offset,7.1,6)) and human.items.back().drift==drift and is_equal_approx(human.items.back().life,.85) and actual_next==want_next,"Human popup position, drift, lifetime and exact two-draw RNG progression remain unchanged")
	var displayed_frame=Engine.get_process_frames()
	while Engine.get_process_frames()==displayed_frame:await process_frame
	check(siblings[23].damage(Vector3.ZERO,"ANBU STRIKE","crit")!=null,"A new displayed frame restores ally popup admission")
	for sibling in siblings:sibling.clear()
	fx.clear();human.clear();separate.clear();game.queue_free();siblings_parent.queue_free();separate_game.queue_free()
	await process_frame;await process_frame
	print("ARMY_DAMAGE_TEXT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
