extends RefCounted
## Chief's precision weapons use the same native head pose as the crowd shader.
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const HEAD_PART=7
static var native_envelopes:Dictionary={}
static func native_head(enemy:Ninja)->bool:return Soldier.supports(enemy.variant) and enemy.has_method("_combat_data")
static func separate_head(enemy:Ninja)->bool:return native_head(enemy) or not enemy.has_method("combat_bounds")
static func broad_bounds(enemy:Ninja)->AABB:
	if not native_head(enemy):return enemy.combat_bounds() if enemy.has_method("combat_bounds") else bounds(enemy)
	if not native_envelopes.has(enemy.variant):native_envelopes[enemy.variant]=Soldier.data(enemy.variant).get_meta("bounds")
	var data:Dictionary=enemy._combat_data()
	return Transform3D(Basis(Vector3.UP,float(data.get("facing",0))),data.pos)*native_envelopes[enemy.variant]
static func region(enemy:Ninja)->Dictionary:
	if native_head(enemy):
		var data:Dictionary=enemy._combat_data()
		var resource=Soldier.data(enemy.variant)
		var frame=Soldier.frame_state(data)
		var root=Transform3D(Basis(Vector3.UP,float(data.get("facing",0))),data.pos)
		var pose:Transform3D=root*resource.get_meta("poses")[int(frame.row)*11+HEAD_PART]
		return {"pose":pose,"bounds":resource.get_meta("part_bounds")[HEAD_PART]}
	if not enemy.has_method("combat_bounds"):
		# Legacy Ninja actors use the shared HeroModel head pivot, or its rest
		# pivot when their body is submitted through the old crowd renderer.
		var pose=enemy.global_transform
		if is_instance_valid(enemy.model):
			pose=enemy.model.head.global_transform if is_instance_valid(enemy.model.head) else enemy.model.global_transform.translated_local(Vector3(0,1.98,0))
		else:pose=pose.translated_local(Vector3(0,1.98,0))
		return {"pose":pose,"bounds":AABB(Vector3(-.36,-.3,-.33),Vector3(.72,.65,.66))}
	# Stylized enemies have no separate head bone. Use the upper central part of
	# their body contact, excluding the giant's independently moving fists/feet.
	var bounds:AABB=enemy.combat_bounds()
	var prepared:Dictionary=enemy.get("fitted_contact") if enemy.has_method("_combat_data") else {}
	for i in prepared.get("shapes",[]).size():
		if prepared.shapes[i].group=="body":
			bounds=prepared.shape_bounds[i];break
	var size=bounds.size*Vector3(.6,.28,.6)
	var head=AABB(Vector3(bounds.get_center().x-size.x*.5,bounds.end.y-size.y,bounds.get_center().z-size.z*.5),size)
	return {"pose":Transform3D.IDENTITY,"bounds":head}
static func contact(enemy:Ninja,from:Vector3,to:Vector3)->Dictionary:
	var head=region(enemy)
	var pose:Transform3D=head.pose;var inverse=pose.affine_inverse()
	var span:Vector2=Contact._box_interval(head.bounds,inverse*from,inverse*to,0)
	if span.x<0:return {}
	return {"t":span.x,"point":from.lerp(to,span.x)}
static func bounds(enemy:Ninja)->AABB:
	var head=region(enemy)
	return head.pose*head.bounds
