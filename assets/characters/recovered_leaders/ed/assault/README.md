Recovered from Musashi SC06.CD/FILE_016, US disc overlay0.4.dec. See source-proof.json
for verified call sites, dispatch tables and VRAM upload coverage. No pixels were
painted or generated. RGB555 colors are expanded to RGBA with transparent zero.

- charge.png: actor2FD, effect5D; 16×16, VRAM word(720,296), CLUT(352,323).
- ball.png: actor2FF, effect5E; 64×64, word(704,448), CLUT(352,324).
- fire.png: actor303, effect60; sixteen64×64 frames in a256×256 atlas,
  word origins x768/784/800/816 and y256/320/384/448, CLUT(352,322).
  Frame order is row major. Eight actors at512/4096-turn intervals,90 source
  ticks lifetime and30fps animation come from the original overlay.

Playable adaptation: one large ball during each of three collision-aware hops;
one floor bounce,2.4s maximum flight,9m initial burst and18m outward travel over
4.5s. Outward fire sprites and their damaging width are3× their initial port
size. The bright leading end faces the projected outward heading, with the
red tail trailing toward the burst; camera turns preserve that orientation.
An elevated render center keeps the enlarged sprite above ground while its
collision front stays low enough to respect cover. Each ball hits each victim
once for90 base damage (270 with Ed's existing
3× multiplier), scaled by current hero tuning. These distances, timings and HP
are port choices. Released attacks retain damage, attribution and cast identity.

Audio assault_bounce.wav is recovered source983 at pitch18432; the existing
source981 assault_burst mix accompanies the port's burst. This does not claim
that981 replaces the original terminal call984 in the ROM.
