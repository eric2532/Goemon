extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func brute(m,worker)->int:
 var nearest=48.0*48.0;var id=-1
 for e in m.enemies.values():
  var direction:Vector3=e.pos-worker.pos
  var muzzle:Vector3=worker.pos+Vector3.UP*20+Basis(Vector3.UP,atan2(direction.x,direction.z))*Vector3(.85,1.25,.6)
  var hurt=Contact.contact(e,muzzle)
  var distance=worker.pos.distance_squared_to(hurt)
  if e.hp>0 and distance<nearest and (m.visible_at(e.pos) or m.visible_at(hurt)):nearest=distance;id=e.id
 return id
func far_cost(m,guards,count:int)->float:
 for i in guards.size():guards[i].timer=0 if i<count else 100
 m.workforce.tick(0,Vector3(0,0,18))
 var samples=[]
 for repeat_ in 3:
  var start=Time.get_ticks_usec()
  for i in 12:m.workforce.tick(0,Vector3(0,0,18))
  samples.append(float(Time.get_ticks_usec()-start))
 samples.sort();return samples[1]
func run():
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_four_gates.json"))
 var m=Model.new();m.reset(42,{},data);m.start_wave();m.workforce.assignment_clock=1000
 var guards=m.workers.values().filter(func(w):return w.state=="garrison")
 for i in 96:
  var p=m.waves.routes.exit_point(m.portals[i%8],i%4);p.y=18;m.waves.spawn_enemy(i%4,p)
 var one=far_cost(m,guards,1);var eight=far_cost(m,guards,8)
 print("TOWER_SCAN_COST one_us=",one," eight_us=",eight," ratio=",eight/maxf(1,one))
 check(eight<one*3.5,"Eight idle towers share broad-phase work for distant enemies")
 m.workers={guards[0].id:guards[0]};var w=guards[0];w.pos=Vector3.ZERO
 for x in range(-40,40):
  for z in range(-40,40):m.visible_cells[Vector2i(x,z)]=true
 var matches=true;var cases=0
 for distance in [18,40,47,49,56,65]:
  for phase in [0.0,.5,1.0]:
   for facing in [0.0,PI*.5,PI]:
    for action in ["walk","windup","recover","frozen","recoil"]:
     m.enemies.clear();m.workforce.arrows.clear();w.timer=0
     for kind in 4:
      var e=m.waves.spawn_enemy(kind,Vector3(distance+(kind-1)*2,0,kind*3));e.facing=facing;e.walk_phase=phase*TAU;e.velocity=Vector3.RIGHT;e.attack_progress=phase;e.action=action
      if action=="frozen":e.frozen=1.0;e.frozen_pose=e.duplicate();e.facing+=.5
      if action=="recoil":e.hit_recoil=.16;e.hit_direction=Vector3.RIGHT;e.hit_heavy=true
     var expected=brute(m,w);m.workforce.tick(0,Vector3(0,0,18))
     var actual=m.workforce.arrows.values()[0].target if not m.workforce.arrows.is_empty() else -1
     matches=matches and expected==actual;cases+=1
 check(matches,"Exact target selection matches the exhaustive scan in %d pose/range cases, including giant reach"%cases)
 print("TOWER_BROADPHASE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
