extends Node
## CharacterBody3D.move_and_slide reads the engine's current step internally.
## Run manual fixture callbacks inside real physics, with matching delta.
signal finished
var remaining=0
var callback:Callable
func _ready():set_physics_process(false)
func advance(count:int,tick:Callable)->void:
 assert(remaining==0)
 remaining=count;callback=tick;set_physics_process(true)
 await finished
func _physics_process(delta:float):
 callback.call(delta)
 remaining-=1
 if remaining<=0:
  set_physics_process(false);callback=Callable();finished.emit()
