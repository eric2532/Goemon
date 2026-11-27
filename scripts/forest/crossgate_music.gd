extends RefCounted
## Prepared original tracks; area changes reuse the game's single music player.
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const BATTLE_RADIUS=16.0
const BATTLE_HOLD=4.0
const BATTLE_PROBE_INTERVAL=.25
const STREAMS={
 "b0":preload("res://assets/audio/crossgate/music/cgbgm_b0.mp3"),
 "m0":preload("res://assets/audio/crossgate/music/cgbgm_m0.mp3"),
 "m1":preload("res://assets/audio/crossgate/music/cgbgm_m1.mp3"),
 "m2":preload("res://assets/audio/crossgate/music/cgbgm_m2.mp3"),
 "m3":preload("res://assets/audio/crossgate/music/cgbgm_m3.mp3"),
 "m4":preload("res://assets/audio/crossgate/music/cgbgm_m4.mp3"),
 "f0":preload("res://assets/audio/crossgate/music/cgbgm_f0.mp3"),
 "f1":preload("res://assets/audio/crossgate/music/cgbgm_f1.mp3"),
 "f2":preload("res://assets/audio/crossgate/music/cgbgm_f2.mp3"),
 "d0":preload("res://assets/audio/crossgate/music/cgbgm_d0.mp3"),
 "d1":preload("res://assets/audio/crossgate/music/cgbgm_d1.mp3"),
 "d2":preload("res://assets/audio/crossgate/music/cgbgm_d2.mp3"),
 "d3":preload("res://assets/audio/crossgate/music/cgbgm_d3.mp3"),
 "d4":preload("res://assets/audio/crossgate/music/cgbgm_d4.mp3"),
 "puk2_field1":preload("res://assets/audio/crossgate/music/puk2_field1.mp3"),
 "puk2_mati":preload("res://assets/audio/crossgate/music/puk2_mati.mp3"),
 "puk2_sinden":preload("res://assets/audio/crossgate/music/puk2_sinden.mp3"),
 "puk2_haikyo":preload("res://assets/audio/crossgate/music/puk2_haikyo.mp3"),
}
const ELSA_SOUNDS={213:"d1",214:"d2",216:"d4",218:"",228:"puk2_field1",229:"puk2_mati",230:"puk2_sinden",232:"puk2_haikyo"}

static func key(area:String,floor:int,at:Vector2=Vector2.ZERO)->String:
 if Regions.village_contains(area,at):area=Regions.CONNECTED_VILLAGES[area]
 match area:
  "city","":return "m1"
  "castle":return "m0"
  "il_village","alyut","laruka","venoa":return "m3"
  "kili","ghana":return "m4"
  "sokia_coast","sokia_desert","ghana_road","ghana_north_road":return "f2"
  "interior":return indoor(floor)
 return "f1"

static func indoor(floor:int)->String:
 if floor==51009:return "d3"
 if floor==51010:return "d4"
 if Original.floor_number(floor)>0:return "d0"
 # The pinned server dungeon table assigns sound 214 to these maze families.
 if floor>=30101 and floor<=30106 or floor>=30201 and floor<=30216 or Original.Beast.owns(floor):return "d2"
 var source=Original.source_id(floor)
 if source>=59500 and source<59800 and Original.owns(floor):
  var sound=int(Original.Art.data().maps[Original.path_for(floor)].get("music",-1))
  if ELSA_SOUNDS.has(sound):return ELSA_SOUNDS[sound]
 if source in [400,402]:return "f0"
 if source==15522 or floor in [47001,47010]:return "f1"
 if source>=4000 and source<4500:return "m2"
 if source>=1530 and source<=1538:return "d2"
 if source>=1500 and source<1600:return "m0"
 if source>=1000 and source<1500:return "m1"
 if source>=2000 and source<2500 or source==5007:return "m3"
 if source>=3000 and source<3900:return "m4"
 # shortcut: unverified special dungeon overrides use the original cave theme; refine from original playback evidence.
 return "d1"
