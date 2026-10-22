extends "res://scripts/recovered_goemon_gameplay_tests.gd"
func cost(points:PackedVector3Array)->float:
	var combat=game.player.original_pipe_combat;combat.vertices=points
	for i in 4:combat.tick(.20,.2167)
	var begin=Time.get_ticks_usec()
	for i in 24:combat.tick(.20,.2167)
	return float(Time.get_ticks_usec()-begin)/24000.0
func contains_original(compact:PackedVector3Array,original:PackedVector3Array)->bool:
	# Enumerate exact supporting planes from source coordinates, independently
	# of the runtime debug-hull corner selection. This catches a cut-off corner
	# even when every old face still has a point at its original extreme.
	var planes=0
	for a in range(compact.size()):
		for b in range(a+1,compact.size()):
			for c in range(b+1,compact.size()):
				var normal=(compact[b]-compact[a]).cross(compact[c]-compact[a])
				if normal.length_squared()<.0001:continue
				normal=normal.normalized()
				var low=0.0;var high=0.0
				for point in compact:
					var d=normal.dot(point-compact[a]);low=minf(low,d);high=maxf(high,d)
				if low<-.0002 and high>.0002:continue
				if high>.0002:normal=-normal
				planes+=1
				for point in original:
					if normal.dot(point-compact[a])>.0002:return false
	return planes>=4
func run():
	await setup_fixture();fresh();game.player.start_attack(false,1)
	var combat=game.player.original_pipe_combat;combat.begin()
	var mesh:MeshInstance3D=game.player.model.pipe.get_node("GoldPipe")
	var unique={}
	for surface in mesh.mesh.get_surface_count():
		for point in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:unique[mesh.transform*point]=true
	var original=PackedVector3Array(unique.keys());var compact:PackedVector3Array=combat.vertices
	print("PIPE_HULL_COUNTS original=%d compact=%d original_first=%s compact_first=%s"%[original.size(),compact.size(),original[0],compact[0]])
	check(compact.size()>=4,"Compact weapon retains a three-dimensional hull")
	check(Array(compact).all(func(point):return unique.has(point)),"Every retained corner is an exact original mesh vertex")
	check(contains_original(compact,original),"The compact hull contains every original weapon vertex without cutting corners")
	var original_ms=cost(original);var compact_ms=cost(compact);combat.vertices=compact
	print("PIPE_SWEEP_TIMING full_ms=%.4f compact_ms=%.4f"%[original_ms,compact_ms])
	check(compact_ms<original_ms*.8,"The real native pipe sweep spends at least 20% less CPU on redundant geometry")
	game.move_audio.stop()
	for voice in game.voices:voice.stop()
	combat=null;mesh=null
	game.queue_free();paused=false;await frames();await create_timer(.2).timeout
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("GOEMON_PIPE_SWEEP_PERFORMANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
