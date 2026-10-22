extends SceneTree
func _initialize():call_deferred("run")
func run():
	var sampler=load("res://scripts/recovered_goemon_pose.gd").new()
	assert(sampler.frame_count(0)==17,"Action0 must map original17frame clip")
	assert(is_equal_approx(sampler.duration(0),16.0/(30.0*0.4)))
	assert(is_equal_approx(sampler.duration(0x58),4.0/(30.0*0.6)))
	assert(sampler.native_rate(0x10)==1.0)
	var snapshot=sampler.sample_source(0,0)
	assert(snapshot["0x9005498"].origin.distance_to(Vector3(35.5625,81.28125,-3.03125))<0.00001)
	var count=0
	for action_key in sampler.archive.actions:
		var action=int(action_key)
		for frame in range(sampler.frame_count(action)):
			for phase in [0.0,0.5]:
				var source=sampler.sample_source(action,(frame+phase)/(30.0*sampler.native_rate(action)))
				for pointer in source:assert(source[pointer].is_finite());count+=1
	print("PASS: original action mapping, native pose coordinates and %d finite source part samples"%count)
	quit()
