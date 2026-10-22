extends "res://tests/forest-shrine/large_army_benchmark.gd"
## Same sustained native combat workload, with a dense settlement to expose scenery cost.
var settlement_added=false
func spawn_points(center:Vector3,near:float,far:float,radius:float,wanted:int)->PackedVector3Array:
 if not settlement_added:
  settlement_added=true
  if options.has("baseline-pilot"):
   game.world.set_painterly_preview(false)
   game.world.painterly_pilot=load(options["baseline-pilot"]).new(game.world)
   game.world.set_painterly_preview(true)
  for path in ["scripts/forest/forest_glade_structures.gd","scripts/forest/forest_painterly_pilot.gd","assets/materials/thirstquencher_crowd.gdshader"]:fingerprints[path]=FileAccess.get_sha256("res://"+path)
  if options.has("baseline-pilot"):fingerprints["baseline-pilot"]=FileAccess.get_sha256(options["baseline-pilot"])
  var added=0;var anchor=game.model.cell_of(center)
  for z in range(-9,10,4):
   for x in range(-9,10,4):
    var cell=anchor+Vector2i(x,z);var kind="barracks" if added%2==0 else "tower"
    var cells=game.model.footprint(kind,cell,0)
    if cells.any(func(c):return game.model.occupancy.has(c) or game.model.trees.has(c) or game.model.terrain.cliff_cell(c)):continue
    game.model._make_building(kind,cell,0);added+=1
    if added==12:break
   if added==12:break
  game.model.rebuild_navigation();game.model.revision+=1;game.world.sync(0)
  print("GLADE_SETTLEMENT added=",added)
 return super.spawn_points(center,near,far,radius,wanted)
