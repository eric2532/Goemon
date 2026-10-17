extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func south(point: Vector3)->bool:return point.z>absf(point.x) and point.z>42
func run():
	for seed_value in [42,90824,91919,123456]:
		var m=Model.new();m.reset(seed_value)
		var gate=m.buildings.values().filter(func(b):return b.kind=="gate")[0]
		check(m.center(gate).z>0,"The single gate faces the southern approach")
		for expected in [72,108,144,180,240]:
			check(m.start_wave(),"Each of the five waves can begin")
			var spawned=0;var giants=0;var directions_ok=true;var attempts=0
			while m.waves.pending>0 and attempts<1000:
				attempts+=1;m.waves.spawn_one()
				for e in m.enemies.values():
					spawned+=1;directions_ok=directions_ok and south(e.pos)
					if e.variant==2:giants+=1
				m.enemies.clear()
			check(directions_ok,"Every enemy, including Daruma, starts on the south/gate side")
			check(spawned==expected and m.waves.pending==0,"Southern entries preserve the complete finite wave count")
			check(giants==(1 if m.wave>=3 else 0),"Waves three through five still include one giant")
			m.waves.tick(.1,m.hero_position)
		check(m.phase=="victory","All five south-only waves can resolve to victory")
	# Scouting the center lane must never send a giant to another forest edge.
	var watched=Model.new();watched.reset(42);watched.wave=2;watched.start_wave()
	for x in range(-40,40):
		for z in range(-40,40):
			if absi(x)<30 or z<34:watched.visible_cells[Vector2i(x,z)]=true
	var choices=watched.waves.giant_staging()
	check(not choices.is_empty(),"Far southern entries remain available when the central lane is watched")
	check(choices.all(func(p):return south(p) and watched.waves.navigation.full_unseen(p,2)),"Every giant fallback stays south and outside full-footprint sight")
	# No currently unseen entry: wait for a valid one, rather than changing sides.
	for x in range(-40,40):
		for z in range(-40,40):watched.visible_cells[Vector2i(x,z)]=true
	check(watched.waves.giant_staging().is_empty(),"A fully watched map never enables a spawn from another side")
	watched.update_vision(watched.hero_position)
	check(not watched.waves.giant_staging().is_empty(),"Clearing temporary scouting restores southern giant entries")
	print("FOREST_SOUTH_SPAWN_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
