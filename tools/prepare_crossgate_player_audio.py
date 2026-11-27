"""Bind prepared player attack clocks to recovered sound IDs without rebaking art."""
import argparse
from array import array
import hashlib
import json
from pathlib import Path
import re
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/characters/crossgate'
OUT = ROOT / 'assets/audio/crossgate/player-attacks.json'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Cross Gate Player Audio'
# User-selected layers, prepared once so combat still plays one cached voice per cue.
ATTACK_MIXES = {900001: (104, 282), 900002: (134, 266),
              900003: (104, 282, 172), 900004: (134, 266, 290),
              900005: (134, 290), 900006: (102, 262, 267),
              900007: (103, 282), 900008: (133, 266), 900009: (104, 266),
              900010: (134, 264), 900011: (135, 264), 900012: (138, 264),
              900013: (140, 264), 900014: (116, 264)}
KAZ_FIRE_AUDIO = {'ex:1727': (900007, 900008), 'puk2:893': (900001, 900009)}
WATER_WEAPON_AUDIO = {"sword":900010,"axe":900011,"polearm":900012,"staff":900013,"bow":900014,"kunai":900010,"boomerang":900010}
SHIN_SPECIAL_AUDIO = {
    'original:3277': (900001, 900002),  # 1 Glowing Sword
    'puk2:887': (900001, 900002),      # 2 Ember Shields
    'puk2:1107': (900003, 900002),     # 3 Gold Runes + dragon call 172
    'puk2:1108': (104, 900005),        # 4 Gold Lightning: Raikou 290, no Fire
    'puk3:941': (900006, 0),          # 5 Visible punch blast also sounds on a miss; no duplicate on hit.
    'puk3:942': (900001, 900002),      # 6 Yellow Flame
    'puk3:948': (900001, 900004),      # 7 Red Lightning + Raikou 290
    'puk2:784': (108, 138),           # 8 Gold Polearm
    'ch1:660': (104, 134),            # 9 All White: sword
    'ch1:662': (108, 138),            # 9 equipped polearm
}


def mix_pcm(paths):
    layers = []
    for path in paths:
        with wave.open(str(path)) as wav:
            assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, 22050), path
            values = array('h', wav.readframes(wav.getnframes()))
            if sys.byteorder != 'little':
                values.byteswap()
            layers.append(values)
    mixed = [0] * max(map(len, layers))
    for layer in layers:
        for i, value in enumerate(layer):
            mixed[i] += value
    peak = max(map(abs, mixed), default=0)
    gain = min(1.0, 30000 / peak) if peak else 1.0
    values = array('h', (round(value * gain) for value in mixed))
    if sys.byteorder != 'little':
        values.byteswap()
    return values.tobytes()


def manifest_paths():
    catalog = json.loads((ART / 'weapons/catalog.json').read_text())
    roster = (ROOT / 'scripts/rogue_roster.gd').read_text()
    ids = {name: int(value) for name, value in re.findall(r'const (\w+)_ID\s*=\s*(\d+)', roster)}
    roots = {ids[name]: root for name, root in re.findall(r'const (\w+)=\{[^}]*?"root":"([^"]+)"', roster)
             if name in ids}
    roots.update({37: 'shin', 38: 'shin', 39: 'fighters/saizo'})
    paths = set()
    for character, skins in catalog.items():
        character = int(character)
        assert character in roots, ('Missing roster root', character)
        for skin, routes in skins.items():
            if character == 34:
                folder = ART / 'kazi' / ('' if skin == '102488' else 'skins/' + skin)
            elif character == 36 or (character == 35 and skin == '0'):
                folder = ART / roots[character]
            else:
                folder = ART / roots[character] / skin
            paths.add(folder / 'motions.json')
            paths.update(ROOT / route['root'].removeprefix('res://') / 'motions.json'
                         for route in routes.values() if 'root' in route)
    return sorted(paths)


