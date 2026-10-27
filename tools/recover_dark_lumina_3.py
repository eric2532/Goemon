"""Recover the retail final-form body, retaining every source pose and stream."""
import json
import struct
from recover_vambee_wolf import RECOVERY, OUT, assemble, streams

BASE = 0x801A00D8
SOURCE = 'raw/SC07.CD.dir/FILE_004.dir/1.1'
TABLE = 0x801B6E94
RANGES = [(0x801EEAC8, 0x801EFA00), (0x801AFC60, 0x801AFCD0)]


def main():
    data = (RECOVERY / SOURCE).read_bytes()
    assert struct.unpack_from('<I', data)[0] == 0x73
    assert struct.unpack_from('<I', data, 0x801AFBE8 - BASE)[0] == TABLE
    clips = [clip for start, end in RANGES for clip in streams(data, start, end, BASE)]
    assert len(clips) == 16
    semantics = dict(idle='Source__801eeac8', walk='Source__801eeac8',
                     attack='Source__801ef270', hurt='Source__801ef9a8', death='Source__801ef940',
                     sword_charge='Source__801eeea0', sword_combo='Source__801ef3b8',
                     sword_retreat='Source__801ef6d0', sword_recover='Source__801ef7d8',
                     earth='Source__801eecb8', water='Source__801eeb70',
                     fire='Source__801eeb70', wind='Source__801ef088', sky='Source__801ef8a0',
                     cast='Source__801ef4c0', cast_hold='Source__801afc60', cast_end='Source__801ef5c8')
    assemble(SOURCE, 'dark_lumina_3', TABLE, 17, clips, semantics, BASE)
    path = OUT / 'dark_lumina_3_motion.json'
    manifest = json.loads(path.read_text())
    manifest['identity'] = dict(module_id='0x73', initializer='0x801a0230',
        descriptor='0x801afbe4', model_list=hex(TABLE),
        evidence='Finale module; initializer copies all 17 model pointers. Module 0x72 is the separate second form.')
    manifest['notes'].append('Source -5 streams unfold the engine ping-pong traversal, including its repeated final pose.')
    path.write_text(json.dumps(manifest, indent=2) + '\n')
    copies = streams(data, 0x801EFA00, 0x801EFA80, BASE)
    assemble(SOURCE, 'dark_lumina_3_sky_copy', 0x801BA9E8, 10, copies,
             dict.fromkeys(['idle', 'walk', 'attack', 'hurt', 'death'], copies[0]['name']), BASE)


if __name__ == '__main__':
    main()
