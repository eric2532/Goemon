extends Node3D
## Original soldier bullets share simulation state with legacy aimed projectiles.
const SoldierVisual=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const SOLDIER_DIR="res://assets/characters/thirstquencher/projectiles/"
const MAX_SOURCE_BULLETS=48
const MAX_CASINGS=24
var bullet_scene:PackedScene
var casing_scene:PackedScene
var gunshot:AudioStream
var casings:Array=[]
var gun_voices:Array=[]
var gun_voice_cursor=0
var legacy_geo:Script
var game
var visuals: Dictionary={}
var effects: Node3D
func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	load_source_resources()
	effects=load("res://assets/rogue/scripts/effects.gd").new();add_child(effects)
	effects.apply_quality(int(game.settings.quality))
func load_source_resources():
	# Populate ResourceLoader's shared cache before combat begins.
	if bullet_scene==null:bullet_scene=load(SOLDIER_DIR+"bullet.glb")
	if casing_scene==null:casing_scene=load(SOLDIER_DIR+"casing.glb")
	if gunshot==null:gunshot=load(SOLDIER_DIR+"gunshot_43a.wav")

func launch(event: Dictionary):
	if event.get("soldier_bullet",false):
		if game.forest_point_visible(event.from):
			_source_bullet(event)
			play_gunshot(event.from)
			_source_casing(event)
		return
	var arrow=Node3D.new();arrow.name="ReedArrow";add_child(arrow)
	_legacy_geometry().beam(arrow,Vector3(0,0,-1.2),Vector3(0,0,.1),.055,_legacy_geometry().mat("82623d",.1,.15))
	_legacy_geometry().spike(arrow,Vector3.ZERO,Vector3(0,0,.45),.16,_legacy_geometry().mat("e6e0c4",.4,.3))
	for side in [-1.0,1.0]:
		var fin=_legacy_geometry().box(arrow,Vector3(side*.09,0,-1.05),Vector3(.2,.04,.4),_legacy_geometry().mat("ce7555",0,.1));fin.rotation.y=side*-.3
	visuals[event.id]=arrow;arrow.position=event.from
	var direction: Vector3=event.to-event.from
	if direction.length_squared()>.001:arrow.quaternion=Quaternion(Vector3.BACK,direction.normalized())
	arrow.visible=game.forest_point_visible(event.from)
func impact(event: Dictionary):
	var point: Vector3=event.point
	if game.forest_point_visible(point):
		effects.impact(point,false,Color("fff4c0") if event.get("muzzle",false) else Color("cf8662"))
func sync(delta: float):
	effects.tick(delta)
	for item in effects.items:item.node.visible=game.forest_point_visible(item.node.global_position)
	var arrows: Dictionary=game.model.waves.projectiles
	for id in arrows:
		var a:Dictionary=arrows[id]
		if a.get("soldier_bullet",false) and not visuals.has(id) and game.forest_point_visible(a.pos):
			_source_bullet({"id":id,"from":a.pos,"to":a.to,"direction":a.direction,"facing":a.facing})
	_tick_casings(delta)
	for id in visuals.keys():
		var node: Node3D=visuals[id]
		if not arrows.has(id):node.queue_free();visuals.erase(id);continue
		var arrow: Dictionary=arrows[id];node.position=arrow.pos
		var direction: Vector3=arrow.get("direction",arrow.to-arrow.pos)
		if direction.length_squared()>.001:node.quaternion=Quaternion(Vector3.BACK,direction.normalized())
		node.visible=game.forest_point_visible(arrow.pos)
		if node.get_meta("soldier_bullet",false):
			if not node.visible:node.queue_free();visuals.erase(id);continue
			var player:AnimationPlayer=node.get_meta("source_player",null)
			if is_instance_valid(player):
				var frame=posmod(floori(float(arrow.get("age",0))*30),16)
				if node.get_meta("source_frame",-1)!=frame:
					player.seek(frame/30.0,true);node.set_meta("source_frame",frame)
