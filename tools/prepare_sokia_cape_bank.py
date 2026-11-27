"""Append three whole existing prepared Cape actors; preserve the original thirteen Sokia rows."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

from PIL import Image
from prepare_east_region_population import append_native_bank
from recover_crossgate_hounds import write_atlas

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/crossgate/sokia_region'
SOURCE = ROOT / 'assets/characters/crossgate/east_region'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Cape caves'
SKINS = [1, 58, 59]


def records():
    source = json.loads((SOURCE / 'species.json').read_text())
    names = ['牛鬼公主', '帝國兵的亡靈', '帝國兵的亡靈']
    return [{**source[skin], 'name': name, 'prepared_from': dict(bank='east_region', skin=skin)}
            for skin, name in zip(SKINS, names)]


def table(folder, data):
    values = list(struct.iter_unpack('<4f', (folder / 'frames.bin').read_bytes()))
    clips = values[:data['clip_count']]
    count = max(int(row[0] + row[1]) for row in clips)
    return clips, values[data['clip_count']:data['clip_count'] + count * 2]


def snapshot(folder):
    data = json.loads((folder / 'motions.json').read_text())
    clips, frames = table(folder, data)
    stride = len(data['timelines']) // len(data['variants']) // 8
    return dict(variants=data['variants'][:13], clips=clips[:13 * len(data['actions']) * 8],
                frames=frames, timelines=[data['timelines'][i:i + 32] for i in range(0, 13 * 8 * stride, stride)],
                sounds={k: v for k, v in data['sounds'].items() if int(k.split(':')[0]) < 13},
                palette=Image.open(folder / 'palette.png').convert('RGBA').tobytes(),
                pngs={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.glob('atlas-*.png')})


def prepare():
    current = json.loads((OUT / 'motions.json').read_text())
    proof = REPORT / 'boss-bank-preservation.json'
    if len(current['variants']) >= 16:
        assert [r['id'] for r in current['variants'][13:16]] == [r['id'] for r in records()]
        if proof.exists() and json.loads(proof.read_text()).get('compacted_indexed_frames'):
            return
        assert len(current['variants']) == 16, 'Do not rebuild a prefix while another source actor addition exists'
        clips, frames = table(OUT, current)
        clips = clips[:13 * len(current['actions']) * 8]
        frames = frames[:max(int(r[0] + r[1]) for r in clips) * 2]
        values = clips + frames
        width = int(current['table_width'])
        values += [(0, 0, 0, 0)] * (-len(values) % width)
        (OUT / 'frames.bin').write_bytes(b''.join(struct.pack('<4f', *r) for r in values))
        palette = Image.open(OUT / 'palette.png').convert('RGBA')
        added_rows = Image.open(SOURCE / 'palette.png').height
        palette.crop((0, 0, 256, palette.height - added_rows)).save(OUT / 'palette.png')
        stride = int(current['timeline_stride'])
        current.update(variants=current['variants'][:13], pages=27, clip_count=len(clips),
                       timelines=[v for i in range(13 * 8) for v in current['timelines'][i * stride:i * stride + 32]],
                       timeline_stride=32, atlas_paths=current['atlas_paths'][:27],
                       sounds={k: v for k, v in current['sounds'].items() if int(k.split(':')[0]) < 13})
        (OUT / 'motions.json').write_text(json.dumps(current, separators=(',', ':')) + '\n')
    assert len(current['variants']) == 13, 'Cape addition requires the preserved thirteen-actor Sokia bank'
    before = snapshot(OUT)
    data = json.loads((SOURCE / 'motions.json').read_text())
    clips, frames = table(SOURCE, data)
    new_clips, new_frames, used = [], [], set()
    actions = len(data['actions'])
    for skin in SKINS:
        for start, count, duration, scale in clips[skin * actions * 8:(skin + 1) * actions * 8]:
            new_clips.append((len(new_frames) // 2, count, duration, scale))
            for i in range(int(start), int(start + count)):
                rect, other = frames[i * 2:i * 2 + 2]
                new_frames.extend([rect, other]); used.add(int(other[2]))
    paths = data['atlas_paths']
    selected = sorted(used)
    stage = REPORT / 'Prepared boss bank'
    stage.mkdir(parents=True, exist_ok=True)
    width = int(data['table_width'])
    images = {i: Image.open(ROOT / paths[i].removeprefix('res://')).convert('L') for i in selected}
    unique, frame_table = {}, []
    for i in range(0, len(new_frames), 2):
        rect, other = new_frames[i:i + 2]
        x, y, w, h = map(int, rect)
        image = images[int(other[2])].crop((x, y, x + w, y + h))
        token = (image.size, image.tobytes())
        unique.setdefault(token, None)
        frame_table.append((token, other[0], other[1], other[3]))
    palette_image = Image.open(SOURCE / 'palette.png').convert('RGBA')
    palettes = [list(palette_image.crop((0, y, 256, y + 1)).getdata()) for y in range(palette_image.height)]
    packed_pages = write_atlas(stage, unique, palettes, new_clips, frame_table, 1024, width)
    stride = int(data['timeline_stride'])
    sounds = {}
    for target, skin in enumerate(SKINS):
        for key, path in data['sounds'].items():
            owner, cue = key.split(':')
            if int(owner) == skin:
                sounds[f'{target}:{cue}'] = path if path.startswith('res://') else 'res://' + str((SOURCE / path).relative_to(ROOT))
    staged = dict(variants=[data['variants'][i] for i in SKINS], actions=data['actions'], pages=packed_pages,
                  table_width=width, clip_count=len(new_clips),
                  timeline_stride=stride,
                  timelines=[value for skin in SKINS for value in data['timelines'][skin * 8 * stride:(skin + 1) * 8 * stride]],
                  sounds=sounds)
    (stage / 'motions.json').write_text(json.dumps(staged, separators=(',', ':')) + '\n')
    base = json.loads((ROOT / 'assets/maps/falan/sokia/population.json').read_text())['extra_species'][:13]
    (OUT / 'species.json').write_text(json.dumps(base, ensure_ascii=False, indent=2) + '\n')
    append_native_bank(OUT, stage, list(range(3)), records())
    active_paths = set(json.loads((OUT / 'motions.json').read_text())['atlas_paths'])
    prefix = hashlib.sha256(str(stage).encode()).hexdigest()[:12]
    for path in OUT.glob(f'append-{prefix}-atlas-*.png'):
        if 'res://' + str(path.relative_to(ROOT)) not in active_paths:
            path.unlink()  # Only obsolete pages generated by this exact Cape stage.
    after = snapshot(OUT)
    assert after['variants'] == before['variants']
    assert after['clips'] == before['clips']
    assert after['frames'][:len(before['frames'])] == before['frames']
    assert after['timelines'] == before['timelines']
    assert after['sounds'] == before['sounds']
    assert after['palette'].startswith(before['palette'])
    assert after['pngs'] == before['pngs']
    evidence = dict(old_actor_count=13, added=records(), old_variants_clips_frames_cues_palette_rows_and_pngs_preserved=True,
                    reused_source_pages=selected, scattered_source_page_count=len(selected), copied_page_count=packed_pages,
                    compacted_indexed_frames=True, source_bank='east_region',
                    source_motions_sha256=hashlib.sha256((SOURCE / 'motions.json').read_bytes()).hexdigest(),
                    original_source_art_untouched=True, native_combat_and_visual_review_required=True)
    (REPORT / 'boss-bank-preservation.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        data = json.loads((OUT / 'motions.json').read_text())
        assert len(data['variants']) >= 16
        assert [r['id'] for r in data['variants'][13:16]] == [r['id'] for r in records()]
        assert json.loads((REPORT / 'boss-bank-preservation.json').read_text())['old_variants_clips_frames_cues_palette_rows_and_pngs_preserved']
    else:
        prepare()
    print('SOKIA_CAPE_BANK exact prepared princess + two soldier entries; original13 preserved; Lorens uses existing companion311')


if __name__ == '__main__':
    main()
