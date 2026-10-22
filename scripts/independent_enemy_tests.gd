extends "res://scripts/shared_enemy_hitbox_tests.gd"
## Each rendered figure is a distinct combat actor, including on native hills.
func setup():
 if has_meta("forest_custom_layout"):remove_meta("forest_custom_layout")
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
 await physics_frames(3)
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false);game.crowd.set_process(false);game.camera_rig.set_process(false)
 game.player.select_character(11);game.tuning.critical_chance=0.0
 game.training_dummy.set_physics_process(false);game.training_dummy.hide();game.enemies.erase(game.training_dummy)
func single_geometry(actor,data:Dictionary):
 var formation:Dictionary=game.crowd._formations[data.id]
 check(formation.roots.size()==1,"One logical enemy submits exactly one rendered figure (%d)"%data.variant)
 var expected=AABB();var first=true
 for part in displayed_parts(data):
  var center:Vector3=part.pose*part.item.bounds.get_center()
  check(native_owner_at(actor,center),"Native body covers its displayed part (%d/%s)"%[data.variant,part.item.group])
  check(not actor.combat_segment_contact(center,center,0).is_empty(),"Actor attack query covers displayed part (%d/%s)"%[data.variant,part.item.group])
  check(not Contact.segment_contact(data,center,center,0).is_empty(),"Model attack query covers displayed part (%d/%s)"%[data.variant,part.item.group])
  var box:AABB=part.pose*part.item.bounds;expected=box if first else expected.merge(box);first=false
 check(actor.combat_bounds().is_equal_approx(expected),"Combat bounds match the one rendered figure (%d)"%data.variant)
 check(actor.fitted_shapes.size()==Contact.shapes(int(data.variant),true).size(),"Native shapes include only one figure (%d)"%data.variant)