def prepare(source, check=False):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg
    import cg_sounds

    table = cg_sounds.sound_table()
    files = {}
    for script in ['sound_library.gd', 'maze_combat.gd']:
        for value in re.findall(r'preload\("(res://assets/audio/crossgate/[^"\n]+\.wav)"\)', (ROOT/'scripts'/script).read_text()):
            path = ROOT / value.removeprefix('res://')
            files.setdefault(path.name.lower(), path)
    for path in sorted((ROOT / 'assets/audio/crossgate').rglob('*.wav')):
        files.setdefault(path.name.lower(), path)
    profiles, samples, exceptions, hashes, pcm_hashes = {}, {}, [], {}, {}
    count = 0

    def sample(ident):
        if str(ident) in samples:
            return
        if ident == 0:
            samples['0'] = ''  # Explicit source-silent marker, not a fallback.
            return
        if ident in ATTACK_MIXES:
            for source_id in ATTACK_MIXES[ident]:
                sample(source_id)
            paths = [ROOT / samples[str(i)].removeprefix('res://') for i in ATTACK_MIXES[ident]]
            pcm = mix_pcm(paths)
            path = ROOT / f'assets/audio/crossgate/shin/special-mix-{ident}.wav'
            if check:
                with wave.open(str(path)) as wav:
                    assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, 22050)
                    assert wav.readframes(wav.getnframes()) == pcm, path
            else:
                with wave.open(str(path), 'wb') as wav:
                    wav.setparams((1, 2, 22050, 0, 'NONE', 'not compressed'))
                    wav.writeframes(pcm)
            samples[str(ident)] = 'res://' + str(path.relative_to(ROOT))
            pcm_hashes[str(ident)] = hashlib.sha256(pcm).hexdigest()
            return
        name = table[str(ident)]['file'].replace('\\', '/').split('/')[-1].lower()
        path = files[name]
        with wave.open(str(path)) as wav:
            actual = hashlib.sha256(wav.readframes(wav.getnframes())).hexdigest()
        with wave.open(str(cg.SOURCE / 'se' / name)) as wav:
            original = hashlib.sha256(wav.readframes(wav.getnframes())).hexdigest()
        assert actual == original, (ident, path)
        samples[str(ident)] = 'res://' + str(path.relative_to(ROOT))
        pcm_hashes[str(ident)] = original

    for path in manifest_paths():
        data = json.loads(path.read_text())
        root = 'res://' + str(path.parent.relative_to(ROOT)) + '/'
        hashes[root] = hashlib.sha256(path.read_bytes()).hexdigest()
        profiles[root] = []
        for stance in [data] + data.get('weapons', []):
            result = {}
            for clip_key, clip in stance['clips'].items():
                if not (clip_key.startswith('5:') or clip_key.startswith('fist:5:')):
                    continue
                key = data['dagger_key'] if clip_key.startswith('fist:') else stance['key']
                # Fitted Emilia staff art borrows this staff, not the unarmed body's cues.
                fitted = '/fighters/emilia/' in root and 'frame_map' in clip
                if fitted:
                    key = 'puk3:533'
                direction = int(clip_key.rsplit(':', 1)[1])
                original = next(c for c in cg.actor(key)[2] if c['action'] == int(clip.get('source_action',5)) and c['direction'] == direction)
                cues = cg_sounds.clip_cues(original)
                swings = [c['id'] for c in cues if c['flag'] < 10000 or c['flag'] >= 20000]
                hits = [f[3] % 10000 for f in original['frames'] if 10000 <= f[3] < 20000]
                if not hits:
                    hits = [c['id'] for c in cues if c['flag'] >= 20000]
                assert cues or hits, (root, key, clip_key, 'Source has no audio/contact evidence; review the adaptation explicitly')

                def mapped(when, fallback, index, contact):
                    frame = round(float(when) / float(clip['duration']) * len(clip['frames']))
                    mapping = clip.get('frame_map', clip.get('source_frames', []))
                    if mapping and isinstance(mapping[0], int):
                        frame = mapping[min(frame, len(mapping)-1)]
                    if not fitted and 0 <= frame < len(original['frames']):
                        flag = original['frames'][frame][3]
                        if flag and ((flag >= 10000) == contact):
                            return flag % 10000
                    return fallback[min(index, len(fallback)-1)] if fallback else 0

                if clip.get('contact_cues') is not None:
                    impact = clip['contact_cues']
                    expected = [mapped(t, hits, i, True) for i, t in enumerate(clip['contacts'])]
                    assert impact == expected, (root, key, clip_key, impact, expected)
                elif clip.get('contacts'):
                    impact = [mapped(t, hits, i, True) for i, t in enumerate(clip['contacts'])]
                elif 'contact' in clip:
                    impact = [mapped(float(clip['duration'])*float(clip['contact']), hits, 0, True)]
                else:
                    impact = hits
                sound = [mapped(float(c['atMs'])/1000, swings, i, False) for i, c in enumerate(clip.get('sounds', []))
                         if not (c.get('id') == 139 and ('/ruby/' in root or fitted))]
                if not sound:
                    sound = swings[:1] or [0]
                if '/weapons/boomerang/' in root:
                    sound = impact[:1]
                    exceptions.append(dict(root=root, clip=clip_key, source=key,
                        reason='Native action-7 release cue plays at the equipped throw draw/release, without a custom ice layer'))
                if fitted:
                    sound, impact = [109], [140]
                if key == 'ex:1727':
                    impact = [133]  # Approved Kaz cut/blast adaptation has no native hit marker.
                    exceptions.append(dict(root=root, clip=clip_key, source=key, reason='Original Kaz cut/blast keeps approved regular sword impact 133'))
                if key in SHIN_SPECIAL_AUDIO and ('/shin/' in root or root.endswith('/ch1-662/')):
                    swing_id, hit_id = SHIN_SPECIAL_AUDIO[key]
                    sound, impact = [swing_id] * len(sound), [hit_id] * len(impact)
                    exceptions.append(dict(root=root, clip=clip_key, source=key,
                        reason='User-selected Shin Special original-source weapon/effect layers, 2026-11-17'))
                if key in KAZ_FIRE_AUDIO and '/kazi/' in root:
                    rise, hit = KAZ_FIRE_AUDIO[key]
                    # One Fire rise per attack; the second existing cut carries its impact.
                    assert set(sound) == {103 if key == 'ex:1727' else 104}
                    assert set(impact) == {133 if key == 'ex:1727' else 104}
                    sound, impact = [rise] + sound[1:], [impact[0], hit]
                    exceptions.append(dict(root=root, clip=clip_key, source=key,
                        reason='User-selected Kaz 1/4 level-10 Fire layers, 2026-11-17'))
                if '/shin/900050/' in root:
                    if root.endswith('/900050/'):
                        assert set(sound) == {104} and set(impact) == {134}
                    weapon=stance['weapon']
                    if weapon in ('kunai','boomerang') and not any(sound):sound=[112]
                    impact = [WATER_WEAPON_AUDIO[weapon]] * len(impact)
                    exceptions.append(dict(root=root, clip=clip_key, source='original:2902',
                        reason='User-selected Water Dragon weapon impact + 水精 attack effect 264; throws use the existing sword impact, 2026-11-17'))
                assert impact, (root, key, clip_key, 'No contact audio contract')
                result[clip_key] = [sound, impact]
                for ident in sound + impact:
                    sample(ident)
                count += 1
            profiles[root].append(result)
    result = dict(samples=samples, profiles=profiles, manifest_hashes=hashes, pcm_hashes=pcm_hashes,
                  mix_recipes=ATTACK_MIXES, special_overrides=SHIN_SPECIAL_AUDIO,
                  kaz_fire_overrides=KAZ_FIRE_AUDIO)
    encoded = json.dumps(result, separators=(',', ':'), sort_keys=True) + '\n'
    if check:
        assert OUT.read_text() == encoded, 'Player audio contract is stale; rebuild it from source'
    else:
        OUT.write_text(encoded)
    REPORT.mkdir(parents=True, exist_ok=True)
    (REPORT / 'source-verification.json').write_text(json.dumps(dict(clips=count, manifests=len(profiles),
        samples=len(samples), exceptions=exceptions, manifest_hashes=hashes), indent=2)+'\n')
    print(f'PLAYER_AUDIO {"CHECK" if check else "PREPARE"}: {len(profiles)} manifests, {count} attack clips, {len(samples)} samples ({len(ATTACK_MIXES)} prepared mixes), {len(exceptions)} documented adaptations')


