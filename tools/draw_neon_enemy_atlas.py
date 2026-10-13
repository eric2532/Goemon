"""Paint an original atlas for the two neon siege enemies; preserve old artwork."""
from pathlib import Path
import random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
out = ROOT / 'assets/textures/enemies/neon_set/neon_atlas.png'
out.parent.mkdir(parents=True, exist_ok=True)
colors = ['#202940', '#4ce8f3', '#bdabc7', '#28334b',
          '#3d4059', '#111628', '#38425c', '#74516b',
          '#d6d5eb', '#f45baa', '#69507b', '#26394b',
          '#b680a0', '#74758e', '#442b4e', '#ffc789']
im = Image.new('RGB', (256, 256))
d = ImageDraw.Draw(im)
rng = random.Random(247)
for i, color in enumerate(colors):
    x, y = i % 4 * 64, i // 4 * 64
    d.rectangle((x, y, x + 63, y + 63), fill=color)
    if i not in (1, 9, 15):
        rgb = tuple(int(color[j:j + 2], 16) for j in (1, 3, 5))
        for _ in range(60):
            px, py = x + rng.randrange(64), y + rng.randrange(64)
            d.line((px, py, px + 3, py), fill=tuple(min(255, c + 5) for c in rgb))
    if i in (0, 3, 6):
        d.line((x + 5, y + 3, x + 5, y + 60), fill='#586384', width=2)
        d.line((x + 58, y + 3, x + 58, y + 60), fill='#586384', width=2)
# A painted fox-like ronin mask, with a luminous visor and purple cheek strokes.
y = 128
d.polygon([(5, y + 19), (27, y + 25), (25, y + 32), (8, y + 29)], fill='#152238')
d.polygon([(36, y + 25), (59, y + 18), (55, y + 30), (37, y + 32)], fill='#152238')
d.line((9, y + 25, 24, y + 28), fill='#46e7ef', width=3)
d.line((39, y + 28, 55, y + 24), fill='#46e7ef', width=3)
d.line((25, y + 48, 40, y + 47), fill='#29314a', width=3)
for x in (9, 48):
    d.polygon([(x, y + 36), (x + 8, y + 38), (x + 4, y + 48)], fill='#c53c88')
# An original oni face: broad brows, teeth painted into the mask, no facial nodes.
y = 192
d.polygon([(5, y + 18), (25, y + 10), (29, y + 23), (10, y + 27)], fill='#27223a')
d.polygon([(34, y + 23), (40, y + 10), (58, y + 18), (55, y + 27)], fill='#27223a')
d.line((12, y + 29, 24, y + 28), fill='#ffc789', width=4)
d.line((39, y + 28, 51, y + 29), fill='#ffc789', width=4)
d.polygon([(10, y + 40), (54, y + 40), (46, y + 54), (18, y + 54)], fill='#262136')
for x in (18, 41):
    d.polygon([(x, y + 42), (x + 7, y + 42), (x + 3, y + 51)], fill='#e8d8d0')
im.save(out)
