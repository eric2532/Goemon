"""Stitch the original water-dragon item into basic Shin's existing sword poses."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

from recover_crossgate_kazi import ROOT, pack_frames
from prepare_crossgate_kazi_attack import packed_frame
from prepare_shin_red_lightning_run import move_blade

SKIN = 900050
ART = ROOT / 'assets/characters/crossgate/shin'
OUT = ART / str(SKIN)
SIZE, ORIGIN = (320, 288), (160, 192)
SWORD_SCALE = 1.5 * 1.15
SWORD_LENGTH_SCALE = .9
RECIPE = Path(__file__).with_name('shin_water_dragon_splices.json')
WAVE_SIZE, WAVE_ORIGIN = (768, 768), (384, 384)


def blue_theme(image):
    palette = {}
    for _, pixel in image.getcolors(image.width * image.height):
        r, g, b, a = pixel
        color=pixel
        if r > 18 and b < 9 and r > g * 3:
            color=(r * 4 // 5, (r + g) // 6, min(255, r + g // 3), a)
            # Preserve dark edges used by blade cleanup; lift the hair's midtones and highlights.
            if max(color[:3])>46:
                color=(min(255, 35 + r * 3 // 4), min(255, 35 + (r + g) * 9 // 20), min(255, 60 + r * 4 // 5), a)
        elif b>r*1.3 and g>r*1.2 and b>g*1.05 and max(r,g,b)>52:
            color=(r*9//10,g*9//10,b*9//10,a)
        palette[pixel]=color
    result = image.copy()
    result.putdata([palette[pixel] for pixel in image.getdata()])
    return result



def prepare_counter(check=False):
    with Image.open(ART/'counter.png') as source:
        r,g,b,a=source.convert('RGBA').split()
        image=Image.merge('RGBA',(ImageChops.darker(r,b),g,ImageChops.lighter(r,b),a))
    path=OUT/'counter-blue.png';OUT.mkdir(exist_ok=True)
    if check:
        with Image.open(path) as existing:assert existing.convert('RGBA').tobytes()==image.tobytes()
    else:
        image.save(path)
        settings=path.with_suffix('.png.import')
        if settings.exists():settings.write_text(settings.read_text().replace('process/fix_alpha_border=false','process/fix_alpha_border=true'))
        else:settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="res://'+str(path.relative_to(ROOT))+'"\n[params]\ncompress/mode=0\nprocess/fix_alpha_border=true\nmipmaps/generate=false\n')


def blue_waves():
    folder = ART / '111625'
    source = json.loads((folder / 'motions.json').read_text())
    pages = [Image.open(folder / f'atlas-{i}.png').convert('RGBA') for i in range(source['pages'])]

    def canvas(frame):
        p, x, y, w, h, ox, oy = frame
        image = Image.new('RGBA', WAVE_SIZE)
        image.alpha_composite(pages[p].crop((x, y, x + w, y + h)), (WAVE_ORIGIN[0] + ox, WAVE_ORIGIN[1] + oy))
        return image

    waves = {}
    for direction in range(8):
        pose = f'5:{direction}'
        frames = source['clips'][pose]['frames']
        body = Image.new('L', WAVE_SIZE)
        # Raised-weapon masks cut holes above the head; waves use only the later strike/recovery body.
        for index in (10, 11, 24):
            frame = frames[index]
            assert frame[3] < 150 and frame[4] < 150, (pose, index)
            body = ImageChops.lighter(body, canvas(frame).getchannel('A'))
        body = body.filter(ImageFilter.MaxFilter(5))
        waves[pose] = []
        for frame in frames:
            wave = None
            if frame[3] >= 150 or frame[4] >= 150:
                image = canvas(frame)
                alpha = ImageChops.subtract(image.getchannel('A'), body)
                r, g, b, _ = image.split()
                image = Image.merge('RGBA', (b, g, r, alpha))
                box = image.getbbox()
                assert box, pose
                wave = (image.crop(box), box[0] - WAVE_ORIGIN[0], box[1] - WAVE_ORIGIN[1])
            waves[pose].append(wave)
    for page in pages:
        page.close()
    return waves


def stitch(body, sword, pose, bare=None):
    if pose is None:
        return body.copy(), Image.new('L', SIZE)
    # Keep the reviewed source coordinates; padded packing allows the larger blade's full swing.
    base, grip, tip = ([pose[k][0] + ORIGIN[0] - 96, pose[k][1] + ORIGIN[1] - 116] for k in ('base', 'grip', 'tip'))
    band = Image.new('L', SIZE)
    ImageDraw.Draw(band).line((*base, *tip), fill=255, width=11 if bare is not None else 5)
    hilt = Image.new('L', SIZE)
    for polygon in pose.get('erase_hilt', []):
        ImageDraw.Draw(hilt).polygon([(x + ORIGIN[0] - 96, y + ORIGIN[1] - 116) for x, y in polygon], fill=255)
    mask = Image.new('L', SIZE)
    vx, vy = tip[0] - base[0], tip[1] - base[1]
    left,top,right,bottom=ImageChops.lighter(band,hilt).getbbox()
    for y in range(top,bottom):
        for x in range(left,right):
            r, g, b, a = body.getpixel((x, y))
            if bare is not None and (body.getpixel((x, y)) == bare.getpixel((x, y))
                                     or (abs(x - grip[0]) <= 2 and abs(y - grip[1]) <= 2)):
                continue
            along = (x - base[0]) * vx + (y - base[1]) * vy
            if hilt.getpixel((x, y)) and a:
                mask.putpixel((x, y), 255)
            elif band.getpixel((x, y)) and along >= (-12 if bare is not None else 0) and a and (
                (min(r, g, b) > 110 and max(r, g, b) - min(r, g, b) < 43)
                or (g > r * 1.6 and g > b * 1.3) or max(r, g, b) <= 46
            ):
                mask.putpixel((x, y), 255)
    clean = body.copy()
    clean.putalpha(ImageChops.subtract(clean.getchannel('A'), mask))
    # Reuse the existing offline blade transform; original hands/body occlude the item.
    tip = [grip[i] + (tip[i] - grip[i]) * SWORD_SCALE * SWORD_LENGTH_SCALE for i in (0, 1)]
    # The source wrist turns between the raised pose and the descending cut.
    across = .55 * SWORD_SCALE * min(1, pose.get('projected_width', 3.1) / 3.1)
    if pose.get('edge_flip', False):across = -across
    fitted = move_blade(sword, ((48, 39), (2, 1), 1), (grip, tip, across), SIZE)
    return Image.alpha_composite(fitted.crop((0, 0, *SIZE)), clean), mask


def prepare(source, check=False):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg
    import cg_library

    original = json.loads((ART / '100050/motions.json').read_text())
    native = next(s for s in original['weapons'] if s['weapon'] == 'sword')
    manifest = deepcopy(native)
    if (OUT/'motions.json').exists():
        prepared=json.loads((OUT/'motions.json').read_text()).get('prepared_weapons',{})
        if prepared:manifest['prepared_weapons']=prepared
    pages = [Image.open(ART / f'100050/atlas-{i}.png').convert('RGBA') for i in range(original['pages'])]
    pages += [Image.open(ART / f'100050/cast-{i}.png').convert('RGBA') for i in range(original['cast_pages'])]
    item = cg_library.image_from_record('original', 251582)
    sword = Image.new('RGBA', SIZE)
    sword.alpha_composite(item)
    recipe = json.loads(RECIPE.read_text())
    unique, clips, bodies, masks, references = {}, {}, {}, {}, {}
    for pose, motion in native['clips'].items():
        poses = list(dict.fromkeys(tuple(f) for f in motion['frames']))
        bodies[pose] = []
        for frame in motion['frames']:
            p, x, y, w, h, ox, oy = frame
            body = Image.new('RGBA', SIZE)
            body.alpha_composite(pages[p].crop((x, y, x + w, y + h)), (ORIGIN[0] + ox, ORIGIN[1] + oy))
            bodies[pose].append((blue_theme(body), poses.index(tuple(frame))))
        if pose.startswith(('0:', '1:', '3:')):
            references[pose] = []
            assert len(original['clips'][pose]['frames']) == len(motion['frames'])
            for p, x, y, w, h, ox, oy in original['clips'][pose]['frames']:
                bare = Image.new('RGBA', SIZE)
                bare.alpha_composite(pages[p].crop((x, y, x + w, y + h)), (ORIGIN[0] + ox, ORIGIN[1] + oy))
                references[pose].append(blue_theme(bare))
    for clip in cg.actor(native['key'])[2]:
        if clip['action'] != 9 or not clip['frames']:
            continue
        pose = f"9:{clip['direction']}"
        image, x, y = cg.frame_parts(native['key'], clip['index'], 0)
        body = Image.new('RGBA', SIZE)
        body.alpha_composite(image, (ORIGIN[0] + x, ORIGIN[1] + y))
        bodies[pose] = [(blue_theme(body), 0)]
        manifest['clips'][pose] = dict(duration=clip['duration'] / 1000, source_clip=clip['index'])
    # Reuse a resting body only where the saved recipe explicitly requests it.
    for direction in (5, 6, 7):
        pose, rest = f'5:{direction}', f'0:{direction}'
        if not recipe[f'{pose}:7'].get('body_pose'):
            continue
        assert recipe[f'{pose}:7']['body_pose'] == f'{rest}:0'
        bodies[pose] = [(bodies[rest][0][0] if index == 7 else body, index) for body, index in bodies[pose]]
        references[pose] = [references[rest][0] if index == 7 else None for _, index in bodies[pose]]
    OUT.mkdir(exist_ok=True)
    prepare_counter(check)
    waves = blue_waves()
    for pose, frames in bodies.items():
        clip = deepcopy(manifest['clips'][pose])
        clip['frames'] = []
        prepared = {}
        if pose in waves:
            assert len(waves[pose]) == len(frames), 'Original wave and sword frame counts must agree'
        for frame_index, (body, index) in enumerate(frames):
            key = f'{pose}:{index}'
            if index not in prepared:
                bare = references[pose][frame_index] if pose in references else None
                result, masks[key] = stitch(body, sword, recipe[key], bare)
                left, top, right, bottom = result.getbbox()
                assert left > 0 and top > 0 and right < SIZE[0] and bottom < SIZE[1], ('Clipped sword', key)
                prepared[index] = result
            result = prepared[index]
            origin = ORIGIN
            wave = waves.get(pose, [])[frame_index] if pose in waves else None
            if wave is not None:
                combined = Image.new('RGBA', WAVE_SIZE)
                combined.alpha_composite(wave[0], (WAVE_ORIGIN[0] + wave[1], WAVE_ORIGIN[1] + wave[2]))
                combined.alpha_composite(result, (WAVE_ORIGIN[0] - ORIGIN[0], WAVE_ORIGIN[1] - ORIGIN[1]))
                result, origin = combined, WAVE_ORIGIN
            clip['frames'].append(packed_frame(result, -origin[0], -origin[1], unique))
            assert clip['frames'][-1] is not None, key
        clips[pose] = clip
    from tempfile import TemporaryDirectory
    with TemporaryDirectory(prefix='goemon-water-dragon-') as temporary:
        staging = Path(temporary)
        count = pack_frames(clips, unique, staging)
        manifest.update(id=SKIN, pages=count, clips=clips, source_weapons={'sword': native['key']},
                        stitched_weapon={'body_skin': 100050, 'item': 'original:251582', 'serial': 26300,
                                         'recipe_sha256': hashlib.sha256(RECIPE.read_bytes()).hexdigest(),
                                         'item_rgba_sha256': hashlib.sha256(item.tobytes()).hexdigest(),
                                         'scale': SWORD_SCALE, 'length_scale': SWORD_LENGTH_SCALE,
                                         'item_grip': [48, 39], 'theme': 'light lavender hair',
                                         'recovery_reuse': {'action': 0, 'pose': 0, 'directions': [d for d in (5, 6, 7) if recipe[f'5:{d}:7'].get('body_pose')]},
                                         'wave_source': 'puk2:1108', 'wave_palette': 'BGR'})
        (staging / 'motions.json').write_text(json.dumps(manifest, separators=(',', ':')) + '\n')
        item.save(staging / 'water-dragon-sword.png')
        frame = clips['0:4']['frames'][0]
        p, x, y, w, h, ox, oy = frame
        with Image.open(staging / f'atlas-{p}.png') as atlas:
            atlas.crop((x, y, x + w, y + h)).save(staging / 'portrait.png')
        for file in staging.iterdir():
            if check:
                assert (OUT / file.name).read_bytes() == file.read_bytes(), file.name
            else:
                (OUT / file.name).write_bytes(file.read_bytes())
        if not check:
            for file in OUT.glob('*.png'):
                settings = file.with_suffix('.png.import')
                if settings.exists():
                    settings.write_text(settings.read_text().replace('process/fix_alpha_border=false', 'process/fix_alpha_border=true'))
                else:
                    settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="res://'
                        + str(file.relative_to(ROOT)) + '"\n[params]\ncompress/mode=0\nprocess/fix_alpha_border=true\nmipmaps/generate=false\n')
    catalog_path = ART / 'skins.json'
    catalog = json.loads(catalog_path.read_text())
    entry = [SKIN, '水龍shin', [ox, oy], False]
    if check:
        assert entry in catalog
    else:
        catalog = [row for row in catalog if row[0] != SKIN] + [entry]
        catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
    weapons_path = ART.parent / 'weapons/catalog.json'
    weapons = json.loads(weapons_path.read_text())
    route = {'sword': {'native': 0}, **manifest.get('prepared_weapons',{})}
    if check:
        assert weapons['37'][str(SKIN)] == route
    else:
        weapons['37'][str(SKIN)] = route
        weapons_path.write_text(json.dumps(weapons, indent=2) + '\n')
    print(f'WATER_DRAGON {"CHECK" if check else "PREPARE"}: {len(clips)} existing directional clips, {len(unique)} stitched drawings, {count} atlas page(s)')
    return manifest, bodies, masks


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    prepare(args.source.resolve(), args.check)
