extends SceneTree
const Terrain=preload("res://scripts/forest/forest_kai_terrain.gd")
class CountTerrain extends "res://scripts/forest/forest_kai_terrain.gd":
 var probes=0
 func _covered_height(x:float,z:float)->float:
  probes+=1;return super._covered_height(x,z)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var t=CountTerrain.new();t.configure([])
 check(t.disk_clear(Vector3.ZERO,3.9),"The level castle clearing supports the full enlarged soldier footprint")
 check(t.probes==0,"A fully covered level disk uses a region proof without nine repeated height probes")
 t.probes=0
 for i in 100:t.disk_clear(Vector3(.001*i,0,.001*i),3.9)
 check(t.probes==0,"Nearby soldiers share exact flat region proofs while preserving their actual positions")
 t.probes=0
 var point=Vector3(0,t.height(0,108),108)
 check(t.disk_clear(point,3.9),"The native gentle ramp remains supported by the enlarged footprint")
 check(not t.disk_region_cache.is_empty(),"Native disk region proofs are shared after successful checks")
 t.configure([{"ax":-10,"az":0,"bx":10,"bz":0,"width":3,"h0":12.0,"h1":12.0}]);t.probes=0
 check(t.disk_region_cache.is_empty(),"Reconfiguring terrain invalidates every native disk proof")
 check(t.disk_clear(Vector3.ZERO,3.9) and t.probes>0,"Custom raised decks retain the original coverage and height checks after reconfiguration")
 var gentle=CountTerrain.new();gentle.width=20;gentle.spacing=3.0;gentle.heights.resize(400);gentle.covered.resize(400);gentle.covered.fill(1)
 for z in 20:
  for x in 20:gentle.heights[z*20+x]=x*.025+z*.025
 check(gentle.disk_clear(Vector3(-210,0,-210),3.9) and gentle.probes==0,"Small native height variations use a conservative range proof without weakening disk clearance")
 gentle.probes=0
 check(not gentle.disk_clear(Vector3(-239,0,-239),3.9) and gentle.probes>0,"A gentle surface cannot prove a footprint crossing its coverage edge")
 var steep=CountTerrain.new();steep.width=20;steep.spacing=3.0;steep.heights.resize(400);steep.covered.resize(400);steep.covered.fill(1)
 for z in 20:
  for x in 20:steep.heights[z*20+x]=x*3.0
 check(not steep.disk_clear(Vector3(-210,0,-210),3.9) and steep.probes>0,"A steep unsupported slope retains the exact sample rejection")
 var hole=CountTerrain.new();hole.width=20;hole.spacing=3.0;hole.heights.resize(400);hole.heights.fill(0);hole.covered.resize(400);hole.covered.fill(1)
 hole.covered[10*20+10]=0
 check(not hole.disk_clear(Vector3(-210,0,-210),3.9),"An uncovered center never becomes traversable through a flat height proof")
 check(not t.disk_clear(Vector3(-240,0,-240),3.9),"A footprint crossing the native field boundary remains rejected")
 var bounded=CountTerrain.new();bounded.configure([])
 for z in range(1,155):
  for x in range(1,155):bounded._disk_region_clear(Vector3(x*3-239.9,0,z*3-239.9),0)
 check(bounded.disk_region_cache.size()<=16384,"Region certificates have bounded storage across the whole native map")
 print("KAI_DISK_FAST_PATH_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
