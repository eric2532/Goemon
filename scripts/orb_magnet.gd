extends Node3D
var game: Node
var age=0.0
var picked=false
var visual: Node3D
func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE;add_to_group("orb_magnets")
	visual=Node3D.new();add_child(visual)
	var red=Geo.mat("ed4d62",.5,.6);var white=Geo.mat("b6f3ff",.4,1.1)
	for i in range(12):
		var a=PI+PI*i/12.0;var b=PI+PI*(i+1)/12.0
		Geo.beam(visual,Vector3(cos(a),sin(a),0)*.65,Vector3(cos(b),sin(b),0)*.65,.17,red)
	for side in [-1,1]:
		Geo.box(visual,Vector3(side*.65,.32,0),Vector3(.34,.7,.34),red)
		Geo.box(visual,Vector3(side*.65,.8,0),Vector3(.34,.28,.34),white)
	var label=Label3D.new();label.text="MAGNET";label.position.y=1.5;label.font_size=32;label.pixel_size=.013
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;visual.add_child(label)
func _physics_process(delta):
	if picked or not game.playing or game.paused or game.transitioning:return
	age+=delta;visual.position.y=1.2+sin(age*2)*.2;visual.rotation.y+=delta*.8
	if age>=90:queue_free();return
	if game.player.hp<=0 or global_position.distance_to(game.player.global_position)>2.5:return
	if not game.pursuit.clear_segment(global_position,game.player.global_position):return
	picked=true;game.orb_system.magnet_collect();queue_free()