def check_local():
    data = json.loads(OUT.read_text())
    expected = {'res://' + str(p.parent.relative_to(ROOT)) + '/' for p in manifest_paths()}
    errors = []
    if data.get('mix_recipes', {}) != {str(i): list(ids) for i, ids in ATTACK_MIXES.items()}:
        errors.append('Player attack audio recipes changed; rebuild player attack audio')
    if data.get('special_overrides', {}) != {key: list(ids) for key, ids in SHIN_SPECIAL_AUDIO.items()}:
        errors.append('Shin Special audio selection changed; rebuild player attack audio')
    if data.get('kaz_fire_overrides', {}) != {key: list(ids) for key, ids in KAZ_FIRE_AUDIO.items()}:
        errors.append('Kaz Fire audio selection changed; rebuild player attack audio')
    if set(data['profiles']) != expected:
        errors.append('Player audio roster/weapon coverage is stale; rebuild with prepare_crossgate_player_audio.py')
    for root, digest in data['manifest_hashes'].items():
        path = ROOT / root.removeprefix('res://') / 'motions.json'
        if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            errors.append('Player attack source changed: ' + str(path))
    for ident, digest in data['pcm_hashes'].items():
        path = ROOT / data['samples'][ident].removeprefix('res://')
        if not path.exists():
            errors.append('Missing player attack sample: ' + str(path))
            continue
        with wave.open(str(path)) as wav:
            actual = hashlib.sha256(wav.readframes(wav.getnframes())).hexdigest()
        if actual != digest:
            errors.append('Changed player attack PCM: ' + str(path))
    return errors


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    prepare(args.source.resolve(), args.check)
