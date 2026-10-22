Original Ed / Ben combat correction — Goemon 2.85.0

Controls
Ben: hold LMB for polearm attacks; hold RMB for the blue-bomb barrage;
E throws a three-shuriken fan; hold Space to fly, release to descend.
Ed: hold LMB for the sustained piercing beam; RMB throws fireballs.
C evades and Q opens the fighter gallery.

Corrected ROM mappings
Ben ground source14 releases three actor30C four-point projectiles at tick10,
with -22.5/0/+22.5 degree headings. Original945 is a four-event sequence at
0/.2/.4/.6 seconds. A8C is the projectile-throw voice, not a bomb voice.
Ben source19 uses a deployed propeller and repeated window11..16 for actor30B
blue bombs. Each native pattern contains20 target choices from21 arena grid
positions. Launch/arrival uses943; detonation uses940. The sprite and four-point
projectile mesh are recovered source assets. Bomb flight lasts32 ticks with
1.28m sine-arc lift; the bomb then rests128 ticks before detonating.
The fixed boss arena grid is projected around the player's aim in the new map.
Holding RMB repeats the native-sized pattern; a quick tap completes one throw.

Ed source06 is a genuine16-frame beam loop, with source05 recovery. The beam
appears with a four-tick scale-in. Native97E starts two transients and a looping
bed;97F is another sustained loop beginning after30 actor ticks, not a release
one-shot. The native loops are separate and stopped when the attack ends.
The explicit requested A92 restoration remains once per cast; US dispatch
normally disables it. Beam reach38m, radius0.7m and24 damage/.2s deliberately
adapt the original to Edo-scale player power. Original geometry was6.4m long.

Fidelity and preserved data
Original character GLBs, mesh/color arrays, texture pixels and recovered actions
are unchanged. The shared palette fragment is unchanged; its optional billboard
vertex path only faces the bomb sprite toward the camera. Eight native-rendered
source swatches still match exactly. Loop bounds are in the accompanying proofs.
SPU ADSR/reverb/modulation and the full PS1 renderer are not emulated. Existing
shared impact bursts remain runtime effects. The shuriken has no unique original
impact sound; it never plays the bomb explosion. WAV imports preserve PCM/rates.
Historical file beam_release.wav now correctly serves97F sustain, and the old
bomb_voice.wav artifact is retained; runtime A8C is mapped only to the E throw.
