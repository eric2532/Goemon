extends RefCounted
## Fixture for tests that construct their own workplaces.
static func reset(m,value: int=42):
	m.reset(value)
	for b in m.buildings.values():
		if b.kind!="shrine":m._remove_building(b.id)
	# These fixtures exercise manual construction with six idle workers, rather
	# than the ready fort's additional tower guards and discovered camp ground.
	while m.workers.size()>6:m.workers.erase(m.workers.keys().back())
	m.rebuild_navigation();m.explored.clear();m.visible_cells.clear()
	var index=0
	for w in m.workers.values():
		w.pos=m.point(m.nearest_open(Vector2i(-3+index%6,4+index/6)));index+=1
	m.update_vision(m.hero_position)
