"""Prepare the selected Frost Dragon landing and hunting cues."""
import array
import hashlib
import json
import struct
import wave
from recover_monster_audio import ROOT, RECOVERY, recover


def main():
    source = 'raw/SC04.CD.dir/FILE_011.dir/0.4.dec'
    code = (RECOVERY / source).read_bytes()
    base = 0x80128158
    # This owner writes the known Frost Dragon HP and starts event B37 at battle entry.
    assert struct.unpack_from('<II', code, 0x80182984-base) == (0x3c01801f, 0xa422fd28)
    assert struct.unpack_from('<III', code, 0x80187158-base) == (0x24040b37, 0x0c00b532, 0x00002821)
    output = ROOT / 'assets/audio/recovered_frost_dragon'
    catalog = ROOT / 'build/Other Files/Asset Toolkit/Dragoon Frost Dragon Audio/Source Catalog'
    recover('frost_dragon', 'SC04', 11, {0xb37: 'roar'}, 51, output, catalog,
            ['Frost Dragon HP at 0x801EFD28 identifies SC04/011.',
             'Opening handler 0x80187068 calls B37 at 0x8018715C after starting the boss HP display.',
             'Adaptation: Dragoon Dragon Leap voice on landing; original impact and combat unchanged.'])
    event = json.loads((output / 'sources.json').read_text())['events']['b37:0']
    assert len(event['layers']) == 2
    assert all(layer['sample_index'] == 20 and layer['pitch_q8'] == 0x4000 for layer in event['layers'])
    selected = json.loads((output / 'sources.json').read_text())['events']['ba9:0']
    source = ROOT / selected['file']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == selected['sha256']
    with wave.open(str(source), 'rb') as wav:
        assert wav.getnchannels() == 1 and wav.getsampwidth() == 2 and wav.getframerate() == 44100
        pcm = array.array('h', wav.readframes(wav.getnframes()))
    peak = max(map(abs, pcm))
    pcm = array.array('h', (round(value * .4 * 32767 / peak) for value in pcm))
    target = output / 'ground_attack.wav'
    with wave.open(str(target), 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(44100); wav.writeframes(pcm.tobytes())
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    assert digest == 'b6a416ab64f03d5439e3413810f0d73861eafbdfefc8fa9d7af5553cfde83db5'
    (output / 'ground_attack_sources.json').write_text(json.dumps(dict(
        selected_preview='08-extended-deeper-ending.wav', event='ba9:0',
        source=selected, sha256=digest, preview_peak=.4,
        usage='User-selected ground hunting onset, separate from the unchanged landing cue.'), indent=2) + '\n')


if __name__ == '__main__':
    main()
