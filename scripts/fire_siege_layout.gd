extends RefCounted
## Coordinates for the expanded standard map. Custom maps keep their own contract.
static func configure(world: Node3D)->void:
	world.playable_bounds=Rect2(-160,50,320,480)
	world.base_position=Vector3(0,0,220)
	world.spawn_point=Vector3(0,.15,185)
	world.defense_stations=[155.0,195.0]
	world.hero_spawn_position=Vector3(-8,.15,208)
	world.dog_spawn_position=Vector3(8,.15,208)
	world.lanes[1]=[Vector3(0,0,110),Vector3(0,0,155),Vector3(0,0,195),world.base_position]
	world.layout_anchors=anchors(world)
	world.landmarks={"SHRINE COURT":world.base_position,"SAKURA GROVE":Vector3(-95,0,210),"NEON VILLAGE":Vector3(95,0,240),"RUINED WATCHPOST":Vector3(0,0,400)}
static func anchors(world: Node3D)->Dictionary:
	return {"entrance":world.lanes[1][0],"shrine":world.base_position,"pagoda":world.base_position+Vector3(0,0,31),"forward_station":Vector3(0,0,world.defense_stations[0]),"rear_station":Vector3(0,0,world.defense_stations[-1]),"hero_summon":world.hero_spawn_position,"dog_summon":world.dog_spawn_position,"grove":Vector3(-95,0,210),"village":Vector3(95,0,240),"watchpost":Vector3(0,0,400)}
