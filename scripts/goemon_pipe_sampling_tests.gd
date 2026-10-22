extends SceneTree
const Sampler=preload("res://scripts/recovered_goemon_pose.gd")
class CountedSampler extends Sampler:
	var conversions=0
	func _transform(values:Array)->Transform3D:
		conversions+=1;return super._transform(values)
var checks=0
var failures=0
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	var sampler=CountedSampler.new()
	check(sampler.has_method("sample_part"),"Weapon collision can sample one source part without rebuilding the whole character")
	if sampler.has_method("sample_part"):
		var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Sampler.DATA_PATH))
		for action in [0x68,0x69,0x6a]:
			var clip:Dictionary=data.clips[data.actions[str(action)]]
			var index:int=clip.pointers.find("0x9002518")
			for frame in range(int(clip.frame_count)):
				var v:Array=clip.frames[frame][index]
				var expected=Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8])),Vector3(v[9],v[10],v[11]))
				var time_=float(frame)/(30.0*float(data.rates[str(action)]))
				var pose:Transform3D=sampler.sample_part(action,time_,"0x9002518")
				check(pose.is_equal_approx(expected),"Single-part sampling preserves original action %X frame %d"%[action,frame])
			for time_ in [.012,.071,.134,.223,.307]:
				var full:Dictionary=sampler.sample_source(action,time_)
				sampler.conversions=0
				var part:Transform3D=sampler.sample_part(action,time_,"0x9002518")
				check(part.is_equal_approx(full["0x9002518"]),"Fractional weapon matrix matches the visible original pose (%X/%.3f)"%[action,time_])
				check(sampler.conversions<=2,"A weapon sample converts at most its two adjacent source matrices")
	print("GOEMON_PIPE_SAMPLING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
