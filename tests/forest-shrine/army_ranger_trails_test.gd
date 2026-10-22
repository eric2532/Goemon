extends SceneTree
const Effects=preload("res://assets/rogue/scripts/effects.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,label_: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func arrow(power: bool=false,scale_: float=1.0)->Dictionary:
	return {"color":Color("42f5a4") if power else Color("ffd487"),"rangeScale":scale_,"power":power,"vel":Vector3(0,0,60),"life":2.0,"damage":101 if power else 67}
func endpoints(node: Node3D,tail: Vector3,head: Vector3)->bool:
	return (node.transform*Vector3.ZERO).is_equal_approx(tail) and (node.transform*Vector3.BACK).is_equal_approx(head)
func run():
	var fx=Effects.new();root.add_child(fx)
	check(fx.get("army_trails")==false,"Army optimization is opt-in for existing human and gate-defender trails")
	var native=arrow();fx.ranger_trail(native,Vector3.ZERO,Vector3.BACK)
	var native_mesh=native.rangerTrail.node.mesh
	check(native_mesh is ImmediateMesh and native.rangerTrail.points.size()==2,"Default trail retains its native curved point history and ImmediateMesh")
	fx.ranger_trail(native,Vector3.BACK,Vector3(1,0,2))
	check(native.rangerTrail.node.mesh==native_mesh and native.rangerTrail.points.size()==3,"Native trail keeps appending actual curved flight samples")
	fx.clear();await process_frame
	if fx.get("army_trails")==null:
		check(false,"Effects offers the army trail mode");fx.queue_free();await process_frame;finish();return
	fx.army_trails=true
	var normal=arrow();var power=arrow(true,2)
	var normal_state=normal.duplicate(true);var power_state=power.duplicate(true)
	fx.ranger_trail(normal,Vector3.ZERO,Vector3.BACK)
	fx.ranger_trail(power,Vector3.ZERO,Vector3.BACK)
	var item: Dictionary=normal.rangerTrail;var powered: Dictionary=power.rangerTrail
	var node: MeshInstance3D=item.node;var mesh: ArrayMesh=node.mesh;var material=node.material_override
	check(mesh is ArrayMesh and powered.node.mesh==mesh,"All normal and power arrows share one immutable ArrayMesh")
	var arrays=mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_INDEX].size()==12 and arrays[Mesh.ARRAY_COLOR].size()==8,"Shared geometry is two crossed ribbons with a vertex fade gradient")
	check(arrays[Mesh.ARRAY_COLOR][0].a==0 and arrays[Mesh.ARRAY_COLOR][2].a==1,"Ribbon fades from transparent tail to opaque head")
	check(not item.has("points") and not powered.has("points"),"Army arrows retain no per-tick point history")
	check(endpoints(node,Vector3.ZERO,Vector3.BACK),"First normal trail spans only the distance already flown")
	check(is_equal_approx(node.basis.x.length(),.014) and is_equal_approx(item.life,.14),"Normal arrow keeps native width and tail lifetime")
	check(is_equal_approx(powered.node.basis.x.length(),.11) and is_equal_approx(powered.life,.26),"Power arrow keeps native width scaled by range and longer lifetime")
	check(material.get_shader_parameter("ink_tint")==normal.color and material.get_shader_parameter("use_vertex_alpha")==true,"Army trail preserves projectile color and uses its spatial fade")
	check(powered.node.material_override.get_shader_parameter("ink_tint")==power.color,"Power arrows retain their distinct green trail color")
	for step in range(1,121):
		fx.tick(1.0/60)
		fx.ranger_trail(normal,Vector3(0,0,step),Vector3(0,0,step+1))
		fx.ranger_trail(power,Vector3(0,0,step),Vector3(0,0,step+1))
	check(node.mesh==mesh and powered.node.mesh==mesh and node.material_override==material and fx.items.size()==2,"Many flight ticks reuse both trail nodes, geometry and materials")
	check(mesh.surface_get_arrays(0)==arrays,"Flight updates never rebuild or mutate shared mesh surfaces")
	check(endpoints(node,Vector3(0,0,112.6),Vector3(0,0,121)),"Normal tail length follows native .14-second history at sixty metres per second")
	check(endpoints(powered.node,Vector3(0,0,105.4),Vector3(0,0,121)),"Power tail length follows native .26-second history")
	var contact=Vector3(.15,.2,121.35)
	fx.ranger_trail(normal,Vector3(0,0,121),contact)
	check((node.transform*Vector3.BACK).is_equal_approx(contact),"Trail head ends exactly at native collision contact on a curved final segment")
	check(is_equal_approx(node.basis.x.length(),.014) and is_equal_approx(node.basis.y.length(),.014),"Changing flight direction retains both crossed ribbon widths")
	var still=node.transform;var life=item.life;fx.tick(0)
	check(node.transform==still and item.life==life,"A zero combat-clock tick preserves trail pose and lifetime")
	var normal_after=normal.duplicate();normal_after.erase("rangerTrail")
	var power_after=power.duplicate();power_after.erase("rangerTrail")
	check(normal_after==normal_state and power_after==power_state,"Trail updates preserve native projectile movement, lifetime and damage state")
	fx.tick(.15);await process_frame
	check(not is_instance_valid(node) and fx.items.size()==1,"Normal tail expires after its final .14-second contact sample")
	fx.tick(.12);await process_frame
	check(fx.items.is_empty(),"Power tail expires after its final .26-second sample")
	fx.ranger_trail(normal,contact,contact+Vector3.BACK)
	check(fx.items.size()==1 and normal.rangerTrail.node.mesh==mesh,"An expired trail restarts safely using the shared mesh")
	fx.clear();await process_frame
	check(fx.items.is_empty() and fx.get_child_count()==0,"Clear releases every army trail node")
	fx.effect_budget=3
	var arrows=[];var admitted_nodes=[];var admitted_materials=[]
	for i in range(20):
		var pr=arrow();arrows.append(pr);fx.ranger_trail(pr,Vector3.ZERO,Vector3.BACK)
		if i<3:
			admitted_nodes.append(pr.rangerTrail.node);admitted_materials.append(pr.rangerTrail.node.material_override)
	# Catch-up physics can revisit every arrow many times before deferred frees
	# or an effect-clock tick. A full trail pool must not churn nodes/materials.
	for step in range(1,61):
		for pr in arrows:fx.ranger_trail(pr,Vector3.BACK*step,Vector3.BACK*(step+1))
	check(fx.items.size()==3 and fx.get_child_count()==3,"Twenty arrows over sixty catch-up ticks allocate only three admitted trail nodes")
	var stable=true
	for i in range(3):
		stable=stable and is_instance_valid(admitted_nodes[i]) and not admitted_nodes[i].is_queued_for_deletion() and arrows[i].rangerTrail.node==admitted_nodes[i] and admitted_nodes[i].material_override==admitted_materials[i] and admitted_nodes[i].mesh==mesh
	check(stable,"Full army trail capacity preserves the first three nodes, materials and shared geometry")
	check(not arrows[19].has("rangerTrail"),"Arrows beyond the cosmetic budget receive no trail allocation")
	var feedback_denied=true
	for i in range(60):
		feedback_denied=feedback_denied and fx.ring(Vector3.ZERO,Color.WHITE,1,.5)==null
		feedback_denied=feedback_denied and fx.weapon_impact(Vector3.ZERO,0,"sword",Color.WHITE)==null
		feedback_denied=feedback_denied and fx.streak(Vector3.ZERO,Vector3.BACK)==null
		fx.particles(Vector3.ZERO,Color.WHITE,12)
	check(feedback_denied and fx.get_child_count()==3,"A full army pool rejects optional rings, impacts, streaks and particles before node allocation")
	check(not admitted_nodes[0].is_queued_for_deletion() and fx.items.size()==3,"New optional army feedback preserves existing admitted cosmetic effects")
	fx.tick(.15);await process_frame
	fx.ranger_trail(arrows[19],Vector3.BACK*61,Vector3.BACK*62)
	check(fx.items.size()==1 and arrows[19].has("rangerTrail") and arrows[19].rangerTrail.node.mesh==mesh,"Trail expiry opens admission for an arrow previously denied by capacity")
	var native_fx=Effects.new();native_fx.effect_budget=2;root.add_child(native_fx)
	var native_arrows=[]
	for i in range(3):
		var pr=arrow();native_arrows.append(pr);native_fx.ranger_trail(pr,Vector3.ZERO,Vector3.BACK)
	check(native_fx.items.size()==2 and native_arrows[0].rangerTrail.node.is_queued_for_deletion(),"Ordinary Ranger trails preserve native oldest-effect eviction")
	check(native_fx.ring(Vector3.ZERO)!=null,"Human optional feedback retains ordinary admission at the effect budget")
	native_fx.clear();native_fx.queue_free()
	var brush_fx=Effects.new();brush_fx.army_trails=true;brush_fx.effect_budget=1;root.add_child(brush_fx)
	var weapon=Node3D.new();root.add_child(weapon)
	var blades=[{"node":weapon,"axis":Vector3.RIGHT}]
	var attack={"contact":.1,"duration":.4,"time":.1,"index":0}
	brush_fx.weapon_brush_sample(attack,blades,Color.WHITE)
	var ribbon=attack.magicBrush.node
	var next_attack={"contact":.1,"duration":.4,"time":.1,"index":1}
	weapon.position=Vector3.UP*.1
	brush_fx.weapon_brush_sample(next_attack,blades,Color.WHITE,true)
	check(not next_attack.has("magicBrush") and not ribbon.is_queued_for_deletion() and brush_fx.get_child_count()==1,"New accelerated army cuts cannot evict a live brush when the cosmetic pool is full")
	attack.time=.12;brush_fx.weapon_brush_sample(attack,blades,Color.WHITE)
	check(attack.magicBrush.node==ribbon and is_equal_approx(attack.magicBrush.sampleTime,.12),"Existing live army brushes continue sampling while the pool is full")
	brush_fx.clear();brush_fx.queue_free();weapon.queue_free()
	# Many helpers own separate Effects objects. They must still share geometry
	# while retaining independent colors, lifetimes and transforms per arrow.
	var other=Effects.new();other.army_trails=true;root.add_child(other)
	var volley=[];var materials=[]
	for i in range(60):
		var pr=arrow(i%3==0);volley.append(pr)
		other.ranger_trail(pr,Vector3(i,0,0),Vector3(i,0,1))
		materials.append(pr.rangerTrail.node.material_override)
	for step in range(1,61):
		other.tick(1.0/60)
		for i in range(volley.size()):other.ranger_trail(volley[i],Vector3(i,0,step),Vector3(i,0,step+1))
	check(other.items.size()==60 and volley.all(func(pr):return pr.rangerTrail.node.mesh==mesh),"Sixty active arrows across helper Effects share the same immutable geometry")
	var retained=true
	for i in range(volley.size()):retained=retained and volley[i].rangerTrail.node.material_override==materials[i]
	check(retained and mesh.surface_get_arrays(0)==arrays,"A sustained army volley reuses materials and never rewrites mesh arrays")
	other.clear();other.queue_free()
	fx.clear();fx.queue_free();await process_frame
	await geometry_and_burst_rules()
	finish()
