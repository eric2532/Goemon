"""Verify original land-walking sounds, then reproduce their existing dry PCM.

Run with build/Other Files/Goemon ROM Recovery/Tools/venv/bin/python.
Requires the user's locally recovered ROM and existing Unicorn/NumPy tools.
"""
from pathlib import Path
import hashlib
import json
import struct
import subprocess
import sys
from unicorn import Uc, UC_ARCH_MIPS, UC_MODE_MIPS32, UC_MODE_BIG_ENDIAN, UC_HOOK_CODE
from unicorn.mips_const import (
    UC_MIPS_REG_A0, UC_MIPS_REG_CP0_STATUS, UC_MIPS_REG_PC,
    UC_MIPS_REG_RA, UC_MIPS_REG_SP, UC_MIPS_REG_V0,
)

ROOT = Path(__file__).resolve().parents[1]
RECOVERY = ROOT / 'build/Other Files/Goemon ROM Recovery'
OUT = ROOT / 'build/Other Files/Asset Toolkit/Original Footsteps'
ROM_HASH = '1603be37427a33548857fc3d2e8867ede71121c353fb631b79b44f1d94845d80'


def verify():
    rom = (RECOVERY / 'original.z64').read_bytes()
    assert hashlib.sha256(rom).hexdigest() == ROM_HASH, 'Unexpected source ROM'
    overlay = (RECOVERY / 'Extracted/files/0010.bin').read_bytes()
    u = Uc(UC_ARCH_MIPS, UC_MODE_MIPS32 | UC_MODE_BIG_ENDIAN)
    u.mem_map(0, 0x800000)
    u.mem_write(0x400, rom[0x1000:0x7ec20])
    u.mem_write(0x1cb460, overlay)
    u.reg_write(UC_MIPS_REG_CP0_STATUS, 0x24000000)
    calls = []

    def hook(u, address, size, data):
        if address == 0x801e348c:
            u.emu_stop()  # Stop after sound dispatch, before input/movement.
        elif address == 0x80038bc8:
            calls.append(u.reg_read(UC_MIPS_REG_A0))
            u.reg_write(UC_MIPS_REG_PC, u.reg_read(UC_MIPS_REG_RA))
        elif address == 0x801e7de8:
            u.reg_write(UC_MIPS_REG_V0, 0)  # Ordinary dry land, no water.
            u.reg_write(UC_MIPS_REG_PC, u.reg_read(UC_MIPS_REG_RA))

    u.hook_add(UC_HOOK_CODE, hook)
    results = []
    for character, name, table, model_index, expected in [
        (0, 'Goemon', 0x801fcf98, 287, 0x217),
        (2, 'Sasuke', 0x802005a0, 295, 0x218),
        (3, 'Yae', 0x80202228, 299, 0x217),
    ]:
        model = (RECOVERY / f'Extracted/files/{model_index:04d}.bin').read_bytes()
        u.mem_write(0x400000, model)
        for action in range(0xc, 0x10):
            row = struct.unpack_from('>7I', overlay, table + action * 28 - 0x801cb460)
            count = struct.unpack_from('>I', model, row[2] & 0xffffff)[0] & 255
            events = []
            for frame in range(count):
                u.mem_write(0x600000, bytes(0x1000))
                for address, value in [(0x600018, 0x80600400), (0x60005c, 0x80600200),
                                       (0x600058, row[2]), (0x600440, 0x80400000)]:
                    u.mem_write(address, struct.pack('>I', value))
                u.mem_write(0x6000d0, struct.pack('>f', 1.0))
                u.mem_write(0x600428, struct.pack('>f', frame))
                u.mem_write(0x600060, bytes([character]))
                u.mem_write(0x1fcacc, b'\0')
                u.reg_write(UC_MIPS_REG_A0, 0x80600000)
                u.reg_write(UC_MIPS_REG_SP, 0x807ff000)
                u.reg_write(UC_MIPS_REG_RA, 0x807f0000)
                calls.clear()
                u.emu_start(0x801e3400, 0, count=100000)
                assert u.reg_read(UC_MIPS_REG_PC) == 0x801e348c
                assert not calls or calls == [expected], (name, action, frame, calls)
                if calls:
                    events.append({'source_frame': frame, 'event': hex(expected)})
            assert events and len(events) < count, 'Must verify audible and silent frames'
            results.append({'character': name, 'action': hex(action), 'events': events})
    samples = []
    for event, character in [(0x217, 'yae'), (0x218, 'sasuke')]:
        subprocess.run([sys.executable, str(RECOVERY / 'Audio/trace_engine.py'), hex(event)], check=True)
        subprocess.run([sys.executable, str(RECOVERY / 'Audio/render_events.py'), hex(event)], check=True)
        rendered = RECOVERY / f'Audio/event_{event:03x}_dry.wav'
        runtime = ROOT / f'assets/audio/recovered_{character}/event_{event:03x}.wav'
        assert rendered.read_bytes() == runtime.read_bytes(), 'Prepared audio differs from original render'
        samples.append({'event': hex(event), 'path': str(runtime.relative_to(ROOT)),
                        'sha256': hashlib.sha256(runtime.read_bytes()).hexdigest(),
                        'render': json.loads(rendered.with_name(rendered.stem + '_render.json').read_text())})
    OUT.mkdir(parents=True, exist_ok=True)
    report = {'rom_sha256': ROM_HASH, 'method': 'Original land handler 801E3400 through 801DD720, '
              'channel decoder and character sound lookup 801DD6E0 execute in Unicorn. Only the sound '
              'API and dry-land environment query are hooked. Every frame of actions 0C–0F is checked. '
              'Rate 1 frame probes identify the event, not native playback cadence.',
              'cases': results, 'samples': samples,
              'scope': 'Ordinary land footsteps. Existing gameplay cadence is unchanged. Dry reconstruction; '
              'original RSP filtering and room reverb are not emulated.'}
    (OUT / 'source-verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print('ORIGINAL_FOOTSTEPS_SOURCE: 12 gait cases and 2 fresh PCM comparisons PASS')


if __name__ == '__main__':
    verify()
