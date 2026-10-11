extends SceneTree
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)
	else:print("PASS: ",message)
func run():
	var fx=load("res://assets/rogue/scripts/effects.gd").new();root.add_child(fx)
	fx.particles(Vector3.ZERO,Color.RED,24,1)
	var batches=fx.find_children("*","MultiMeshInstance3D",true,false)
	check(batches.size()==1,"An impact burst uses one batched particle draw instead of individual spark nodes")
	if not batches.is_empty():
		# The headless Dummy renderer has no MultiMesh transform readback.
		var headless=DisplayServer.get_name()=="headless"
		var before=fx.items[0].sparks[0].position if headless else batches[0].multimesh.get_instance_transform(0).origin
		fx.tick(.1)
		var after=fx.items[0].sparks[0].position if headless else batches[0].multimesh.get_instance_transform(0).origin
		check(before!=after,"Batched sparks travel during the combat clock")
	fx.tick(1);await process_frame
	check(fx.items.is_empty(),"Batched bursts expire and release their scene nodes")
	check(fx.has_method("apply_quality"),"Combat effects support the existing graphics quality setting")
	if fx.has_method("apply_quality"):
		fx.apply_quality(0);fx.particles(Vector3.ZERO,Color.RED,48,1)
		batches=fx.find_children("*","MultiMeshInstance3D",true,false)
		check(batches.size()==1 and batches[0].multimesh.instance_count<=6,"Low quality caps a large impact at six sparks")
		fx.clear();await process_frame
		for i in range(220):fx.slash(Vector3.ZERO,0,0,Color.RED,1)
		check(fx.items.size()<=180,"Sustained effects cannot exceed the Low quality budget")
	fx.clear();await process_frame
	check(fx.items.is_empty() and fx.get_child_count()==0,"Hero interruption clears all transient VFX")
	fx.apply_quality(1)
	for i in range(24):fx.weapon_impact(Vector3.ZERO,0,"sword",Color.RED,false)
	batches=fx.find_children("*","MultiMeshInstance3D",true,false)
	check(batches.size()<=8,"A crowd contact caps impact visuals per combat frame without capping damage")
	fx.clear();await process_frame
	for quality in [0,1,2]:
		fx.apply_quality(quality)
		for i in range(24):
			fx.particles(Vector3.ZERO,Color.ORANGE,18,1.6)
			fx.ring(Vector3.ZERO,Color.ORANGE,1.8,.3)
		batches=fx.find_children("*","MultiMeshInstance3D",true,false)
		var rings=0
		for item in fx.items:
			if item.kind=="ring":rings+=1
		check(batches.size()==[3,8,12][quality],"Piercing spells admit only the quality budget of spark batches per combat frame")
		check(rings==[3,8,12][quality],"Piercing spells cap ring allocation before reaching the live effect limit")
		fx.tick(.02)
		fx.particles(Vector3.ZERO,Color.ORANGE,18,1.6)
		fx.ring(Vector3.ZERO,Color.ORANGE,1.8,.3)
		check(fx.items.size()==2*[3,8,12][quality],"Catch-up physics steps cannot multiply feedback allocations inside one display frame")
		await process_frame
		fx.particles(Vector3.ZERO,Color.ORANGE,18,1.6)
		fx.ring(Vector3.ZERO,Color.ORANGE,1.8,.3)
		check(fx.items.size()==2*([3,8,12][quality]+1),"A new display frame restores spell feedback admission")
		fx.clear();await process_frame
		fx.particles(Vector3.ZERO,Color.ORANGE,18,1.6)
		fx.ring(Vector3.ZERO,Color.ORANGE,1.8,.3)
		check(fx.items.size()==2,"Interruption clears spell admission counters with the effects")
		fx.clear();await process_frame
	for quality in [0,1,2]:
		fx.apply_quality(quality)
		for frame in range(8):
			for i in range(24):
				fx.weapon_impact(Vector3.ZERO,0,"sword",Color.RED,false)
				fx.particles(Vector3.ZERO,Color.ORANGE,18,1.6)
				fx.ring(Vector3.ZERO,Color.ORANGE,1.8,.3)
			await process_frame
		var count={"impact":0,"particle-burst":0,"ring":0}
		for item in fx.items:
			if count.has(item.kind):count[item.kind]+=1
		check(count.impact<=[6,12,18][quality] and count["particle-burst"]<=[6,12,18][quality] and count.ring<=[6,12,18][quality],"Sustained feedback has a live budget independent of the total effect pool")
		fx.tick(1);await process_frame
		fx.particles(Vector3.ZERO,Color.RED,4,1)
		fx.ring(Vector3.ZERO,Color.RED,1,.2)
		fx.weapon_impact(Vector3.ZERO,0,"sword",Color.RED,false)
		check(fx.items.size()>=3,"Expiry restores live feedback admission")
		fx.clear();await process_frame
	for quality in [0,1,2]:
		fx.apply_quality(quality)
		for i in range(100):fx.streak(Vector3.ZERO,Vector3.FORWARD,Color.RED,.1,.2)
		check(fx.items.size()==[8,16,24][quality],"Projectile trails cap allocations per displayed frame")
		fx.tick(.02)
		for i in range(100):fx.streak(Vector3.ZERO,Vector3.FORWARD,Color.RED,.1,.2)
		check(fx.items.size()==[8,16,24][quality],"Catch-up projectile ticks share the trail admission budget")
		for frame in range(5):
			await process_frame
			for i in range(100):fx.streak(Vector3.ZERO,Vector3.FORWARD,Color.RED,.1,.2)
		check(fx.items.size()==[16,32,48][quality],"Projectile trails have a separate live ceiling")
		fx.tick(1);await process_frame
		fx.streak(Vector3.ZERO,Vector3.FORWARD,Color.RED,.1,.2)
		check(fx.items.size()==1,"Trail expiry restores admission")
		fx.clear();await process_frame
	fx.apply_quality(1)
	var arrow={"color":Color.WHITE,"rangeScale":1.0}
	for i in range(20):fx.ranger_trail(arrow,Vector3.FORWARD*i,Vector3.FORWARD*(i+1))
	check(fx.items.size()==1 and arrow.rangerTrail.node.mesh.get_surface_count()>0,"Ranger preserves its reusable flight trail independently of cosmetic streak limits")
	fx.clear();await process_frame
	fx.queue_free();await process_frame
	print("COMBAT_VFX_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
