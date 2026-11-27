"""Remove relocated temple/tower photographs from BG tiles, keeping tile geometry.

Only private, placement-specific RGBA derivatives are written. Native CUT pixels,
tile extents, shoreline profiles and walking flags stay intact. Duplicated tower
pixels outside the land are removed, rather than being turned into new ground.
The ground occluded in the original camera is an explicitly inferred continuation.
"""
import argparse
import base64
from collections import deque
import json
from pathlib import Path
import zlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps
import recover_elsa_island as source
from prepare_elsa_gate import native_layers
from prepare_elsa_temple import RECT as TEMPLE_RECT

ROOT = source.ROOT / 'assets/maps/falan/elsa/scenery'
RECT = (6592, -3312, 12032, -1104)
OUT = ROOT / 'landmark-floor'
PAGE = 2048


def land_mask(width, height, outer=False):
    """Owned/closed ground, or an outer outline used only under tower occlusion."""
    row = json.loads((ROOT.parent / 'ownership.json').read_text())['59520']
    bits = zlib.decompress(base64.b64decode(row['open']))
    owned = {i for i in range(width * height) if bits[i >> 3] & (1 << (i & 7))}
    if outer:
        points = sorted((i % width, i // width) for i in owned)
        halves = []
        for sequence in [points, points[::-1]]:
            half = []
            for p in sequence:
                while len(half) >= 2 and (half[-1][0]-half[-2][0])*(p[1]-half[-2][1])-(half[-1][1]-half[-2][1])*(p[0]-half[-2][0]) <= 0:
                    half.pop()
                half.append(p)
            halves.append(half[:-1])
        mask = Image.new('L', (RECT[2] - RECT[0], RECT[3] - RECT[1]))
        ImageDraw.Draw(mask).polygon([((x+y)*32-RECT[0],(y-x)*24-RECT[1]) for x,y in halves[0]+halves[1]], fill=255)
        return mask
    exterior = set()
    queue = deque(i for i in range(width * height)
                  if i % width in (0, width - 1) or i // width in (0, height - 1))
    while queue:
        i = queue.popleft()
        if i in exterior or i in owned:
            continue
        exterior.add(i)
        x, y = i % width, i // width
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            if 0 <= x + dx < width and 0 <= y + dy < height:
                queue.append(i + dy * width + dx)
    mask = Image.new('L', (RECT[2] - RECT[0], RECT[3] - RECT[1]))
    draw = ImageDraw.Draw(mask)
    for i in range(width * height):
        if i in exterior:
            continue
        x, y = i % width, i // width
        u, v = (x + y) * 32 - RECT[0], (y - x) * 24 - RECT[1]
        draw.polygon([(u - 32, v), (u, v - 24), (u + 32, v), (u, v + 24)], fill=255)
    return mask


def build(out=OUT):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    width, height, planes = source.reference_map(59520)
    _, native = native_layers([], RECT, 59520)
    desired = native.copy()
    # Apply the already separated original temple wall, stair and railing roles.
    temple = Image.open(ROOT / 'temple-steps/floor.png').convert('RGBA')
    temple_at = (TEMPLE_RECT[0] - RECT[0], TEMPLE_RECT[1] - RECT[1])
    desired.paste(temple, temple_at)
    red, green, blue = ImageChops.difference(desired, native).convert('RGB').split()
    repair = ImageChops.lighter(ImageChops.lighter(red, green), blue).point(lambda p: 255 if p else 0)
    # The same tower is present in FG and precomposed BG; lift FG once, then
    # continue only the occluded land beneath that precise source silhouette.
    data = json.loads((ROOT / 'data.json').read_text())
    tower = data['tower']
    tx, ty, tw, th = tower['rect']
    alpha = Image.open(ROOT / 'tower.png').getchannel('A')
    silhouette = Image.new('L', native.size)
    silhouette.paste(alpha, (tx - RECT[0], ty - RECT[1]))
    silhouette = silhouette.filter(ImageFilter.MaxFilter(7))
    land = land_mask(width, height)
    # Blocked ground hidden by the tower can connect to exterior padding in the
    # walk mask. Infer that surface inside the outer walk outline, ONLY through
    # the original tower silhouette; this is not a reconstructed coastline.
    hidden_land = ImageChops.multiply(ImageChops.multiply(land_mask(width, height, True), silhouette), ImageChops.invert(land))
    land = ImageChops.lighter(land, hidden_land)
    hidden_land.save(out / 'inferred-occluded-land-mask.png')
    # Blocked cells beneath the already fitted architecture are still its
    # floor footprint. Do not mistake these source occlusions for exterior sea.
    model = Image.new('L', native.size)
    model.paste(Image.open(ROOT / 'temple-steps/footprint-mask.png').convert('L'), temple_at)
    draw = ImageDraw.Draw(model)
    temple_data = json.loads((ROOT / 'temple/data.json').read_text())
    for part in temple_data['parts']:
        draw.polygon([(u - RECT[0], v - RECT[1]) for u, v in part['front'] + part['rear']], fill=255)
    land = ImageChops.lighter(land, model)
    exterior = ImageChops.multiply(silhouette, ImageChops.invert(land))
    silhouette = ImageChops.multiply(silhouette, land)
    base = json.loads((ROOT / 'temple/data.json').read_text())
    x, y, w, h = base['grass_rect']
    grass = Image.open(ROOT / 'temple/original-background.png').crop((x, y, x + w, y + h))
    # This native crop has a baked light gradient. Mirror-wrap it so repeating
    # inferred ground has no bright/dark cut seams; native colors stay exact.
    tile = Image.new('RGBA', (w * 2, h * 2))
    tile.paste(grass, (0, 0));tile.paste(ImageOps.mirror(grass), (w, 0))
    tile.paste(ImageOps.flip(grass), (0, h));tile.paste(ImageOps.flip(ImageOps.mirror(grass)), (w, h))
    continuation = Image.new('RGBA', native.size)
    for py in range(0, native.height, tile.height):
        for px in range(0, native.width, tile.width):
            continuation.paste(tile, (px, py))
    desired.paste(continuation, (0, 0), silhouette)
    desired.putalpha(ImageChops.subtract(desired.getchannel('A'), exterior))
    repair = ImageChops.lighter(ImageChops.lighter(repair, silhouette), exterior)
    native.save(out / 'original-background.png')
    desired.save(out / 'floor.png')
    repair.save(out / 'repair-mask.png')
    silhouette.save(out / 'tower-mask.png')
    exterior.save(out / 'tower-exterior-mask.png')
    land.save(out / 'floor-domain-mask.png')
    # An additional alpha-only floor fills original FG occlusion holes. It
    # never covers an opaque native BG pixel or replaces its shoreline mesh.
    gaps = ImageChops.multiply(ImageChops.multiply(ImageChops.invert(native.getchannel('A')), land), repair)
    infill = desired.copy()
    infill.putalpha(gaps)
    infill.save(out / 'ground-infill.png')
    pages = []
    page = Image.new('RGBA', (PAGE, PAGE))
    px = py = row_height = 0
    placements = {}
    shore = data['shore']['placements']
    for index, serial in enumerate(planes[0]):
        if serial < 1000 or source.cut_records(59520)[serial - 1000][4:6] == (0, 0):
            continue
        art, origin, _ = source.cut_image(59520, serial)
        left = (index % width + index // width) * 32 + origin[0] - RECT[0]
        top = (index // width - index % width) * 24 + origin[1] - RECT[1]
        box = (left, top, left + art.width, top + art.height)
        if box[2] <= 0 or box[3] <= 0 or left >= native.width or top >= native.height:
            continue
        mask = ImageChops.multiply(repair.crop(box), art.getchannel('A'))
        if not mask.getbbox():
            continue
        derivative = art.copy()
        derivative.paste(desired.crop(box), (0, 0), mask)
        derivative.putalpha(ImageChops.subtract(art.getchannel('A'), exterior.crop(box)))
        assert art.width + 2 <= PAGE and art.height + 2 <= PAGE
        if px + art.width + 2 > PAGE:
            px = 0
            py += row_height
            row_height = 0
        if py + art.height + 2 > PAGE:
            pages.append(page)
            page = Image.new('RGBA', (PAGE, PAGE))
            px = py = row_height = 0
        page.paste(derivative, (px + 1, py + 1))
        placements[str(index)] = dict(page=len(pages), rect=[px + 1, py + 1, art.width, art.height],
                                      serial=serial, origin=list(origin), shoreline=str(index) in shore,
                                      source_sha256=source.sha(art.tobytes()), rgba_sha256=source.sha(derivative.tobytes()))
        px += art.width + 2
        row_height = max(row_height, art.height + 2)
    if placements:
        pages.append(page)
    for i, image in enumerate(pages):
        image.save(out / ('atlas-%d.png' % i))
    result = dict(map=59520, rect=list(RECT), placements=placements, pages=len(pages),grass_native_rect=[x+TEMPLE_RECT[0],y+TEMPLE_RECT[1],w,h],grass_repeat='mirrored 2x2 native crop',
                  inference='Native grass continues beneath the relocated tower, temple, stairs and railings. Occluded tread paint continues native paving. Placement-specific BG colors change only in the role masks. Original tile alpha is retained except removal of the duplicated tower outside the land. Occluded blocked ground inside the outer walking outline is inferred only through the original tower silhouette. A separate alpha patch fills original transparent BG holes within the recorded floor domain. Origin, extent, shoreline geometry and navigation are retained.',
                  hashes=dict(native=source.sha(native.tobytes()), floor=source.sha(desired.tobytes()), repair=source.sha(repair.tobytes())))
    (out / 'data.json').write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    print('ELSA_LANDMARK_FLOOR', len(placements), 'BG tiles;', len(pages), 'pages;',
          sum(row['shoreline'] for row in placements.values()), 'shoreline profiles retained', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=OUT)
    build(parser.parse_args().out)
