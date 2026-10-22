extends SceneTree
## Independent integer fixtures from the original effect emitters/GTE stages.
const Packets=preload("res://scripts/recovered_ed_beam_packets.gd")
var failures=0
var checks=0
func check(ok: bool,label_: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
	check(Packets.screen_ratio(Vector2i(101,92),Vector2i(80,100),3072)==Vector2i(95,94),"Entry radius ratio uses signed integer screen delta after projection")
	check(Packets.screen_ratio(Vector2i(101,92),Vector2i(80,100),5120)==Vector2i(106,90),"Outer entry edge uses original five-quarter screen ratio")
	check(Packets.ribbon_offset(Vector2i(20,30),Vector2i(35,21),3723)==Vector2i(-9,-13),"Ribbon width signed-shifts projected endpoint deltas before negating X")
	check(Packets.ribbon_offset(Vector2i.ZERO,Vector2i(1,0),512)==Vector2i.ZERO,"Subpixel ribbon width negates after the source arithmetic shift")
	check(Packets.light_rgb(Vector3i(0,4096,0),Vector3i(128,128,128),Basis.IDENTITY*4096)==Vector3i(89,76,115),"Original light/color/background matrix fixture for source up normal")
	check(Packets.light_rgb(Vector3i(0,-4096,0),Vector3i(128,128,128),Basis.IDENTITY*4096)==Vector3i(106,119,136),"Original light/color/background matrix fixture for source down normal")
	check(Packets.shield_color(1337,0,0)==Vector3i.ZERO,"First shield update leaves source base band black")
	check(Packets.shield_color(1337,2,0)==Vector3i(39,79,159),"First shield update band2 is original integer blue ramp")
	check(Packets.shield_color(1337,2,1)==Vector3i(36,74,149),"Release intensity scales each original channel separately")
	check(Packets.transform_q12(Basis(Vector3(4026,750,0),Vector3(-750,4026,0),Vector3(0,0,4096)),Vector3i(0,-32,-128))==Vector3i(5,-32,-128),"Native vertex transform keeps literal sine/cosine and signed shifts")
	check(Packets.ordering_bucket([1000,1000,1000])==249,"AVSZ3 preserves original341 factor instead of replacing it with a floating average")
	check(Packets.ordering_bucket([1000,1000,1000,1000])==250,"AVSZ4 preserves original Q12 scale256")
	check(Packets.ordering_bucket([1000],"disc")==155 and Packets.ordering_bucket([20],"disc")==0,"Complete discs use their center bucket plus1 minus96, clamped at zero")
	check(Packets.ordering_bucket([1000],"entry")==251 and Packets.ordering_bucket([1000],"ribbon")==250,"Entry and ribbon retain their distinct native center/first-endpoint buckets")
	print("RECOVERED_ED_BEAM_PACKET_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
