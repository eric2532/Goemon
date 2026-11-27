extends SceneTree
const Region=preload("res://scripts/forest/forest_east_region.gd")
const Events=preload("res://scripts/forest/forest_east_events.gd")
var failures=[]
var checks=0
func _initialize():call_deferred("run")
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)
func run():
 var population=Region.residents();var trap:Dictionary=population.actors.filter(func(a):return str(a.id)=="5638")[0]
 var context={"cell":Vector2i(49,12),"items":{},"gold":0,"level":99,"group":1,"nowtime":1,"hp":100.,"max_hp":100.,"external":{},"bags":{},"refills":{},"seed":1701}
 check(not Region.automatic_candidate_ready(trap,context),"A broad-phase nonmatching trap position cannot consume the source cooldown")
 context.cell=Vector2i(49,13)
 check(Region.automatic_candidate_ready(trap,context),"Exact original trap position reaches its signed HP command")
 var before=var_to_str(context);Region.automatic_candidate_ready(trap,context)
 check(var_to_str(context)==before,"Automatic readiness cannot commit staged HP/items/gold or consume a weighted bag")
 var session=Events.begin_context(trap,population.scripts[trap.script],context)
 check(session.context.hp==80 and context.hp==100,"Source trap preserves exact20HP delta until the normal event commit")
 print("EAST_AUTO_CONDITIONS_RESULT checks=",checks," failures=",failures.size())
 for failure in failures:push_error(failure)
 quit(0 if failures.is_empty() else 1)