func clear():
	for row in casings:
		if is_instance_valid(row.node):row.node.queue_free()
	casings.clear()
	for voice in gun_voices:
		if is_instance_valid(voice):voice.stop()
	for node in visuals.values():node.queue_free()
	visuals.clear()
	if is_instance_valid(effects):effects.clear()

func _find_animation(node:Node)->AnimationPlayer:
	if node is AnimationPlayer:return node
	for child in node.get_children():
		var found=_find_animation(child)
		if found!=null:return found
	return null

func _source_count()->int:
	var count=0
	for node in visuals.values():
		if node.get_meta("soldier_bullet",false):count+=1
	return count

func _source_bullet(event:Dictionary):
	if visuals.has(event.id) or _source_count()>=MAX_SOURCE_BULLETS:return
	if bullet_scene==null:bullet_scene=load(SOLDIER_DIR+"bullet.glb")
	if bullet_scene==null:return
	var node=Node3D.new();node.name="ThirstquencherBullet";add_child(node)
	var model=bullet_scene.instantiate();node.add_child(model);model.scale=Vector3.ONE*SoldierVisual.SCALE
	node.position=event.from
	var direction:Vector3=event.get("direction",event.to-event.from).normalized()
	if direction.length_squared()>.001:node.quaternion=Quaternion(Vector3.BACK,direction)
	node.set_meta("soldier_bullet",true)
	var player=_find_animation(model)
	if player!=null:
		for name_ in player.get_animation_list():
			if "Source__801b1208" in name_:
				player.play(name_);player.pause();player.seek(0,true);break
		node.set_meta("source_player",player)
	visuals[event.id]=node

func play_gunshot(point:Vector3):
	if gunshot==null:gunshot=load(SOLDIER_DIR+"gunshot_43a.wav")
	if gunshot==null:return
	if gun_voices.size()<8:
		var voice=AudioStreamPlayer3D.new();voice.stream=gunshot;voice.max_distance=65;voice.unit_size=12
		add_child(voice);gun_voices.append(voice)
	var voice:AudioStreamPlayer3D=gun_voices[gun_voice_cursor%gun_voices.size()]
	gun_voice_cursor+=1;voice.position=point;voice.pitch_scale=1.0
	voice.volume_db=linear_to_db(maxf(.0001,float(game.settings.get("volume",.65))*.55));voice.play()

func _source_casing(event:Dictionary):
	if casings.size()>=MAX_CASINGS:return
	if casing_scene==null:casing_scene=load(SOLDIER_DIR+"casing.glb")
	if casing_scene==null:return
	var node=Node3D.new();node.name="ThirstquencherCasing";add_child(node)
	var model=casing_scene.instantiate();node.add_child(model);model.scale=Vector3.ONE*SoldierVisual.SCALE;model.rotation.y=PI
	var yaw=float(event.get("facing",0));node.rotation.y=yaw
	node.position=event.from+Basis(Vector3.UP,yaw)*SoldierVisual.source_point(Vector3(0,0,16))
	casings.append({"node":node,"age":0.0,"yaw":yaw,"velocity":Basis(Vector3.UP,yaw)*SoldierVisual.source_point(Vector3(-4.5,-8,0))*30.0})

func _tick_casings(delta:float):
	for index in range(casings.size()-1,-1,-1):
		var row:Dictionary=casings[index];row.age+=delta
		if row.age>=3.0 or not game.forest_point_visible(row.node.position):
			row.node.queue_free();casings.remove_at(index);continue
		row.node.position+=row.velocity*delta
		# Source(-128,+4,+5) through glTF plus controller half-turn gives(+128,-4,+5).
		row.node.basis=Basis(Vector3.UP,float(row.yaw))*Basis.from_euler(Vector3(128,-4,5)*(TAU/4096.0)*floorf(float(row.age)*30.0),EULER_ORDER_XYZ)

func _legacy_geometry()->Script:
	if legacy_geo==null:legacy_geo=load("res://scripts/geo.gd")
	return legacy_geo
