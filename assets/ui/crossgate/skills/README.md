# Shared skill icons

`water-dragon-regeneration.png` uses the original 水龍蜥 (#101721,
`original:2941`), cell 1 of `dragon_lizards/portraits.png`, surrounded by green
energy, a ground ring and healing sparks. `mantis-critical.png` uses the original
green 螳螂 (#101320, `original:2867`), cell 0 of `mantises/portraits.png`, over
an orange/ivory critical slash and impact flashes. Both are transparent 256×256
icons shared by the Equipment passive cell and pet Stats. The recovered sprite
pixels use integer nearest-neighbor enlargement with no repainting; energy stays
behind the original body. Rebuild with `python3 tools/prepare_pet_passive_icons.py`.
Its assertions check opaque foreground pixels and unchanged source sheets.

`bee-blink-flurry.svg` uses the unchanged original Killer bee from cell zero of
`assets/characters/crossgate/bees/portraits.png`. The vector layout clips the
first cell above its shadow, places four faded bees behind the solid foreground
bee, and adds cyan blink streaks and a small flash. The PNG is embedded unchanged;
the source portrait sheet is never edited. Inventory, pet equipment and hotbar
share this icon. Edit the layout master in `tools/prepare_bee_blink_icon.py` and
rebuild with `python3 tools/prepare_bee_blink_icon.py`.

`bee-mirage.png` is the innate bee dodge icon. It uses the original Killer bee
sprite from the same sheet, cell zero above its ground shadow. The foreground
keeps its original pixels. Two offset, translucent violet copies of the sprite
form the 陽炎 trail.

`summon-bears.png` uses the summoned 穴熊's original actor #101010
(`original:2807`), idle action 0, direction 5, frame 0. The unchanged 68×90
foreground sprite sits in front of two smaller half-opacity copies on a
transparent 128×128 canvas. Inventory and hotbar share this prepared texture.
Rebuild with `tools/recover_habaru_encounter.py::recover_bear_icon` using the
standalone command in the Habaru README. The old `summon-bears.svg` and recovered
Habaru face portrait stay intact; the live skill uses the original full-body
sprite. The five-bear summon count and gameplay are unchanged.

亂射影分身 uses Lancelot's original White / Silver character head at
`assets/ui/portraits/crossgate/model/43-106125.png`. The earlier three-figure
art is preserved in `barrage-shadows.png`.

`assassination.png` pairs Saizo's original blue-black head (`model/39-106052.png`)
with the red KILL graphic from `assets/characters/crossgate/maze/assassination-kill.png`.
Rebuild it with `python3 tools/prepare_crossgate_skill_icons.py`.

反擊 reuses `assets/characters/crossgate/shin/counter-icon.png`, the existing
recovered effect icon. Both inventory and equipped hotbar use these same icons.

The separate `mirror-image.png` belongs to the existing generic Mirror Image
skill. It uses the painted Kaz portrait (`assets/ui/portraits/crossgate/kaz.png`)
as its identity reference: a solid foreground Kaz with two cyan/blue spectral
copies behind him, a dark navy/violet background, and no text or frame. That
artwork is independent of Lancelot's barrage icon.
