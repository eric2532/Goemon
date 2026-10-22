extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Native charged coins stop at the nearest eligible swept contact, independent
## of enemy creation order. Exercise the real projectile and scenery query.
var projectile_hits:Array[Node]=[]

func small_target(target:Node3D,point:Vector3):
 target.position=point;target.home=point;target.set_physics_process(false)
 var collision:CollisionShape3D=target.get_children().filter(func(c):return c is CollisionShape3D)[0]
 var capsule=CapsuleShape3D.new();capsule.radius=.08;capsule.height=.16
 collision.shape=capsule;collision.position=Vector3.ZERO
 target.contact_shape={"shape":capsule,"center":Vector3.ZERO}

func charged_projectile()->GoldCoin:
 var ticket=game.player.attack_chain.make_ticket("coin")
 ticket["move_audio"]={"character_id":1,"move_key":"coin_charged","voiced":true}
 var coin=game.spawn_gold_coin(Vector3(0,1.5,62.2),Vector3.FORWARD,true,true,1,false,0,ticket)
 coin.set_physics_process(false)
 # This segment crosses both targets in one frame, as a fast or delayed tick can.
 coin.velocity=Vector3.FORWARD*120
 return coin

func run():
 await setup_fixture();fresh(true)
 game.impact_confirmed.connect(func(victim,_strength,_duration):projectile_hits.append(victim))
 var far=game.training_dummy
 var near=load("res://scripts/forest/forest_training_dummy.gd").new();near.game=game;game.add_child(near)
 small_target(far,Vector3(0,1.5,60.2));small_target(near,Vector3(0,1.5,61.5))
 game.enemies.clear();game.enemies.append(far);game.enemies.append(near)
 await physics_frame;await physics_frame
 var coin=charged_projectile();coin._physics_process(1.0/60)
 check(projectile_hits==[near],"Charged coin hits the nearer target when the farther target was created first")
 check(coin.is_queued_for_deletion(),"Charged coin disappears after its first eligible contact")
 await physics_frame
 projectile_hits.clear();game.enemies.reverse()
 coin=charged_projectile();coin._physics_process(1.0/60)
 check(projectile_hits==[near],"Reversing enemy order preserves the nearest charged coin contact")
 await physics_frame
 projectile_hits.clear()
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(3,4,.1);collision.shape=box;wall.add_child(collision)
 game.add_child(wall);wall.position=Vector3(0,1.5,61.95)
 await physics_frame;await physics_frame
 coin=charged_projectile();coin._physics_process(1.0/60)
 check(projectile_hits.is_empty(),"A wall before both targets blocks the charged coin's swept contact")
 check(coin.is_queued_for_deletion(),"A blocked charged coin disappears at the wall")
 game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GOEMON_CHARGED_CONTACT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
