"""Recover Dark Lumina II's retail battle model and every original motion stream."""
import json
import struct
from recover_vambee_wolf import RECOVERY, OUT, assemble, streams

BASE = 0x801A00D8
SOURCE = 'raw/SC07.CD.dir/FILE_003.dir/1.1'
TABLE = 0x801AE21C
RANGES = [(0x801F0008, 0x801F2260), (0x801A63BC, 0x801A6854)]


def main():
    data = (RECOVERY / SOURCE).read_bytes()
    assert struct.unpack_from('<I', data)[0] == 0x72
    assert struct.unpack_from('<I', data, 0x801A6878 - BASE)[0] == TABLE
    clips = [clip for start, end in RANGES for clip in streams(data, start, end, BASE)]
    assert len(clips) == 21
    semantics = dict(idle='Source__801f0008', walk='Source__801f01f0',
                     attack='Source__801f1198', hurt='Source__801f1898',
                     death='Source__801f1a58', fireballs='Source__801a6544',
                     shockwave='Source__801f0478', grab='Source__801f1340',
                     recover='Source__801f1238', rest='Source__801a63fc')
    assemble(SOURCE, 'dark_lumina_2', TABLE, 19, clips, semantics, BASE)
    path = OUT / 'dark_lumina_2_motion.json'
    manifest = json.loads(path.read_text())
    manifest['identity'] = dict(module_id='0x72', initializer='0x801a026c', dispatcher='0x801a01d4',
                                descriptor='0x801a6874', model_list=hex(TABLE),
                                evidence='19-part green second-form battle model; separate from chase overlay and module 0x73 finale.')
    path.write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
