"""Execute only the pinned original StandEnemy list parser and selection routine."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT.parent / 'Magic Power/research/cgmsv-20261031/source/gmsv/cgmsv.exe'
BLOB = '402d215aab0b5262d646f2b26e28d171857f49eb'


def recover(binary=BINARY):
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/research/vendor'))
    import unicorn as uc
    from unicorn import x86_const as x
    raw = binary.read_bytes()
    assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == BLOB
    pe = struct.unpack_from('<I', raw, 0x3c)[0]
    optional = pe + 24
    assert struct.unpack_from('<H', raw, optional)[0] == 0x20b
    base = struct.unpack_from('<Q', raw, optional + 24)[0]
    size = struct.unpack_from('<I', raw, optional + 56)[0]
    machine = uc.Uc(uc.UC_ARCH_X86, uc.UC_MODE_64)
    machine.mem_map(base, (size + 4095) & ~4095)
    machine.mem_write(base, raw[:0x400])
    section_start = optional + struct.unpack_from('<H', raw, pe + 20)[0]
    for i in range(struct.unpack_from('<H', raw, pe + 6)[0]):
        p = section_start + i * 40
        _, rva, length, offset = struct.unpack_from('<IIII', raw, p + 8)
        if length:
            machine.mem_write(base + rva, raw[offset:offset + length])

    def get(at, length=8):
        return int.from_bytes(machine.mem_read(at, length), 'little')

    def string(at):
        out = bytearray()
        while len(out) < 8192:
            char = machine.mem_read(at + len(out), 1)
            if char == b'\0':
                return bytes(out)
            out += char
        raise AssertionError('Unterminated source string')

    stop, stack, data = 0x73000000, 0x70000000, 0x71000000
    machine.mem_map(stop, 0x20000)
    machine.mem_map(stack, 0x40000)
    machine.mem_map(data, 0x10000)
    imports = {}
    rva = struct.unpack_from('<I', raw, optional + 112 + 8)[0]
    while get(base + rva, 4):
        original, first = get(base + rva, 4), get(base + rva + 16, 4)
        i = 0
        while get(base + original + i * 8):
            entry = get(base + original + i * 8)
            name = string(base + entry + 2).decode() if not entry >> 63 else 'ordinal'
            at = stop + 0x100 + len(imports) * 16
            imports[at] = name
            machine.mem_write(base + first + i * 8, struct.pack('<Q', at))
            i += 1
        rva += 20
    state = {}

    def ret(value=0):
        sp = machine.reg_read(x.UC_X86_REG_RSP)
        machine.reg_write(x.UC_X86_REG_RAX, value & 0xffffffffffffffff)
        machine.reg_write(x.UC_X86_REG_RIP, get(sp))
        machine.reg_write(x.UC_X86_REG_RSP, sp + 8)

    def hook(cpu, pc, size, user):
        if pc == stop:
            machine.emu_stop()
            return
        args = [machine.reg_read(r) for r in [x.UC_X86_REG_RCX, x.UC_X86_REG_RDX, x.UC_X86_REG_R8, x.UC_X86_REG_R9]]
        if state.get('selection'):
            if pc == base + 0x121b02:
                ret(data + 0x4000)
                return
            if pc == base + 0x18db20:
                ret(state['random_value'])
                return
            if pc in [base + 0x1b501b, base + 0x1b50c2]:
                ret()
                return
            if pc == base + 0x009327:
                state['ranges'].append(args[:2])
            if pc == base + 0x09902c:
                state['resolved'].append(args[0])
                ret(args[0])
                return
            if pc == base + 0x097c5e:
                state['built'].append(args[1])
                ret(data + 0x6000)
                return
        if pc not in imports:
            return
        name = imports[pc]
        if name == 'atoi':
            match = re.match(rb'\s*([+-]?\d+)', string(args[0]))
            ret(int(match[1]) if match else 0)
        elif name in ['strlen', 'lstrlenA']:
            ret(len(string(args[0])))
        elif name in ['memcpy', 'memmove']:
            machine.mem_write(args[0], bytes(machine.mem_read(args[1], args[2])))
            ret(args[0])
        elif name in ['strcpy', 'strncpy']:
            value = string(args[1]) + b'\0'
            if name == 'strncpy':
                value = value[:args[2]].ljust(args[2], b'\0')
            machine.mem_write(args[0], value)
            ret(args[0])
        elif name == 'memset':
            machine.mem_write(args[0], bytes([args[1] & 255]) * args[2])
            ret(args[0])
        elif name in ['strchr', 'strstr']:
            needle = bytes([args[1] & 255]) if name == 'strchr' else string(args[1])
            haystack = string(args[0]) + (b'\0' if name == 'strchr' else b'')
            index = haystack.find(needle)
            ret(args[0] + index if index >= 0 else 0)
        elif name in ['strcmp', 'strncmp']:
            left, right = string(args[0]), string(args[1])
            if name == 'strncmp':
                left, right = left[:args[2]], right[:args[2]]
            ret((left > right) - (left < right))
        else:
            raise AssertionError(('Unexpected imported routine', name, hex(pc)))

    machine.hook_add(uc.UC_HOOK_CODE, hook)

    def call(rva, args, extra=()):
        sp = stack + 0x3f008
        machine.mem_write(sp, struct.pack('<Q', stop))
        machine.reg_write(x.UC_X86_REG_RSP, sp)
        for reg, value in zip([x.UC_X86_REG_RCX, x.UC_X86_REG_RDX, x.UC_X86_REG_R8, x.UC_X86_REG_R9], args):
            machine.reg_write(reg, value)
        for i, value in enumerate(extra):
            machine.mem_write(sp + 40 + i * 8, struct.pack('<Q', value))
        machine.emu_start(base + rva, stop, count=200000)
        assert machine.reg_read(x.UC_X86_REG_RIP) == stop
        return machine.reg_read(x.UC_X86_REG_RAX)

    parsers = []
    for ids in ['9034,9035,9036', '12008', '9034,9034,9035', ','.join(str(i) for i in range(1, 18))]:
        arg = '3|0,21015,31,16||0|6107||6108||0|' + ids + '|0|1|||0|1|||'
        machine.mem_write(data, arg.encode() + b'\0')
        machine.mem_write(data + 0x2000, b'\0' * 128)
        count = call(0x121b3f, [9, data, 16, data + 0x2000])
        values = [get(data + 0x2000 + i * 4, 4) for i in range(count)]
        assert values == list(map(int, ids.split(',')))[:16]
        parsers.append(dict(field=9, raw=ids, count=count, encounters=values))
    choices = [9034, 9035, 9036]
    selections = []
    machine.mem_write(data + 0x4000 + 0x2c, struct.pack('<III', *choices))
    machine.mem_write(data + 0x4000 + 0x6c, struct.pack('<I', len(choices)))
    for random_value in range(6):
        state.update(selection=True, random_value=random_value, ranges=[], resolved=[], built=[])
        result = call(0x1395ae, [data + 0x3000, data + 0x5000, data + 0x5100, data + 0x5200], [data + 0x5300, data + 0x5400])
        expected = choices[random_value % len(choices)]
        assert state['ranges'] == [[0, 2]] and state['resolved'] == [expected] and state['built'] == [expected]
        assert result == data + 0x6000
        selections.append(dict(random_value=random_value, index_range=state['ranges'][0], encounter=expected, construction_calls=len(state['built'])))
    return dict(binary_git_blob=BLOB, binary_sha256=hashlib.sha256(raw).hexdigest(),
                source_url='https://github.com/linv2/Crossgate_Docker/blob/dd8690ed3df11e4eb5a038a54079a8f40d8e93b3/gmsv/cgmsv.exe',
                qualification='Original field parser, bounded integer RNG and StandEnemy selector executed; only pure CRT, mutex, RNG raw sample, work lookup, encounter lookup and construction are hooked. No server started.',
                parser_rva='0x121b3f', selector_rva='0x1395ae', rng_rva='0x9327', max_encounters=16,
                meaning='One uniformly selected original encounter per activation; comma entries are alternatives, not phases.',
                parser_cases=parsers, selection_cases=selections)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = recover()
    if args.output:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False))
