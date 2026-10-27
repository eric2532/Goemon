extends Node3D
## Presentation follows authoritative arrow positions; impacts never arrive early.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const SOUNDS={"tower-launch":["GuardTowerMissileLaunch1","GuardTowerMissileLaunch2","GuardTowerMissileLaunch3"],"tower-impact":"ArrowImpact"}
var game
var visuals: Dictionary={}
var effects: Node3D
var audio: Node
func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	effects=preload("res://assets/rogue/scripts/effects.gd").new();add_child(effects)
	effects.apply_quality(int(game.settings.quality))
	audio=preload("res://assets/rogue/scripts/audio.gd").new();add_child(audio)
	# Prepare original missile cues once; attacks reuse the existing voice pool.
	for event in SOUNDS:audio.cache[event]=preload("res://scripts/character_audio_bank.gd").event("res://assets/audio/warcraft_tower/",SOUNDS,event)
func launch(event: Dictionary):
	var arrow=Node3D.new();arrow.name="TowerArrow";add_child(arrow)
	Geo.beam(arrow,Vector3(0,0,-1.8),Vector3(0,0,.1),.065,Geo.mat("b47d3e",.2,.25))
	Geo.spike(arrow,Vector3(0,0,-.05),Vector3(0,0,.65),.23,Geo.mat("fff1b3",.5,1.8))
	for side in [-1.0,1.0]:
		var fin=Geo.box(arrow,Vector3(side*.1,0,-1.6),Vector3(.24,.045,.5),Geo.mat("e9d6a0",0,.4));fin.rotation.y=side*-.35
	var trail=Geo.beam(arrow,Vector3(0,0,-3.7),Vector3(0,0,-.1),.055,Geo.mat("ffd77c",0,1.3))
	trail.name="GoldTrail"
	visuals[event.id]=arrow
	arrow.position=event.from
	var direction:Vector3=event.to-event.from
	if direction.length_squared()>.001:arrow.quaternion=Quaternion(Vector3.BACK,direction.normalized())
	arrow.visible=game.model.visible_at(event.from)
	if arrow.visible and not game.sound_library.recording:
		audio.play("tower-launch",{"volume":.36})
func impact(event: Dictionary):
	if not game.model.visible_at(event.to):return
	effects.impact(event.to,false,Color("ffe4a1"))
	# Short crossing cuts mark contact, with no tower-induced camera shake.
	var direction: Vector3=event.direction
	var side=direction.cross(Vector3.UP).normalized()
	for axis in [side,Vector3.UP]:effects.streak(event.to-axis*.65,event.to+axis*.65,Color("fff4ce"),.065,.16)
	if not game.sound_library.recording:audio.play("tower-impact",{"volume":.65})
func sync(delta: float):
	if not visuals.is_empty():game.model.sync_enemy_targets(game.model.workforce.arrows.values().map(func(arrow):return arrow.target))
	audio.set_volume(.55) # Master bus already applies the saved volume setting.
	effects.tick(delta)
	for item in effects.items:item.node.visible=game.model.visible_at(item.node.global_position)
	var arrows: Dictionary=game.model.workforce.arrows
	for id in visuals.keys():
		var node: Node3D=visuals[id]
		if not arrows.has(id):node.queue_free();visuals.erase(id);continue
		var arrow: Dictionary=arrows[id]
		var target: Dictionary=game.model.enemies.get(arrow.target,{})
		if target.is_empty():node.hide();continue
		node.position=arrow.pos
		var direction: Vector3=(Roles.hurt_point(target,arrow.pos)-arrow.pos).normalized()
		if direction.length_squared()>.001:node.quaternion=Quaternion(Vector3.BACK,direction)
		node.visible=game.model.visible_at(arrow.pos)
func clear():
	for node in visuals.values():node.queue_free()
	visuals.clear();effects.clear()
	for voice in audio.voices:voice.stop()
