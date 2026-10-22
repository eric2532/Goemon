extends Node3D
## The same ROM 0x120 coin mesh/UVs/coin_source.png used by create_coin() and
## assets/ui/recovered_goemon/ryo.png, instanced without projectile behavior.
const Weapons=preload("res://scripts/recovered_goemon_weapons.gd")
const MAX_VISIBLE=256
static var coin_mesh:Mesh
var game:Node
var batch:MultiMeshInstance3D
var visible_ids:Array=[]
var selection_clock=0.0
var last_economy:WeakRef

func _ready():
	name="RecoveredROMRyoDrops"
	process_mode=Node.PROCESS_MODE_ALWAYS
	if coin_mesh==null:
		var source=Weapons.create_coin()
		coin_mesh=source.get_child(0).mesh.duplicate()
		for index in range(coin_mesh.get_surface_count()):
			var material=coin_mesh.surface_get_material(index).duplicate() as StandardMaterial3D
			# Face the camera explicitly so each real coin can also rotate in 3D.
			material.billboard_mode=BaseMaterial3D.BILLBOARD_DISABLED
			material.cull_mode=BaseMaterial3D.CULL_DISABLED
			coin_mesh.surface_set_material(index,material)
		source.free()
	batch=MultiMeshInstance3D.new();batch.name="NativeRyoInstances"
	batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh=coin_mesh;batch.multimesh.instance_count=MAX_VISIBLE
	batch.multimesh.visible_instance_count=0
	batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)

func _process(delta:float):
	selection_clock-=delta
	sync()

func sync():
	if not is_instance_valid(game) or game.model==null or game.model.ryo==null:
		if batch!=null:batch.multimesh.visible_instance_count=0
		return
	var ryo=game.model.ryo
	if batch==null:return
	if last_economy==null or last_economy.get_ref()!=ryo:
		last_economy=weakref(ryo);visible_ids.clear();selection_clock=0.0
	if selection_clock<=0 or visible_ids.is_empty():
		_select_visible(ryo);selection_clock=.12
	var camera=get_viewport().get_camera_3d()
	var facing:Basis=camera.global_basis.orthonormalized() if camera!=null else Basis.IDENTITY
	var index=0
	for id in visible_ids:
		if not ryo.drops.has(id):continue
		var drop:Dictionary=ryo.drops[id]
		var age:float=ryo.age_of(drop)
		var phase=age*3.4+float(id)*2.39996
		var point:Vector3=drop.pos
		if drop.target_id=="":point.y+=sin(age*3.2+float(id))*.12
		var size_=3.0+minf(.9,log(maxf(1,float(drop.value)/12.0))*.12)
		var basis=facing*Basis(Vector3.UP,phase)*Basis(Vector3.FORWARD,sin(age*1.8+id)*.12)
		batch.multimesh.set_instance_transform(index,Transform3D(basis.scaled(Vector3.ONE*size_),point))
		index+=1
	batch.multimesh.visible_instance_count=index

func _select_visible(ryo):
	visible_ids=ryo.drops.keys()
	if visible_ids.size()<=MAX_VISIBLE:return
	var focus:Vector3=game.player.global_position if is_instance_valid(game.player) else Vector3.ZERO
	# Keep the exact nearest 256 in a max heap. A full comparison sort used to
	# repeatedly calculate every distance, including thousands of hidden coins.
	visible_ids.clear()
	var distances=PackedFloat64Array()
	for id in ryo.drops:
		var distance:float=ryo.drops[id].pos.distance_squared_to(focus)
		if visible_ids.size()<MAX_VISIBLE:
			visible_ids.append(id);distances.append(distance)
			var child=visible_ids.size()-1
			while child>0:
				var parent=(child-1)/2
				if distances[parent]>=distance:break
				visible_ids[child]=visible_ids[parent];distances[child]=distances[parent];child=parent
			visible_ids[child]=id;distances[child]=distance
		elif distance<distances[0]:
			var parent=0
			while parent*2+1<MAX_VISIBLE:
				var child=parent*2+1
				if child+1<MAX_VISIBLE and distances[child+1]>distances[child]:child+=1
				if distances[child]<=distance:break
				visible_ids[parent]=visible_ids[child];distances[parent]=distances[child];parent=child
			visible_ids[parent]=id;distances[parent]=distance
