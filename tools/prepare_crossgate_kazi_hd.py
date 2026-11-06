"""Prepare illustrated Kazi authoring sheets and bake the saved, editable masters."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics
import sys

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'assets/references/crossgate_kazi_hd'
REVIEW = ROOT / 'build/Other Files/Cross Gate 102488/HD Preview'
OUT = ROOT / 'assets/characters/crossgate/kazi_hd'
SOURCE = ROOT / 'assets/characters/crossgate/kazi'
ACTIONS = {0: 'stand', 1: 'walk', 3: 'run', 5: 'attack', 6: 'cast', 8: 'hurt', 10: 'fall'}
DIRECTIONS = ['north west', 'north (straight back)', 'north east', 'east (straight right)',
              'south east', 'south (straight front)', 'south west', 'west (straight left)']
COLS = {0: 6, 1: 6, 3: 6, 5: 4, 6: 5, 8: 2, 10: 4}
HEIGHT = {0: 83, 1: 83, 3: 74, 5: 77, 6: 83, 8: 76, 10: 83}
SCALE = 2


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(source):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg

    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / '.gdignore').touch()
    (WORK / 'masters').mkdir(exist_ok=True)
    (REVIEW / 'Sources').mkdir(parents=True, exist_ok=True)
    metadata = cg.clip_metadata('ex:1727')
    jobs = []
    for clip in cg.actor('ex:1727')[2]:
        action, direction = clip['action'], clip['direction']
        if action not in ACTIONS:
            continue
        token = f'{action}-{direction}'
        cols = COLS[action]
        rows = math.ceil(len(clip['frames']) / cols)
        cell_w, cell_h = 256, 384
        info = metadata['clips'][clip['index']]
        left, top, right, bottom = info['bounds']
        zoom = min(2, (cell_w - 32) / (right - left), (cell_h - 32) / (bottom - top))
        origin = [round((cell_w - (right-left)*zoom)/2-left*zoom),
                  round((cell_h - (bottom-top)*zoom)/2-top*zoom)]
        sheet = Image.new('RGBA', (cols * cell_w, rows * cell_h))
        for frame in range(len(clip['frames'])):
            image, x, y = cg.frame_parts('ex:1727', clip['index'], frame)
            image = image.resize((max(1, round(image.width*zoom)), max(1, round(image.height*zoom))), Image.Resampling.NEAREST)
            point = (frame % cols*cell_w+origin[0]+round(x*zoom), frame//cols*cell_h+origin[1]+round(y*zoom))
            assert point[0] >= frame % cols*cell_w and point[1] >= frame//cols*cell_h
            assert point[0]+image.width <= (frame % cols+1)*cell_w and point[1]+image.height <= (frame//cols+1)*cell_h
            sheet.alpha_composite(image, point)
        path = REVIEW / 'Sources' / f'{token}.png'
        sheet.save(path)
        motion = ('Make a genuine smooth walk-in-place loop: alternate feet, weight transfer, opposite arm motion, restrained coat/hair follow-through.' if action == 1 else
                  'Make a continuous energetic running-in-place loop, with clear alternating strides and coat/hair follow-through.' if action == 3 else
                  'Preserve the source pose sequence, including any turning, airborne follow-through, spell gesture or falling motion.' if action in (5, 6, 8, 10) else
                  'A restrained seamless idle/breathing loop, with small coherent purple spark motion. Keep the body and equipment consistent.')
        prompt = (f'Production HD illustrated 2D game {ACTIONS[action].upper()} sprite sheet for Kazi. '
                  f'Image 1 is the EDIT TARGET grid: exactly {cols} columns x {rows} rows, {len(clip["frames"])} occupied cells, '
                  f'ordered left-to-right then top-to-bottom; any trailing cells are empty. Image 2 is the APPROVED IDENTITY/STYLE MASTER. '
                  f'Redraw every occupied sprite as the exact same Kazi from image 2, facing {DIRECTIONS[direction]} as the source poses indicate. '
                  'Same swept black hair silhouette, stern narrow marked face, charcoal long high-collared split coat, white inner collar, '
                  'gold waist buttons, black trousers/boots, short curved blade in the correct hand, and violet-white energy. '
                  'For back views show his back, never a face; keep clothing and weapon handedness consistent. '
                  f'{motion} '
                  'Preserve the source positions, motion direction and scale relative to each cell; preserve purple attack/spell effect shapes and extent. '
                  'All frames have one consistent face, body proportions, clothes, palette and lighting. Keep a 12-pixel transparent margin at every cell edge; '
                  'no limb, hair, blade or effect may cross into another cell. No missing frames, no duplicate characters in a cell, no redesign, no additional equipment. '
                  f'Use exactly the same canvas aspect as image 1 ({sheet.width}:{sheet.height}), sharp HD hand-painted sprite detail, true transparent alpha. '
                  'No background, ground, ground shadow, labels, text, separators, grid lines or watermark. This is an animation sheet, not a poster or turnaround.')
        jobs.append(dict(token=token, action=action, direction=direction, cols=cols, rows=rows,
                         frames=len(clip['frames']), source_sheet=str(path), target=str(WORK / 'masters' / f'{token}.png'), prompt=prompt))
    assert len(jobs) == 56
    (WORK / 'source-jobs.json').write_text(json.dumps(jobs, indent=2) + '\n')
    if not (WORK / 'jobs.json').exists():
        (WORK / 'jobs.json').write_text(json.dumps(jobs, indent=2) + '\n')
    print(f'Prepared {len(jobs)} source sheets; existing illustrated masters were not changed.')


def body_bounds(image):
    """Find the opaque neutral/skin body, excluding bright violet energy."""
    pixels = image.load()
    mask = set()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a > 220 and max(r, g, b) < 185 and (max(r,g,b)-min(r,g,b) <= max(20,max(r,g,b)*.35) or r >= g >= b):
                mask.add((x, y))
    # Measure the body without letting a thin raised/extended sword move its root.
    registration = Image.new('L', image.size)
    registration.putdata([255 if (x, y) in mask else 0 for y in range(image.height) for x in range(image.width)])
    kernel = min(15, max(7, 2*int(math.sqrt(len(mask))*.035)+1))
    registration = registration.filter(ImageFilter.MinFilter(kernel)).filter(ImageFilter.MaxFilter(kernel))
    mask = {(x, y) for y in range(image.height) for x in range(image.width) if registration.getpixel((x, y))}
    components = []
    while mask:
        stack = [mask.pop()]
        points = []
        while stack:
            x, y = stack.pop()
            points.append((x, y))
            for neighbor in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                if neighbor in mask:
                    mask.remove(neighbor)
                    stack.append(neighbor)
        if len(points) > 30:
            components.append((len(points), (min(p[0] for p in points), min(p[1] for p in points),
                                             max(p[0] for p in points)+1, max(p[1] for p in points)+1)))
    assert components, 'No opaque character body in illustrated frame'
    components.sort(reverse=True)
    area, main = components[0]
    bounds = list(main)
    width, height = main[2]-main[0], main[3]-main[1]
    # A white collar can disconnect the dark hair from the coat.
    for count, box in components[1:]:
        center = (box[0]+box[2])*.5
        significant = count >= max(20,area*.015)
        if significant and main[0]-width*.3 <= center <= main[2]+width*.3 and box[3] >= main[1]-height*1.2 and box[1] <= main[3]+height*.8:
            bounds = [min(bounds[0], box[0]), min(bounds[1], box[1]), max(bounds[2], box[2]), max(bounds[3], box[3])]
    return tuple(bounds)


def bake(pilot=False):
    jobs = json.loads((WORK / 'jobs.json').read_text())
    source = json.loads((SOURCE / 'motions.json').read_text())
    selected = [job for job in jobs if Path(job['target']).is_file()]
    if not pilot:
        assert len(selected) == 56, f'{56-len(selected)} illustrated masters remain'
    assert selected
    unique, clips, hashes = {}, {}, {}
    for job in selected:
        path = Path(job['target'])
        image = Image.open(path).convert('RGBA')
        assert image.getchannel('A').getextrema()[0] == 0, f'Opaque background: {path}'
        assert image.width >= job['cols']*64 and image.height >= job['rows']*96, f'Undersized grid: {path}'
        cells, bodies = [], []
        for i in range(job['frames']):
            box = (i % job['cols']*image.width//job['cols'], i//job['cols']*image.height//job['rows'],
                   (i % job['cols']+1)*image.width//job['cols'], (i//job['cols']+1)*image.height//job['rows'])
            cell = image.crop(box)
            opaque = cell.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox()
            assert opaque and opaque[0] > 0 and opaque[1] > 0 and opaque[2] < cell.width and opaque[3] < cell.height, f'Art crosses cell edge: {path}, frame {i}'
            cells.append(cell)
            bodies.append(body_bounds(cell))
        shifts = [(0,0)]*len(cells)
        heads = []
        if job['action'] in (0,1,3,5,6):
            for cell, body in zip(cells,bodies):
                head = body_bounds(cell.crop((body[0],body[1],body[2],body[1]+round((body[3]-body[1])*.35))))
                heads.append((body[0]+(head[0]+head[2])*.5,body[1]+head[1],head[2]-head[0]))
            anchors = [(statistics.median(h[0] for h in heads[i:i+job['cols']]),
                        statistics.median(h[1] for h in heads[i:i+job['cols']]))
                       for i in range(0,len(heads),job['cols'])]
            # Generated rows can have different baselines; preserve motion within each row.
            shifts = [(anchors[i//job['cols']][0]-anchors[0][0],anchors[i//job['cols']][1]-anchors[0][1]) for i in range(len(cells))]
            bodies = [(b[0]-s[0],b[1]-s[1],b[2]-s[0],b[3]-s[1]) for b,s in zip(bodies,shifts)]
        # Register once per clip; retain intra-clip movement instead of resizing every pose.
        reference = bodies[:min(3, len(bodies))] if job['action'] in (5, 6, 10) else bodies
        body_height = statistics.median(b[3]-b[1] for b in reference)
        # One stance-height ruler for every direction; hair width is not body scale.
        units = body_height/HEIGHT[job['action']]
        head_width = 0
        if job['action'] in (0, 3):
            head_width = statistics.median(h[2] for h in heads)
        root_x = statistics.median((b[0]+b[2])*.5 for b in reference)
        root_y = statistics.median(b[3] for b in reference)-7*units
        if job['action'] == 10:
            # Settle the final fallen body onto the floor without removing the initial knockback.
            for i, body in enumerate(bodies):
                settle = max(0,min(1,(i/max(1,len(bodies)-1)-.55)/.45))
                shifts[i] = (0,(body[3]-7*units-root_y)*settle*settle*(3-2*settle))
        frames = []
        for cell, shift in zip(cells,shifts):
            # Trim only the nearly invisible generative padding before preparing the atlas.
            bounds = cell.getchannel('A').point(lambda a: 255 if a >= 12 else 0).getbbox()
            assert bounds
            art = cell.crop(bounds)
            art = art.resize((max(1, round(art.width*SCALE/units)), max(1, round(art.height*SCALE/units))), Image.Resampling.LANCZOS)
            key = (art.size, hashlib.sha256(art.tobytes()).hexdigest())
            unique.setdefault(key, art)
            frames.append((key, round((bounds[0]-shift[0]-root_x)*SCALE/units), round((bounds[1]-shift[1]-root_y)*SCALE/units)))
        key = f'{job["action"]}:{job["direction"]}'
        clips[key] = dict(source['clips'][key], frames=frames, illustrated_master=str(path.relative_to(ROOT)),
                          authoring_body_height=body_height, authoring_units=units, authoring_body_bounds=bodies,
                          authoring_head_width=head_width)
        hashes[str(path.relative_to(ROOT))] = sha(path)
    pages = [Image.new('RGBA', (2048, 2048))]
    shelves, regions = [], {}
    for key, art in sorted(unique.items(), key=lambda item: -item[1].height):
        w, h = art.size
        assert w+4 <= 2048 and h+4 <= 2048, (w, h)
        shelf = next((s for s in shelves if s[3] >= h and s[2]+w+2 <= 2048), None)
        if shelf is None:
            y = max((s[1]+s[3]+4 for s in shelves if s[0] == len(pages)-1), default=2)
            if y+h+2 > 2048:
                pages.append(Image.new('RGBA', (2048, 2048)))
                y = 2
            shelf = [len(pages)-1, y, 2, h]
            shelves.append(shelf)
        page, y, x, _ = shelf
        pages[page].paste(art, (x, y))
        assert pages[page].crop((x, y, x+w, y+h)).tobytes() == art.tobytes()
        regions[key] = [page, x, y, w, h]
        shelf[2] += w+4
    for clip in clips.values():
        clip['frames'] = [regions[key]+[x, y] for key, x, y in clip['frames']]
    destination = REVIEW / 'Candidate' if pilot else OUT
    destination.mkdir(parents=True, exist_ok=True)
    # Only generated pages may be removed when a new packing uses fewer atlases.
    for stale in destination.glob('atlas-*.png'):
        if int(stale.stem.split('-')[1]) >= len(pages):
            stale.unlink()
            stale.with_suffix('.png.import').unlink(missing_ok=True)
    memory = 0
    for i, page in enumerate(pages):
        height = max(s[1]+s[3]+2 for s in shelves if s[0] == i)
        page = page.crop((0, 0, 2048, height))
        page.save(destination / f'atlas-{i}.png')
        memory += page.width*page.height*4
    identity = WORK / 'identity-long-blade.png'
    for reference in (WORK / 'identity-master.png', identity):
        hashes[str(reference.relative_to(ROOT))] = sha(reference)
    portrait = Image.open(identity).convert('RGBA')
    portrait.thumbnail((512, 640), Image.Resampling.LANCZOS)
    portrait.save(destination / 'portrait.png')
    # This crop frames the approved concept's face for the existing circular HUD.
    Image.open(identity).convert('RGBA').crop((325, 0, 975, 650)).resize((256, 256), Image.Resampling.LANCZOS).save(destination / 'hud_portrait.png')
    result = dict(source, clips=clips, pages=len(pages), unique_frames=len(unique), pixel_scale=SCALE,
                  illustrated=True, master_hashes=hashes, texel_bytes=memory,
                  texture_hashes={p.name: sha(p) for p in destination.glob('*.png')},
                  original_motion_sha256=sha(SOURCE / 'motions.json'))
    (destination / 'motions.json').write_text(json.dumps(result, separators=(',', ':'))+'\n')
    print(f'Baked {len(clips)} illustrated clips / {sum(len(c["frames"]) for c in clips.values())} frames, {memory/2**20:.2f} MiB of RGBA texels.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('prepare', 'bake'))
    parser.add_argument('--source', type=Path, default=ROOT.parent / 'Magic Power')
    parser.add_argument('--pilot', action='store_true')
    args = parser.parse_args()
    prepare(args.source) if args.command == 'prepare' else bake(args.pilot)