func geometry_and_burst_rules():
	var a=Effects.new();a.army_trails=true;root.add_child(a)
	var b=Effects.new();b.army_trails=true;root.add_child(b)
	var human=Effects.new();root.add_child(human)
	var spear=a._spear(2,.25,.1);var diamond=a._diamond(2,.25);var ring=a._ring_geometry(2,.1,PI,16)
	check(spear==b._spear(2,.25,.1) and diamond==b._diamond(2,.25) and ring==b._ring_geometry(2,.1,PI,16),"Army effects share identical immutable spear, diamond and ring geometry across units")
	check(spear.get_aabb().size.is_equal_approx(Vector3(.5,.2,2)) and diamond.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][2]==Vector3(1,0,0) and diamond.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][1]==Vector3(0,.25,0),"Shared army geometry retains requested literal dimensions")
	check(spear!=b._spear(3,.25,.1) and diamond!=b._diamond(3,.25) and ring!=b._ring_geometry(3,.1,PI,16),"Different cosmetic dimensions receive distinct shared geometry")
	check(human._spear(2,.25,.1)!=spear and human._diamond(2,.25)!=diamond and human._ring_geometry(2,.1,PI,16)!=ring,"Human geometry remains outside the shared army cache")
	var red=a._mesh(spear,Color.RED);var green=b._mesh(spear,Color.GREEN)
	red.position=Vector3.ONE;red.material_override.set_shader_parameter("fade",.2)
	check(red.mesh==green.mesh and red.material_override!=green.material_override and green.position==Vector3.ZERO and is_equal_approx(green.material_override.get_shader_parameter("fade"),1),"Sharing geometry preserves independent materials and transforms per effect")
	red.free();green.free();a.queue_free();b.queue_free();human.queue_free();await process_frame
	var army=[]
	for i in range(48):
		var unit=Effects.new();unit.army_trails=true;root.add_child(unit);army.append(unit)
		unit.weapon_impact(Vector3.ZERO,0,"sword",Color.WHITE)
		unit.particles(Vector3.ZERO,Color.WHITE,6)
		unit.ring(Vector3.ZERO)
		unit.streak(Vector3.ZERO,Vector3.BACK)
	var totals={"impact":0,"particle-burst":0,"ring":0,"streak":0}
	for unit in army:
		for item in unit.items:
			if totals.has(item.kind):totals[item.kind]+=1
	check(totals.impact==12 and totals["particle-burst"]==12 and totals.ring==12 and totals.streak==24,"One game/display frame bounds optional burst allocations independently of 48 army units")
	var native=Effects.new();root.add_child(native)
	check(native.ring(Vector3.ZERO)!=null,"An exhausted army frame budget leaves human feedback admission unchanged")
	var separate_game=Node3D.new();root.add_child(separate_game)
	var separate=Effects.new();separate.army_trails=true;separate_game.add_child(separate)
	check(separate.ring(Vector3.ZERO)!=null,"A separate game parent has an independent army feedback frame budget")
	await process_frame
	check(army[47].ring(Vector3.ZERO)!=null,"A new displayed frame restores shared army optional feedback admission")
	for unit in army:unit.clear();unit.queue_free()
	native.clear();native.queue_free();separate.clear();separate_game.queue_free();await process_frame
func finish():
	print("ARMY_RANGER_TRAILS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
