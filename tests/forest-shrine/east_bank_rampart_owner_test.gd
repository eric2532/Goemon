extends SceneTree
const Rampart=preload("res://scripts/forest/forest_rampart_art.gd")
class Terrain extends RefCounted:
 var pieces=[]
 func height(_x:float,_z:float)->float:return 6.
 func step_clear(_a:Vector3,_b:Vector3)->bool:return true
class Model extends RefCounted:
 var terrain=Terrain.new()
class World extends Node3D:
 var model=Model.new()
 func fog_material(color:Color)->Material:
  var material=StandardMaterial3D.new();material.albedo_color=color;return material
var checks=0
var failures=[]
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label);push_error(label)
func piece(bank:bool)->Dictionary:
 return {"a":Vector2.ZERO,"b":Vector2(6,0),"along":Vector2.RIGHT,"side":Vector2.DOWN,"half":1.,"length":6.,"start":0.,"end":6.,"h0":6.,"h1":6.,"joined":true,"source_bank_cap":bank}
func _initialize():call_deferred("run")
func run():
 for mode in ["source_only","ordinary_only","mixed"]:
  var world=World.new();root.add_child(world)
  world.model.terrain.pieces=[piece(true)] if mode=="source_only" else [piece(false)] if mode=="ordinary_only" else [piece(true),piece(false)]
  var before=world.model.terrain.pieces.duplicate(true);Rampart.build(world,world,false)
  var decks=world.find_children("StoneWallDeck*","MeshInstance3D",true,false);var bodies=world.find_children("WalkableRampart*","StaticBody3D",true,false)
  check(decks.size()==(0 if mode=="source_only" else 1),"Source shore support never creates fortress visual geometry: "+mode)
  check(bodies.size()==(0 if mode=="source_only" else 1),"Source shore support never creates duplicate fortress colliders: "+mode)
  check(world.model.terrain.pieces==before,"Height/support query data stays unchanged: "+mode)
  if mode=="mixed":check(bodies[0].get_meta("map_terrain_index")==1,"Ordinary rampart retains its original terrain index")
  world.queue_free();await process_frame
 print("EAST_BANK_RAMPART_OWNER checks=",checks," failures=",failures.size());quit(failures.size())
