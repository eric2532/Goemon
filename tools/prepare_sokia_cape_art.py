"""Fit Cape's local source-profile rock recess; never alter raw map/actor/collision data."""
import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image
from recover_habaru_encounter import body_rows

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan/sokia/cape'
SCENERY = ROOT / 'assets/maps/falan/sokia/scenery'


def prepare():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_assets as cg
    import cg_library as lib
    raw = (ROOT.parent / 'Magic Power/data/crossgate/source/BlueCrossgate/map/0/15525.dat').read_bytes()
    width, height, floor, objects, flags = lib.parse_map(raw)
    cliffs = json.loads((SCENERY / 'cliffs.json').read_text())
    gorge = json.loads((SCENERY / 'gorge-mass.json').read_text())
    lookup = lib.serial_index()
    profiles, graphics, wall_tiles = {}, {}, {}
    for serial in range(13080, 13116):
        row = cliffs['graphics'].get(str(serial + 200000), {})
        if not row or row.get('void_only'):
            continue
        native = lookup[serial]
        image = lib.image_from_record(native['pack'], native['row'])
        assert row['rgba_sha256'] == hashlib.sha256(image.tobytes()).hexdigest()
        profile = copy.deepcopy(row['profile'])
        profile.update(paint_source=serial, paint_rect=row['rect'])
        profiles[str(serial)] = profile
        graphics[str(serial)] = dict(origin=row['origin'], footprint=[max(1, native['east']), max(1, native['south'])])
        family = str(13080 + (serial - 13080) // 12 * 12)
        donor = str(gorge['wall_paint_sources'][family]['serial'])
        wall_tiles[str(serial)] = gorge['wall_tiles'][donor]
    ident, _, clips = cg.actor('original:2975')
    assert ident == 101923
    idle = next(c for c in clips if c['action'] == 0 and c['direction'] == 4)
    actor, ox, oy = cg.frame_parts('original:2975', idle['index'], 0)
    top, foot = body_rows(actor)
    profile = []
    for index in range(8):
        y = round(foot - (foot - top) * index / 7)
        pixels = [(x, yy) for yy in range(max(top, y - 14), min(foot + 1, y + 15))
                  for x in range(actor.width)
                  if (p := actor.getpixel((x, yy)))[3] >= 128 and max(p[:3]) > 45 and p[:3] != (20, 20, 20)]
        assert pixels, (index, y)
        profile.append([(ox + min(x for x, _ in pixels)) * .043 - .28,
                        (ox + max(x for x, _ in pixels) + 1) * .043 + .28,
                        (foot - y) * .043 + .08])
    profile[0][2] = -.08
    profile[-1][2] += .35
    source = dict(schema=1, map=15525, size=[width, height], source_sha256=hashlib.sha256(raw).hexdigest(),
                  anchors=[[i % width, i // width, serial] for i, serial in enumerate(objects) if 13080 <= serial <= 13115],
                  profiles=profiles, graphics=graphics, minimum_crown_fraction=.7, tile_unseen_faces=True,
                  wall_tiles=wall_tiles, wall_tile_scale=gorge['wall_tile_scale'], cap_paint=gorge['cap_paint'],
                  texture='res://assets/maps/falan/sokia/scenery/gorge-mass.png',
                  recess=dict(npc='5243', cell=[16, 8], original_key='original:2975', direction=4, raw_origin=[ox, oy],
                              body_top=top, body_foot=foot, pixel_size=.043, profile=profile, depth=[-.55, 2.1],
                              interpretation='Measured NPC clearance volume. Continuous source-footprint walls leave it clear without a runtime cut; physical source barriers remain closed.'),
                  limits=['Original raw planes, NPC cell/ground anchor, body pixels, scale, walk bits, native collision and event gates remain authoritative.',
                          'Continuous source-profile wall volume and unseen caps are inferred 3D surfaces. Measured NPC clearance requires no added hole or runtime shader cut.',
                          'Generated configs305/306 specify wall25–29=0. Their existing adapted wall geometry borrows the adjacent original13080 family paint; this does not recover original random topology.'])
    assert len(source['anchors']) == 138
    atlas = Image.open(SCENERY / 'gorge-mass.png').convert('RGBA')
    x, y, w, h = gorge['wall_tiles'][str(gorge['wall_paint_sources']['13080']['serial'])]
    paint = atlas.crop((x, y, x + w, y + h))
    pixels = list(paint.getdata())
    source['generated_rock_paint'] = dict(source='existing gorge-mass.png family13080 opaque body patch', rect=[x, y, w, h], rgba_sha256=hashlib.sha256(paint.tobytes()).hexdigest(),
                                         mean_rgb=[sum(p[c] for p in pixels) / len(pixels) / 255 for c in range(3)])
    return source, paint


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data, paint = prepare()
    if args.check:
        assert json.loads((OUT / 'rock.json').read_text()) == data
        old = Image.open(OUT / 'rock.png').convert('RGBA')
        assert old.size == paint.size and old.tobytes() == paint.tobytes()
    else:
        (OUT / 'rock.json').write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')
        paint.save(OUT / 'rock.png')
    print('SOKIA_CAPE_ART_SOURCE', len(data['anchors']), 'wall anchors; original NPC footprint/profile and existing brown native paint')


if __name__ == '__main__':
    main()
