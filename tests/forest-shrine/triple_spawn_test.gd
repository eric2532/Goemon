extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func fresh():
	var model=Model.new();model.reset(42);model.start_wave();return model
func run():
	var m=fresh();m.waves.spawn_clock=0;m.waves.tick(.001,m.hero_position)
	check(m.enemies.size()==3 and m.waves.pending==69,"A due timer releases three enemies and consumes three pending arrivals")
	var actors=m.enemies.values()
	var separated=true
	for i in range(actors.size()):
		for j in range(i):separated=separated and actors[i].pos.distance_to(actors[j].pos)>=1.8
	check(separated,"The three arrivals occupy separate southern entries")
	for e in actors:e.stun=100
	m.waves.tick(.1,m.hero_position)
	check(m.enemies.size()==3,"The existing interval prevents an extra early batch")
	m.waves.tick(.55,m.hero_position)
	check(m.enemies.size()==6,"The next .65 second interval releases exactly three more")
	m=fresh();m.waves.pending=2;m.waves.spawn_clock=0;m.waves.tick(.001,m.hero_position)
	check(m.enemies.size()==2 and m.waves.pending==0,"A final partial batch never consumes nonexistent pending enemies")
	m=fresh();m.waves.pending=10
	for i in range(239):m.waves.spawn_enemy(0,Vector3(0,0,234)).stun=100
	m.waves.spawn_clock=0;m.waves.tick(.001,m.hero_position)
	check(m.enemies.size()==240 and m.waves.pending==9,"The final active slot admits one member of a batch")
	m.waves.spawn_clock=0;m.waves.tick(.001,m.hero_position)
	check(m.enemies.size()==240 and m.waves.pending==9,"An occupied active cap preserves all pending arrivals")
	m=fresh()
	for x in range(-40,40):
		for z in range(-40,40):m.visible_cells[Vector2i(x,z)]=true
	m.waves.spawn_clock=0;var start=Time.get_ticks_msec();m.waves.tick(.001,m.hero_position)
	check(m.enemies.is_empty() and m.waves.pending==72,"Fully watched entries defer the entire batch")
	check(Time.get_ticks_msec()-start<1000,"An unavailable batch returns after bounded retries")
	m=fresh();m.phase="preparing";m.wave=0
	for expected in [72,108,144,180,240]:
		m.start_wave();var count=0;var giants=0;var tries=0
		while m.waves.pending>0 and tries<1000:
			tries+=1;m.waves.spawn_batch()
			count+=m.enemies.size()
			for e in m.enemies.values():
				if e.variant==2:giants+=1
			m.enemies.clear()
		check(count==expected and m.waves.pending==0,"The complete wave releases %d enemies"%expected)
		check(giants==(1 if m.wave>=3 else 0),"Daruma remains a single giant in late waves")
		m.waves.tick(.001,m.hero_position)
	check(m.phase=="victory","All enlarged finite waves resolve to victory")
	print("FOREST_TRIPLE_SPAWN_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
