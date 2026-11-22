# Smaller blue Qi skill icon — 2026-11-16

The built-in imagegen tool edited the original
`assets/characters/crossgate/kazi/icons/qigong.png`. That original stays intact.
`qigong-blue-master.png` preserves the generated transparent master, excluded
from Godot imports/exports. The shared catalog uses the 64×64 derivative
`assets/characters/crossgate/kazi/icons/qigong-blue.png` for both Qi IDs.
Inventory, equipment and hotbar therefore use the same image.

The visible orb is now 36×37 pixels, up from 30×31. Its slot still uses a 64×64
texture. Rebuild the derivative with this command.

```sh
python3 tools/prepare_crossgate_skill_icons.py
```

Exact imagegen prompt:

> Edit target: the supplied 64px purple Qi skill orb icon. Preserve its round glowing orb with small bright core, curved swirling halo and simple retro game pixel-art character. Recolor the entire orb blue: saturated azure/cobalt outer glow, icy pale blue core; no purple. Make the complete orb including halo occupy only the central 65% of the square canvas width and height, centered, with generous truly transparent padding on all four sides. This is a small game skill inventory icon that must remain readable at 44px display size. Single icon only, no text, no frame, no additional objects. Save the edited transparent PNG to disk and return its local path.
