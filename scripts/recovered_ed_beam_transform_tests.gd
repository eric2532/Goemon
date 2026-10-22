extends SceneTree
## Raw source literals catch coordinate conversion before signed GTE shifts.
const Packets=preload("res://scripts/recovered_ed_beam_packets.gd")
const NativeState=preload("res://scripts/recovered_ed_beam_native_state.gd")
const Visual=preload("res://scripts/recovered_ed_beam_visual.gd")
var checks=0
var failures=0

class Effect extends Node3D:
	var visual: Node3D
	var direction=Vector3.FORWARD
	func native_state()->Dictionary:return {"roll_basis_q12":NativeState.rotation_q12(120)}

class Probe extends Packets:
	var projected: Array[Vector3]=[]
	func project(point: Vector3)->Vector2i:
		projected.append(point);return Vector2i.ZERO
	func _visible(_points: Array,_kind: String="polygon")->bool:return true

func _initialize():run.call_deferred()
func check(ok: bool,label_: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",label_)

func run():
	var effect=Effect.new();root.add_child(effect)
	effect.visual=Visual.new();effect.add_child(effect.visual)
	effect.visual.sample(1,0,.01,2.0,-1)
	var probe=Probe.new();probe.beam=effect;probe.unit=.01
	probe._tube("main",NativeState.rotation_q12(120),0)
	# ROM main vertex9=(0,-64,-144). Source-world matrix at this port aim:
	# [(-4026,750,0),(750,4026,0),(0,0,-4096)] (rows), then C=(x,-y,-z).
	check(probe.projected[9].is_equal_approx(Vector3(-.12,.63,-2.88)),"Tube vertex9 signed-shifts in source coordinates before world-axis conversion")
	probe.projected.clear();probe._entry()
	check(probe.projected[0].is_equal_approx(Vector3(-.06,.32,-2.56)),"Entry origin uses the same unscaled source rotation and source-axis conversion")
	# A quarter-turn port yaw maps the same original forward axis onto world-X.
	effect.rotation.y=PI/2;effect.direction=Vector3.LEFT
	probe.projected.clear();probe._tube("main",NativeState.rotation_q12(120),0)
	check(probe.projected[9].is_equal_approx(Vector3(-2.88,.63,.12)),"Yawed tube preserves the source integer actor transform")
	probe.projected.clear();probe._entry()
	check(probe.projected[0].is_equal_approx(Vector3(-2.56,.32,.06)),"Entry orbit follows the source actor yaw without copying tube growth")
	effect.rotation=Vector3.ZERO
	probe.projected.clear();probe._tube("main",NativeState.rotation_q12(120),0,Vector3i(1024,1024,1024))
	check(probe.projected[9].is_equal_approx(Vector3(-.03,.16,-.72)),"Native quarter growth quantizes matrix columns before transforming original vertices")
	var quarter=probe._source_rotation(NativeState.rotation_q12(120),Vector3i(1024,1024,1024))
	check(quarter.x==Vector3(-1007,187,0) and quarter.y==Vector3(187,1006,0),"Source growth scales the completed actor matrix after yaw and axis composition")
	effect.free()
	print("RECOVERED_ED_BEAM_TRANSFORM_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