func run():
 await setup()
 var fixtures=[]
 for kind in range(5):
  var fixture=spawn(kind);var data:Dictionary=fixture.data;var actor=fixture.actor
  var x=(kind-2)*24.0;var z=120.0
  data.pos=Vector3(x,game.model.surface_height(x,z),z);actor.position=data.pos
  game.model.visible_cells[game.model.cell_of(data.pos)]=true
  actor._sync_fitted_pose();fixtures.append(fixture)
 game.crowd._process(0);await physics_frames()
 check(game.model.terrain_source=="kai_highway" and game.model.surface_height(0,120)>4,"Combat fixture uses the actual raised Kai road")
 check(game.actors.size()==5 and game.model.enemies.size()==5,"Five displayed enemies have five controllers and independent model records")
 for fixture in fixtures:single_geometry(fixture.actor,fixture.data)
 # A tiny blast hits one actor without charging the health of its neighbors.
 var combat=game.player.active_ability
 for fixture in fixtures:
  var parts=displayed_parts(fixture.data);var point:Vector3=parts[0].pose*parts[0].item.bounds.get_center()
  var before=[]
  for other in fixtures:before.append(other.data.hp)
  game.player.position=point-Vector3.UP;combat.player.pos=game.player.position
  var hits:int=Actions.area(combat,point,.05,37,"flintlock",false,Color.WHITE,"slam",1.0)
  check(hits==1,"A narrow real attack selects one independent enemy (%d)"%fixture.data.variant)
  for i in fixtures.size():
   check(is_equal_approx(fixtures[i].data.hp,before[i]-(37 if fixtures[i]==fixture else 0)),"A single hit preserves independent health (%d/%d)"%[fixture.data.variant,i])
 var before=[]
 for fixture in fixtures:before.append(fixture.data.hp)
 var center=Vector3(0,6,120);game.player.position=center-Vector3.UP;combat.player.pos=game.player.position
 var hits:int=Actions.area(combat,center,200,37,"flintlock",false,Color.WHITE,"slam",1.0)
 check(hits==5,"One area attack counts five independent enemies")
 for i in fixtures.size():check(is_equal_approx(fixtures[i].data.hp,before[i]-37),"Area damage charges each enemy once (%d)"%i)
 # Real native coin and pipe attacks retain scenery blocking on the raised map.
 await projectile_checks(fixtures[1].actor,fixtures[1].data,displayed_parts(fixtures[1].data))
 # Use the single-body checks below for the role-zero pipe/coin wall fixture;
 # legacy helper functions requiring cosmetic companions are obsolete.
 var primary=fixtures[0];var parts=displayed_parts(primary.data)
 var point:Vector3=parts[0].pose*parts[0].item.bounds.get_center()
 var box:AABB=parts[0].pose*parts[0].item.bounds
 var from=Vector3(point.x,box.end.y+6,point.z)
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(5,.2,5);collision.shape=shape;wall.add_child(collision);game.add_child(wall)
 wall.position=Vector3(point.x,box.end.y+3,point.z);await physics_frames()
 var coin=original_coin(from,point);var hp:float=primary.data.hp;coin._physics_process(.01)
 check(is_equal_approx(primary.data.hp,hp) and coin.hit_enemies.is_empty(),"Native scenery blocks a coin before an independent enemy")
 wall.queue_free();coin.queue_free();await physics_frames()
 game.player.select_character(1);pipe_pose_at(point);await physics_frames();hp=primary.data.hp
 game.player.strike();game.player.strike()
 check(is_equal_approx(primary.data.hp,hp-66),"Actual Gold Pipe hits the independent figure once")
 game.player.select_character(11)
 # Move uphill, then keep actor/render/native queries coherent between 20Hz updates.
 var actor=primary.actor;var data:Dictionary=primary.data
 data.pos=Vector3(0,game.model.surface_height(0,126),126);actor.position=data.pos;data.hit_recoil=0.0
 game.model.visible_cells[game.model.cell_of(data.pos)]=true
 for i in 123:
  var filler=game.model.waves.spawn_enemy(0,Vector3(-180,game.model.surface_height(-180,-180),-180));filler.stun=1000
 game.sync_enemies()
 for other in game.actors.values():other.set_physics_process(false)
 actor.disable_mode=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE;actor.process_mode=Node.PROCESS_MODE_DISABLED;actor.set_physics_process(true)
 game.model_tick_serial+=1;actor._physics_process(1.0/60);game.crowd._process(0);await physics_frames()
 single_geometry(actor,data)
 var snapshot:Dictionary=actor.fitted_contact
 actor._physics_process(1.0/60);game.crowd._process(1.0/60)
 check(is_same(snapshot,actor.fitted_contact),"Heavy-mode rendering reuses the same native collision snapshot between world steps")
 data.pos.z+=.3;data.pos.y=game.model.surface_height(data.pos.x,data.pos.z);game.model_tick_serial+=1
 actor._physics_process(1.0/60);game.crowd._process(0);await physics_frames()
 check(not is_same(snapshot,actor.fitted_contact) and actor.position.is_equal_approx(data.pos),"Next heavy world step moves the enemy to the actual hill height")
 single_geometry(actor,data)
 actor.combat_knockback(Vector3.RIGHT,1,.1);snapshot=actor.fitted_contact;actor._physics_process(0)
 check(not is_same(snapshot,actor.fitted_contact),"Combat mutations refresh hitboxes immediately during heavy waves")
 for fixture in fixtures:
  if fixture!=primary:await remove_enemy(fixture.actor,fixture.data)
 data.hp=1;actor.hp=1;actor.take_hit(2,Vector3.RIGHT,false,{"tower":true,"tower_feedback":false})
 check(actor.dead and data.hp<=0,"An independent enemy dies without removing its living neighbors")
 game.model.waves.tick(.001,game.player.position)
 check(game.model.enemies.size()==123,"Killing one enemy preserves every other enemy")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 5:await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("INDEPENDENT_ENEMY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
