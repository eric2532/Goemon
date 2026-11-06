"""Extract Kazi's original eight-direction pixels; never run or alter the client."""
import argparse
import hashlib
import json
import sys
import wave
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/crossgate/kazi'
ACTIONS = (0, 1, 3, 5, 6, 8, 10)


def recover(source):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg
    import cg_sounds

    key = 'ex:1727'
    ident, pack, originals = cg.actor(key)
    assert ident == 102488
    info = cg.clip_metadata(key)
    OUT.mkdir(parents=True, exist_ok=True)
    unique = {}
    clips = {}
    for clip in originals:
        if clip['action'] not in ACTIONS:
            continue
        assert info['clips'][clip['index']]['available']
        frames = []
        for index in range(len(clip['frames'])):
            image, ox, oy = cg.frame_parts(key, clip['index'], index)
            box = image.getbbox()
            assert box, (clip['index'], index)
            image = image.crop(box)
            digest = (image.size, hashlib.sha256(image.tobytes()).hexdigest())
            unique.setdefault(digest, image)
            frames.append((digest, ox + box[0], oy + box[1]))
        clips[f"{clip['action']}:{clip['direction']}"] = {
            'duration': clip['duration'] / 1000, 'frames': frames,
            'source_clip': clip['index'], 'source_frames': clip['frames'],
            'sounds': cg_sounds.clip_cues(clip),
        }
    assert len(clips) == len(ACTIONS) * 8
    pages = [Image.new('RGBA', (2048, 2048))]
    regions = {}
    shelves = []
    for digest, image in sorted(unique.items(), key=lambda pair: -pair[1].height):
        w, h = image.size
        assert w + 2 <= 2048 and h + 2 <= 2048
        shelf = next((s for s in shelves if s[3] >= h and s[2] + w + 1 <= 2048), None)
        if shelf is None:
            bottom = max((s[1] + s[3] + 2 for s in shelves if s[0] == len(pages) - 1), default=1)
            if bottom + h + 1 > 2048:
                pages.append(Image.new('RGBA', (2048, 2048)))
                bottom = 1
            shelf = [len(pages) - 1, bottom, 1, h]
            shelves.append(shelf)
        page, top, left, _ = shelf
        pages[page].paste(image, (left, top))
        regions[digest] = [page, left, top, w, h]
        shelf[2] += w + 2
        assert pages[page].crop((left, top, left + w, top + h)).tobytes() == image.tobytes()
    for clip in clips.values():
        clip['frames'] = [regions[digest] + [ox, oy] for digest, ox, oy in clip['frames']]
    for i, page in enumerate(pages):
        height = max(s[1] + s[3] + 1 for s in shelves if s[0] == i)
        page.crop((0, 0, 2048, height)).save(OUT / f'atlas-{i}.png')
    for stale in OUT.glob('atlas-*.png'):
        if int(stale.stem.split('-')[1]) >= len(pages):
            stale.unlink()
            stale.with_suffix('.png.import').unlink(missing_ok=True)
    hashes = {}
    for name in ('AnimeInfoEX_1.Bin', 'AnimeEX_1.Bin', 'GraphicInfoEX_5.bin', 'GraphicEX_5.bin'):
        path = cg.SOURCE / name
        if path.is_file():
            hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest = dict(name='Kazi', id=ident, key=key, source_hashes=hashes,
                    pages=len(pages), unique_frames=len(unique), clips=clips)
    (OUT / 'motions.json').write_text(json.dumps(manifest, separators=(',', ':')) + '\n')
    portrait = cg.frame_image(key, 57, 0)
    portrait = portrait.crop(portrait.getbbox())
    portrait.save(OUT / 'portrait.png')
    audio = ROOT / 'assets/audio/crossgate/kazi'
    audio.mkdir(parents=True, exist_ok=True)
    sound_manifest = json.loads((source / 'godot/assets/sounds/manifest.json').read_text())
    recovered = {}
    for ident in ('103', '255'):
        spec = sound_manifest['sounds'][ident]
        path = source / 'godot/assets' / spec['file']
        with wave.open(str(path), 'rb') as stream:
            pcm = stream.readframes(stream.getnframes())
        assert hashlib.sha256(pcm).hexdigest() == spec['pcmSha256']
        (audio / path.name).write_bytes(path.read_bytes())
        recovered[ident] = spec
    assert all(cue['id'] == 103 for c in clips.values() if originals[c['source_clip']]['action'] == 5 for cue in c['sounds'])
    (audio / 'provenance.json').write_text(json.dumps(dict(sounds=recovered,
        swing='Original ex:1727 attack-frame markers, zero-based frames 3/7; direction 0 has only frame 3.',
        hit='Recovered Cross Gate generic physical impact 255; Kazi-specific contact selection is unverified.'), indent=2) + '\n')
    print(f'Kazi: {len(clips)} clips, {len(unique)} unique frames, {len(pages)} atlases; exact pixel checks passed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Preserved Magic Power project')
    recover(parser.parse_args().source)
