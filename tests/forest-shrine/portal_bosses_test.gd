extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Layout="res://assets/maps/forest_four_gates.json"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func fresh(config:Dictionary={}):
	var m=Model.new();m.reset(42,config,JSON.parse_string(FileAccess.get_file_as_string(Layout)));m.start_wave();return m
func run():
	var m=fresh({"waves":[[2,1,5,3]]})
	check(m.waves.boss_pending is Dictionary and m.waves.boss_pending.is_empty(),"Portal boss queue remains available but is empty in soldiers-only planning")
	check(m.waves.pending==6 and m.waves.remaining_counts==[2,1,0,3],"Eight portals schedule only the configured six ordinary soldiers")
	check(m.balance.waves[0]==[2,1,5,3] and m.balance.bosses_per_portal==1,"Stored giant and portal-boss settings remain editable")
	var counts=[0,0,0,0,0]
	for attempt in 40:
		m.waves.spawn_batch()
		for enemy in m.enemies.values():counts[enemy.variant]+=1
		m.enemies.clear()
		if m.waves.pending==0:break
	check(counts==[2,1,0,3,0],"Portal releases preserve all three ordinary types without giants or bosses")
	check(m.waves.pending==0 and m.waves.boss_pending.is_empty(),"Only successful ordinary releases consume the pending queue")
	m=fresh({"waves":[[2,1,4,3]]})
	for i in 240:m.waves.spawn_enemy(0,Vector3.ZERO)
	check(m.waves.spawn_batch()==0 and m.waves.pending==6 and m.waves.boss_pending.is_empty(),"An occupied active cap preserves every ordinary arrival")
	m.enemies.erase(m.enemies.keys()[0]);m.waves.spawn_batch()
	check(m.enemies.size()==240 and m.waves.pending==5,"A soldier uses the final active slot without exceeding240")
	m=fresh({"waves":[[2,1,2,3]]})
	for portal in m.portals:
		var cell=m.cell_of(m.waves.routes.exit_point(portal,0))
		for x in range(-4,5):
			for z in range(-4,5):m.trees[cell+Vector2i(x,z)]=1.0
	m.rebuild_navigation();m.waves.spawn_clock=0;m.waves.tick(.01,m.hero_position)
	check(m.enemies.is_empty() and m.waves.pending==6 and m.waves.boss_pending.is_empty() and m.phase=="wave","Blocked portal exits preserve ordinary pending counts and prevent early victory")
	m.trees.clear();m.rebuild_navigation()
	for attempt in 8:
		m.waves.spawn_batch()
		for e in m.enemies.values():e.pos=Vector3.ZERO
	check(m.enemies.size()==6 and m.waves.pending==0,"Previously blocked ordinary arrivals spawn after clearance is restored")
	m.enemies.clear();m.waves.tick(.01,m.hero_position)
	check(m.phase=="victory","Final wave completes after all soldiers are defeated")
	m=fresh({"waves":[[1,0,4,1],[0,2,5,1]]})
	for attempt in 8:m.waves.spawn_batch();m.enemies.clear()
	m.waves.tick(.01,m.hero_position)
	check(m.phase=="preparing" and m.wave==1 and m.start_wave() and m.waves.boss_pending.is_empty() and m.waves.pending==3,"Every new wave schedules its own ordinary composition without portal bosses")
	check(m.balance.waves==[[1,0,4,1],[0,2,5,1]],"Advancing waves preserves suppressed legacy counts")
	m=fresh({"waves":[[0,0,9,0]]});m.waves.tick(.01,m.hero_position)
	check(m.phase=="victory" and m.waves.pending==0 and m.waves.boss_pending.is_empty(),"A giant-only saved wave with enabled boss settings completes without stalling")
	m=fresh({"bosses_per_portal":0,"waves":[[0,0,0,0]]});m.waves.tick(.01,m.hero_position)
	check(m.phase=="victory" and m.waves.boss_pending.is_empty(),"Empty waves still complete with bosses disabled")
	var legacy=Model.new();legacy.reset(42,{"waves":[[0,0,0,0]]});legacy.start_wave();legacy.waves.tick(.01,legacy.hero_position)
	check(legacy.phase=="victory","Maps without authored portals have no unspawnable special queues")
	# Explicit manual spawns retain legacy geometry and configurable stats.
	m=fresh({"boss_health":30000,"boss_speed":1.25,"waves":[[0,0,0,0]]})
	var boss=m.waves.spawn_enemy(4,Vector3(60,0,60))
	check(boss.variant==4 and boss.hp==90000 and boss.max_hp==90000,"Manual boss health combines configured base HP and shared multiplier")
	var shapes=Contact.shapes(4);var bounds=Contact.bounds(boss)
	check(shapes.size()==1 and shapes[0].shape is ConvexPolygonShape3D and shapes[0].planes.size()==6 and bounds.size.y>=10,"The boss uses one fitted block with just six contact planes")
	var center=boss.pos+Vector3.UP*5
	check(not Contact.segment_contact(boss,center+Vector3(0,0,20),center-Vector3(0,0,20),.1).is_empty(),"Projectile paths intersect the visible boss block")
	check(Contact.segment_contact(boss,center+Vector3(0,20,20),center+Vector3(0,20,-20),.1).is_empty(),"Projectiles above the block miss instead of hitting an oversized capsule")
	check(Roles.stats(4).speed<Roles.stats(0).speed*.4 and Roles.height(4)>Roles.height(0)*1.5,"Manual bosses remain larger and much slower than enlarged soldiers")
	for portal in range(8):
		m=fresh({"boss_speed":1.25,"waves":[[0,0,0,0]]})
		var point=m.waves.routes.exit_point(m.portals[portal],4);point.y=m.surface_height(point.x,point.z)
		var e=m.waves.spawn_enemy(4,point);e.facing=atan2(-m.waves.routes.direction(m.portals[portal]).x,-m.waves.routes.direction(m.portals[portal]).z);e.road_path=m.waves.routes.guidance(point,4)
		var supported=true;var speed=0.0
		for step in 2400:
			var previous:Vector3=e.pos;m.waves.tick_enemy(e,.2,Vector3(0,0,18))
			supported=supported and absf(e.pos.y-m.surface_height(e.pos.x,e.pos.z))<.001 and m.terrain.step_clear(previous,e.pos)
			speed=maxf(speed,e.pos.distance_to(previous)/.2)
			if maxf(absf(e.pos.x),absf(e.pos.z))<68:break
		check(maxf(absf(e.pos.x),absf(e.pos.z))<68 and e.pos.y<5 and supported,"Boss %d follows its raised wall route down to the gate"%portal)
		check(speed>1.2 and speed<=1.501,"Boss %d obeys configured speed plus shared movement scaling on slopes and corners"%portal)
	finish()
func finish():
	print("PORTAL_BOSSES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
