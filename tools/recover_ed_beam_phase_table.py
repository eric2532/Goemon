"""Extract the native RotMatrix lookup as an automatically exported Godot resource."""
from pathlib import Path
import hashlib
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery/raw/SLUS_007.26')
blob = SOURCE.read_bytes()
expected = '66371c3a7517e9eabd7cb6cf0c5abffe7296bd4bac29c85b8bf7bb9db349714a'
assert hashlib.sha256(blob).hexdigest() == expected
base = struct.unpack_from('<I', blob, 0x18)[0]
address = 0x8006DF1C
offset = address - base + 0x800
table = blob[offset:offset + 4096 * 4]
words = struct.unpack('<4096i', table)
output = ROOT / 'assets/characters/recovered_leaders/ed/beam/rotmatrix.tres'
output.write_text('[gd_resource type="Resource" format=3]\n\n[resource]\n'
                  'metadata/source = "SLUS_007.26:0x8006DF1C, 4096 packed signed Q12 sine/cosine pairs"\n'
                  f'metadata/source_sha256 = "{expected}"\n'
                  f'metadata/table_sha256 = "{hashlib.sha256(table).hexdigest()}"\n'
                  'metadata/sin_cos = PackedInt32Array(' + ', '.join(map(str, words)) + ')\n')
print('ED_ROTMATRIX_EXTRACTED', output, hashlib.sha256(table).hexdigest())
