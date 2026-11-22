"""Recover missing directional guard poses for the playable Cross Gate roster."""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image

from recover_crossgate_kaz_skins import SKINS
from recover_crossgate_kazi import OUT


def pack_guards(cg, folder, records, cell, origin):
    width, height = cell
    atlas = Image.new('RGBA', (8 * width, len(records) * height))
    for row, record in enumerate(records):
        _, _, clips = cg.actor(record)
        guards = [clip for clip in clips if clip['action'] == 9 and clip['frames']]
        assert sorted(clip['direction'] for clip in guards) == list(range(8)), record
        for clip in guards:
            assert len(clip['frames']) == 1
            image, x, y = cg.frame_parts(record, clip['index'], 0)
            left, top, right, bottom = image.getbbox()
            frame = image.crop((left, top, right, bottom))
            local_x, local_y = origin[0] + x + left, origin[1] + y + top
            assert 0 < local_x < local_x + frame.width < width
            assert 0 < local_y < local_y + frame.height < height
            px = clip['direction'] * width + local_x
            py = row * height + local_y
            atlas.paste(frame, (px, py))
            assert atlas.crop((px, py, px + frame.width, py + frame.height)).tobytes() == frame.tobytes()
    atlas.save(folder / 'jump-guard.png')
    return len(records) * 8


def recover(source):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg

    count = pack_guards(cg, OUT, ['ex:1727', *SKINS.values()], (100, 112), (50, 91))
    crossgate = OUT.parent
    # Uru's main atlas already includes guard. Each other sheet follows the live weapon order.
    manifests = [crossgate / 'maze/motions.json', *sorted((crossgate / 'shin').glob('*/motions.json'))]
    for path in manifests:
        appearance = json.loads(path.read_text())
        records = [appearance['key'], *(stance['key'] for stance in appearance.get('weapons', []))]
        if 'dagger_key' in appearance:
            records.append(appearance['dagger_key'])
        count += pack_guards(cg, path.parent, records, (120, 132), (62, 100))
    print(f'{count} guard poses preserved with their source origins in {1 + len(manifests)} sheets.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Preserved Magic Power project')
    recover(parser.parse_args().source)
